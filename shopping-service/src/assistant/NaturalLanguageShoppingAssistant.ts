import natural from 'natural';
import compromise from 'compromise';
import Sentiment from 'sentiment';
import { NlpManager } from 'node-nlp';
import { Product } from '../models/Product';
import { PrecisionMatchingEngine, StyleMatchCriteria } from '../matching/PrecisionMatchingEngine';
import { PriceIntelligenceEngine } from '../intelligence/PriceIntelligenceEngine';
import { logger } from '../middleware/ErrorHandler';

export interface ShoppingQuery {
  text: string;
  intent: QueryIntent;
  entities: ExtractedEntity[];
  context?: ShoppingContext;
  confidence: number;
}

export interface QueryIntent {
  primary: string;
  secondary?: string;
  confidence: number;
}

export interface ExtractedEntity {
  type: EntityType;
  value: string;
  confidence: number;
  synonyms?: string[];
}

export type EntityType =
  | 'product_type'
  | 'brand'
  | 'color'
  | 'size'
  | 'material'
  | 'price_range'
  | 'style'
  | 'occasion'
  | 'season'
  | 'gender'
  | 'age_group'
  | 'feature'
  | 'comparison_term';

export interface ShoppingContext {
  userId?: string;
  previousPurchases?: Product[];
  wardrobe?: Product[];
  preferences?: UserPreferences;
  budget?: { min: number; max: number };
  location?: string;
  currentSeason?: string;
}

export interface UserPreferences {
  brands: string[];
  colors: string[];
  styles: string[];
  priceRange: { min: number; max: number };
  sizes: Record<string, string>;
  materials: string[];
  avoidMaterials: string[];
}

export interface ShoppingResponse {
  query: ShoppingQuery;
  results: ShoppingResult[];
  suggestions: string[];
  followUpQuestions: string[];
  explanation: string;
  totalResults: number;
}

export interface ShoppingResult {
  product: Product;
  relevanceScore: number;
  matchReason: string;
  priceAnalysis?: {
    dealScore: number;
    trend: 'increasing' | 'decreasing' | 'stable';
    recommendation: string;
  };
  alternatives?: Product[];
}

export class NaturalLanguageShoppingAssistant {
  private nlpManager: NlpManager;
  private sentiment: Sentiment;
  private tokenizer: natural.WordTokenizer;
  private stemmer: natural.PorterStemmer;
  private matchingEngine: PrecisionMatchingEngine;
  private priceEngine: PriceIntelligenceEngine;

  private intents: Map<string, IntentPattern[]> = new Map();
  private entityPatterns: Map<EntityType, RegExp[]> = new Map();
  private synonymDict: Map<string, string[]> = new Map();

  constructor(
    matchingEngine: PrecisionMatchingEngine,
    priceEngine: PriceIntelligenceEngine
  ) {
    this.nlpManager = new NlpManager({ languages: ['en'] });
    this.sentiment = new Sentiment();
    this.tokenizer = new natural.WordTokenizer();
    this.stemmer = natural.PorterStemmer;
    this.matchingEngine = matchingEngine;
    this.priceEngine = priceEngine;

    this.initializeIntents();
    this.initializeEntityPatterns();
    this.initializeSynonymDictionary();
    this.trainNLPModel();
  }

  async processQuery(
    text: string,
    context?: ShoppingContext,
    imageUrl?: string
  ): Promise<ShoppingResponse> {
    try {
      // Clean and preprocess text
      const cleanText = this.preprocessText(text);

      // Parse the query
      const query = await this.parseQuery(cleanText, context);

      // Handle different query types
      let results: ShoppingResult[] = [];

      if (imageUrl) {
        results = await this.handleImageSearch(query, imageUrl, context);
      } else {
        results = await this.handleTextSearch(query, context);
      }

      // Generate suggestions and follow-up questions
      const suggestions = this.generateSuggestions(query, results);
      const followUpQuestions = this.generateFollowUpQuestions(query, results);

      // Create explanation
      const explanation = this.generateExplanation(query, results);

      return {
        query,
        results: results.slice(0, 20), // Limit results
        suggestions,
        followUpQuestions,
        explanation,
        totalResults: results.length
      };

    } catch (error) {
      logger.error('Error processing shopping query:', error);
      throw error;
    }
  }

  private async parseQuery(text: string, context?: ShoppingContext): Promise<ShoppingQuery> {
    // Intent recognition
    const intent = await this.recognizeIntent(text);

    // Entity extraction
    const entities = await this.extractEntities(text);

    // Sentiment analysis
    const sentimentResult = this.sentiment.analyze(text);

    // Calculate overall confidence
    const confidence = this.calculateQueryConfidence(intent, entities, sentimentResult);

    return {
      text,
      intent,
      entities,
      context,
      confidence
    };
  }

  private async recognizeIntent(text: string): Promise<QueryIntent> {
    // Use NLP manager for intent recognition
    const nlpResult = await this.nlpManager.process('en', text);

    if (nlpResult.intent && nlpResult.intent !== 'None') {
      return {
        primary: nlpResult.intent,
        confidence: nlpResult.score || 0.5
      };
    }

    // Fallback to pattern matching
    const doc = compromise(text);
    const patterns = [
      { intent: 'search', patterns: ['find', 'look for', 'search', 'show me', 'i want', 'i need'] },
      { intent: 'compare', patterns: ['compare', 'difference', 'vs', 'versus', 'better'] },
      { intent: 'recommend', patterns: ['recommend', 'suggest', 'what should', 'best'] },
      { intent: 'price_check', patterns: ['price', 'cost', 'expensive', 'cheap', 'deal'] },
      { intent: 'availability', patterns: ['available', 'in stock', 'sold out'] },
      { intent: 'size_help', patterns: ['size', 'fit', 'sizing', 'measurements'] },
      { intent: 'style_advice', patterns: ['style', 'match', 'goes with', 'outfit'] },
      { intent: 'budget_optimization', patterns: ['budget', 'save money', 'affordable', 'under'] }
    ];

    for (const { intent, patterns } of patterns) {
      for (const pattern of patterns) {
        if (text.toLowerCase().includes(pattern)) {
          return {
            primary: intent,
            confidence: 0.7
          };
        }
      }
    }

    return {
      primary: 'search',
      confidence: 0.3
    };
  }

  private async extractEntities(text: string): Promise<ExtractedEntity[]> {
    const entities: ExtractedEntity[] = [];
    const doc = compromise(text);

    // Extract product types
    const productTypes = this.extractProductTypes(text, doc);
    entities.push(...productTypes);

    // Extract brands
    const brands = this.extractBrands(text, doc);
    entities.push(...brands);

    // Extract colors
    const colors = this.extractColors(text, doc);
    entities.push(...colors);

    // Extract sizes
    const sizes = this.extractSizes(text, doc);
    entities.push(...sizes);

    // Extract materials
    const materials = this.extractMaterials(text, doc);
    entities.push(...materials);

    // Extract price ranges
    const priceRanges = this.extractPriceRanges(text, doc);
    entities.push(...priceRanges);

    // Extract styles
    const styles = this.extractStyles(text, doc);
    entities.push(...styles);

    // Extract occasions
    const occasions = this.extractOccasions(text, doc);
    entities.push(...occasions);

    return entities;
  }

  private extractProductTypes(text: string, doc: any): ExtractedEntity[] {
    const productTypes = [
      'dress', 'shirt', 'pants', 'jeans', 'shoes', 'sneakers', 'boots',
      'jacket', 'coat', 'sweater', 'hoodie', 't-shirt', 'blouse', 'skirt',
      'shorts', 'swimwear', 'underwear', 'socks', 'hat', 'bag', 'wallet',
      'watch', 'jewelry', 'necklace', 'earrings', 'ring', 'bracelet'
    ];

    const entities: ExtractedEntity[] = [];
    const lowerText = text.toLowerCase();

    for (const type of productTypes) {
      if (lowerText.includes(type)) {
        entities.push({
          type: 'product_type',
          value: type,
          confidence: 0.9,
          synonyms: this.getSynonyms(type)
        });
      }
    }

    // Use compromise to find clothing-related nouns
    const nouns = doc.nouns().out('array');
    for (const noun of nouns) {
      if (this.isClothingItem(noun) && !entities.find(e => e.value === noun)) {
        entities.push({
          type: 'product_type',
          value: noun,
          confidence: 0.7
        });
      }
    }

    return entities;
  }

  private extractBrands(text: string, doc: any): ExtractedEntity[] {
    const brands = [
      'nike', 'adidas', 'zara', 'h&m', 'uniqlo', 'gap', 'levis', 'calvin klein',
      'tommy hilfiger', 'polo ralph lauren', 'hugo boss', 'armani', 'gucci',
      'prada', 'versace', 'burberry', 'chanel', 'dior', 'louis vuitton',
      'michael kors', 'coach', 'kate spade', 'tory burch', 'marc jacobs'
    ];

    const entities: ExtractedEntity[] = [];
    const lowerText = text.toLowerCase();

    for (const brand of brands) {
      if (lowerText.includes(brand)) {
        entities.push({
          type: 'brand',
          value: brand,
          confidence: 0.95
        });
      }
    }

    return entities;
  }

  private extractColors(text: string, doc: any): ExtractedEntity[] {
    const colors = [
      'red', 'blue', 'green', 'yellow', 'orange', 'purple', 'pink', 'brown',
      'black', 'white', 'gray', 'grey', 'navy', 'maroon', 'burgundy', 'khaki',
      'beige', 'tan', 'olive', 'turquoise', 'teal', 'coral', 'lavender',
      'mint', 'cream', 'ivory', 'gold', 'silver', 'metallic'
    ];

    const entities: ExtractedEntity[] = [];
    const lowerText = text.toLowerCase();

    for (const color of colors) {
      if (lowerText.includes(color)) {
        entities.push({
          type: 'color',
          value: color,
          confidence: 0.9
        });
      }
    }

    return entities;
  }

  private extractSizes(text: string, doc: any): ExtractedEntity[] {
    const sizePatterns = [
      /\b(xs|extra small)\b/i,
      /\b(s|small)\b/i,
      /\b(m|medium)\b/i,
      /\b(l|large)\b/i,
      /\b(xl|extra large)\b/i,
      /\b(xxl|2xl|extra extra large)\b/i,
      /\bsize\s*(\d+)\b/i,
      /\b(\d+)\s*(?:inch|")\b/i,
      /\b[0-9]+[a-z]*\b/g // Generic size patterns
    ];

    const entities: ExtractedEntity[] = [];

    for (const pattern of sizePatterns) {
      const matches = text.match(pattern);
      if (matches) {
        matches.forEach(match => {
          entities.push({
            type: 'size',
            value: match.toLowerCase(),
            confidence: 0.8
          });
        });
      }
    }

    return entities;
  }

  private extractMaterials(text: string, doc: any): ExtractedEntity[] {
    const materials = [
      'cotton', 'polyester', 'wool', 'silk', 'linen', 'denim', 'leather',
      'suede', 'canvas', 'nylon', 'spandex', 'elastane', 'cashmere',
      'bamboo', 'organic cotton', 'recycled polyester', 'modal', 'viscose'
    ];

    const entities: ExtractedEntity[] = [];
    const lowerText = text.toLowerCase();

    for (const material of materials) {
      if (lowerText.includes(material)) {
        entities.push({
          type: 'material',
          value: material,
          confidence: 0.85
        });
      }
    }

    return entities;
  }

  private extractPriceRanges(text: string, doc: any): ExtractedEntity[] {
    const pricePatterns = [
      /under\s*\$?(\d+)/i,
      /below\s*\$?(\d+)/i,
      /less than\s*\$?(\d+)/i,
      /\$?(\d+)\s*to\s*\$?(\d+)/i,
      /between\s*\$?(\d+)\s*and\s*\$?(\d+)/i,
      /around\s*\$?(\d+)/i,
      /about\s*\$?(\d+)/i,
      /\$(\d+)/g
    ];

    const entities: ExtractedEntity[] = [];

    for (const pattern of pricePatterns) {
      const matches = text.match(pattern);
      if (matches) {
        entities.push({
          type: 'price_range',
          value: matches[0],
          confidence: 0.9
        });
      }
    }

    return entities;
  }

  private extractStyles(text: string, doc: any): ExtractedEntity[] {
    const styles = [
      'casual', 'formal', 'business', 'sporty', 'athletic', 'vintage',
      'retro', 'modern', 'classic', 'trendy', 'bohemian', 'minimalist',
      'edgy', 'romantic', 'punk', 'goth', 'preppy', 'streetwear'
    ];

    const entities: ExtractedEntity[] = [];
    const lowerText = text.toLowerCase();

    for (const style of styles) {
      if (lowerText.includes(style)) {
        entities.push({
          type: 'style',
          value: style,
          confidence: 0.8
        });
      }
    }

    return entities;
  }

  private extractOccasions(text: string, doc: any): ExtractedEntity[] {
    const occasions = [
      'work', 'office', 'party', 'wedding', 'date', 'vacation', 'travel',
      'gym', 'workout', 'running', 'hiking', 'beach', 'winter', 'summer',
      'spring', 'fall', 'autumn', 'interview', 'meeting', 'dinner'
    ];

    const entities: ExtractedEntity[] = [];
    const lowerText = text.toLowerCase();

    for (const occasion of occasions) {
      if (lowerText.includes(occasion)) {
        entities.push({
          type: 'occasion',
          value: occasion,
          confidence: 0.8
        });
      }
    }

    return entities;
  }

  private async handleImageSearch(
    query: ShoppingQuery,
    imageUrl: string,
    context?: ShoppingContext
  ): Promise<ShoppingResult[]> {
    // This would integrate with the visual matching engine
    const criteria: StyleMatchCriteria = {
      visualWeight: 0.8,
      semanticWeight: 0.2
    };

    // Apply context filters
    if (context?.preferences?.priceRange) {
      criteria.priceRange = context.preferences.priceRange;
    }

    if (context?.preferences?.brands) {
      criteria.brandPreference = context.preferences.brands;
    }

    // For now, return empty array as this requires product database
    return [];
  }

  private async handleTextSearch(
    query: ShoppingQuery,
    context?: ShoppingContext
  ): Promise<ShoppingResult[]> {
    // Build search criteria from extracted entities
    const searchCriteria = this.buildSearchCriteria(query, context);

    // This would integrate with the product search system
    // For now, return empty array as this requires product database
    return [];
  }

  private buildSearchCriteria(query: ShoppingQuery, context?: ShoppingContext): any {
    const criteria: any = {};

    // Extract search terms from entities
    const productTypes = query.entities.filter(e => e.type === 'product_type');
    const brands = query.entities.filter(e => e.type === 'brand');
    const colors = query.entities.filter(e => e.type === 'color');
    const sizes = query.entities.filter(e => e.type === 'size');
    const materials = query.entities.filter(e => e.type === 'material');
    const styles = query.entities.filter(e => e.type === 'style');
    const priceRanges = query.entities.filter(e => e.type === 'price_range');

    if (productTypes.length > 0) {
      criteria.productTypes = productTypes.map(e => e.value);
    }

    if (brands.length > 0) {
      criteria.brands = brands.map(e => e.value);
    }

    if (colors.length > 0) {
      criteria.colors = colors.map(e => e.value);
    }

    if (sizes.length > 0) {
      criteria.sizes = sizes.map(e => e.value);
    }

    if (materials.length > 0) {
      criteria.materials = materials.map(e => e.value);
    }

    if (styles.length > 0) {
      criteria.styles = styles.map(e => e.value);
    }

    // Parse price ranges
    if (priceRanges.length > 0) {
      criteria.priceRange = this.parsePriceRange(priceRanges[0].value);
    }

    // Apply context
    if (context?.preferences) {
      if (!criteria.brands && context.preferences.brands.length > 0) {
        criteria.preferredBrands = context.preferences.brands;
      }

      if (!criteria.priceRange && context.preferences.priceRange) {
        criteria.maxPrice = context.preferences.priceRange.max;
      }
    }

    return criteria;
  }

  private parsePriceRange(priceText: string): { min?: number; max?: number } {
    const range: { min?: number; max?: number } = {};

    // Under/below patterns
    const underMatch = priceText.match(/(?:under|below|less than)\s*\$?(\d+)/i);
    if (underMatch) {
      range.max = parseInt(underMatch[1]);
      return range;
    }

    // Range patterns
    const rangeMatch = priceText.match(/\$?(\d+)\s*(?:to|-)\s*\$?(\d+)/i);
    if (rangeMatch) {
      range.min = parseInt(rangeMatch[1]);
      range.max = parseInt(rangeMatch[2]);
      return range;
    }

    // Between patterns
    const betweenMatch = priceText.match(/between\s*\$?(\d+)\s*and\s*\$?(\d+)/i);
    if (betweenMatch) {
      range.min = parseInt(betweenMatch[1]);
      range.max = parseInt(betweenMatch[2]);
      return range;
    }

    // Single price (around/about)
    const singleMatch = priceText.match(/\$?(\d+)/);
    if (singleMatch) {
      const price = parseInt(singleMatch[1]);
      range.min = price * 0.8; // 20% below
      range.max = price * 1.2; // 20% above
    }

    return range;
  }

  private generateSuggestions(query: ShoppingQuery, results: ShoppingResult[]): string[] {
    const suggestions: string[] = [];

    // Generate suggestions based on intent
    switch (query.intent.primary) {
      case 'search':
        suggestions.push('Try adding a color preference');
        suggestions.push('Specify a price range');
        suggestions.push('Include a brand name');
        break;

      case 'compare':
        suggestions.push('Compare similar products from different brands');
        suggestions.push('Look at price differences');
        suggestions.push('Check material quality');
        break;

      case 'recommend':
        suggestions.push('Consider your wardrobe gaps');
        suggestions.push('Think about upcoming occasions');
        suggestions.push('Factor in seasonal trends');
        break;
    }

    return suggestions.slice(0, 3);
  }

  private generateFollowUpQuestions(query: ShoppingQuery, results: ShoppingResult[]): string[] {
    const questions: string[] = [];

    // Generate based on missing entities
    const hasColor = query.entities.some(e => e.type === 'color');
    const hasSize = query.entities.some(e => e.type === 'size');
    const hasPrice = query.entities.some(e => e.type === 'price_range');
    const hasOccasion = query.entities.some(e => e.type === 'occasion');

    if (!hasColor) {
      questions.push('What color are you looking for?');
    }

    if (!hasSize) {
      questions.push('What size do you need?');
    }

    if (!hasPrice) {
      questions.push('What\'s your budget range?');
    }

    if (!hasOccasion) {
      questions.push('What occasion is this for?');
    }

    return questions.slice(0, 2);
  }

  private generateExplanation(query: ShoppingQuery, results: ShoppingResult[]): string {
    const entities = query.entities.map(e => e.value).join(', ');

    if (results.length === 0) {
      return `I searched for ${entities} but didn't find any exact matches. Try broadening your search or adjusting your criteria.`;
    }

    if (results.length === 1) {
      return `I found 1 product matching your search for ${entities}.`;
    }

    return `I found ${results.length} products matching your search for ${entities}. Results are sorted by relevance and quality.`;
  }

  private calculateQueryConfidence(
    intent: QueryIntent,
    entities: ExtractedEntity[],
    sentiment: any
  ): number {
    let confidence = intent.confidence * 0.5;

    // Add confidence based on entity quality
    const avgEntityConfidence = entities.length > 0
      ? entities.reduce((sum, e) => sum + e.confidence, 0) / entities.length
      : 0;

    confidence += avgEntityConfidence * 0.3;

    // Add confidence based on sentiment clarity
    if (Math.abs(sentiment.score) > 2) {
      confidence += 0.2; // Clear positive or negative sentiment
    }

    return Math.min(confidence, 0.95);
  }

  private preprocessText(text: string): string {
    return text
      .toLowerCase()
      .replace(/[^\w\s$]/g, ' ') // Remove punctuation except $
      .replace(/\s+/g, ' ')
      .trim();
  }

  private isClothingItem(noun: string): boolean {
    const clothingKeywords = [
      'clothing', 'apparel', 'garment', 'wear', 'outfit', 'attire'
    ];

    return clothingKeywords.some(keyword => noun.includes(keyword));
  }

  private getSynonyms(word: string): string[] {
    return this.synonymDict.get(word) || [];
  }

  private initializeIntents(): void {
    // Initialize intent patterns
    const intents = [
      {
        intent: 'search',
        patterns: [
          'find me a {product}',
          'looking for {product}',
          'show me {product}',
          'i want {product}',
          'i need {product}'
        ]
      },
      {
        intent: 'compare',
        patterns: [
          'compare {product1} and {product2}',
          'difference between {product1} and {product2}',
          'which is better {product1} or {product2}'
        ]
      },
      {
        intent: 'recommend',
        patterns: [
          'recommend {product}',
          'suggest {product}',
          'what {product} should i buy',
          'best {product}'
        ]
      }
    ];

    intents.forEach(({ intent, patterns }) => {
      this.intents.set(intent, patterns.map(p => ({ pattern: p, confidence: 0.9 })));
    });
  }

  private initializeEntityPatterns(): void {
    // Initialize entity recognition patterns
    this.entityPatterns.set('price_range', [
      /under\s*\$?(\d+)/i,
      /\$?(\d+)\s*to\s*\$?(\d+)/i,
      /between\s*\$?(\d+)\s*and\s*\$?(\d+)/i
    ]);

    this.entityPatterns.set('size', [
      /\b(xs|s|m|l|xl|xxl)\b/i,
      /\bsize\s*(\d+)\b/i
    ]);
  }

  private initializeSynonymDictionary(): void {
    const synonyms = {
      'dress': ['frock', 'gown', 'outfit'],
      'shirt': ['top', 'blouse', 'tee'],
      'pants': ['trousers', 'slacks', 'bottoms'],
      'shoes': ['footwear', 'sneakers', 'boots']
    };

    Object.entries(synonyms).forEach(([word, syns]) => {
      this.synonymDict.set(word, syns);
    });
  }

  private async trainNLPModel(): void {
    // Train the NLP model with sample data
    const trainingData = [
      { text: 'find me a red dress', intent: 'search' },
      { text: 'looking for blue jeans', intent: 'search' },
      { text: 'compare nike vs adidas shoes', intent: 'compare' },
      { text: 'recommend winter jacket', intent: 'recommend' },
      { text: 'what is the price of this shirt', intent: 'price_check' }
    ];

    for (const { text, intent } of trainingData) {
      this.nlpManager.addDocument('en', text, intent);
    }

    await this.nlpManager.train();
  }
}

interface IntentPattern {
  pattern: string;
  confidence: number;
}