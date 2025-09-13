import { RecommendationResult, RecommendationContext } from './RecommendationEngine';
import { IUserPreferences } from '../models/UserPreferences';
import { IProduct } from '../models/Product';
import { PersonalizationFactor } from './PersonalizationFactorsCollector';

export interface DetailedExplanation {
  primary: string;
  secondary: string[];
  confidence: number;
  reasoning: {
    whyRecommended: ExplanationReason[];
    whyNot: ExplanationReason[];
    alternatives: AlternativeExplanation[];
  };
  visualExplanation: {
    type: 'style_match' | 'color_harmony' | 'price_comparison' | 'contextual_fit';
    data: any;
    imageUrl?: string;
  };
  factorBreakdown: {
    factor: string;
    contribution: number;
    explanation: string;
    confidence: number;
  }[];
  abTestInfo: {
    group: string;
    variant: string;
    experimentId: string;
  };
  feedbackQuestions: SuggestedFeedback[];
}

export interface ExplanationReason {
  reason: string;
  confidence: number;
  weight: number;
  evidence: string[];
  category: 'style' | 'context' | 'preference' | 'social' | 'behavioral' | 'environmental';
}

export interface AlternativeExplanation {
  productId: string;
  reason: string;
  confidence: number;
  tradeoffs: string[];
}

export interface SuggestedFeedback {
  question: string;
  type: 'rating' | 'binary' | 'multiple_choice' | 'text';
  options?: string[];
  importance: 'high' | 'medium' | 'low';
}

export interface ExplanationContext {
  userPreferences: IUserPreferences;
  context: RecommendationContext;
  personalizationFactors: Map<string, PersonalizationFactor>;
  abTestGroup: string;
  previousInteractions: any[];
  culturalContext?: {
    region: string;
    preferences: string[];
  };
}

export class IntelligentExplanationSystem {
  private explanationTemplates: Map<string, string[]> = new Map();
  private confidenceThresholds = {
    high: 0.8,
    medium: 0.6,
    low: 0.4
  };

  constructor() {
    this.initializeTemplates();
  }

  async generateDetailedExplanation(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): Promise<DetailedExplanation> {
    const factorBreakdown = this.analyzeFactorContributions(recommendation, context);
    const reasoning = await this.generateReasoning(recommendation, context, factorBreakdown);
    const visualExplanation = await this.generateVisualExplanation(recommendation, context);
    const abTestInfo = this.getAbTestInfo(context.abTestGroup);
    const feedbackQuestions = this.generateFeedbackQuestions(recommendation, context);

    const primaryExplanation = this.generatePrimaryExplanation(recommendation, context);
    const secondaryExplanations = this.generateSecondaryExplanations(recommendation, context);

    const overallConfidence = this.calculateExplanationConfidence(
      recommendation,
      factorBreakdown,
      reasoning
    );

    return {
      primary: primaryExplanation,
      secondary: secondaryExplanations,
      confidence: overallConfidence,
      reasoning,
      visualExplanation,
      factorBreakdown,
      abTestInfo,
      feedbackQuestions
    };
  }

  private analyzeFactorContributions(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ) {
    const factors: {
      factor: string;
      contribution: number;
      explanation: string;
      confidence: number;
    }[] = [];

    // Analyze personalization factors
    for (const [factorName, factor] of context.personalizationFactors) {
      const contribution = this.calculateFactorContribution(
        factorName,
        factor,
        recommendation,
        context
      );

      if (contribution > 0.1) { // Only include significant factors
        factors.push({
          factor: factorName,
          contribution,
          explanation: this.getFactorExplanation(factorName, factor, recommendation),
          confidence: factor.confidence
        });
      }
    }

    // Analyze recommendation score breakdown
    const scoreBreakdown = recommendation.score.breakdown;
    Object.entries(scoreBreakdown).forEach(([algorithm, score]) => {
      if (score > 0.1) {
        factors.push({
          factor: `${algorithm}_algorithm`,
          contribution: score,
          explanation: this.getAlgorithmExplanation(algorithm, score, recommendation),
          confidence: recommendation.score.confidence
        });
      }
    });

    return factors.sort((a, b) => b.contribution - a.contribution);
  }

  private calculateFactorContribution(
    factorName: string,
    factor: PersonalizationFactor,
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): number {
    // Calculate how much this factor contributed to the recommendation
    let contribution = factor.weight * factor.confidence;

    // Context-specific adjustments
    switch (factorName) {
      case 'temperature':
        contribution *= this.getTemperatureRelevance(
          factor.value as number,
          recommendation.product
        );
        break;
      case 'timeOfDay':
        contribution *= this.getTimeRelevance(
          factor.value as string,
          recommendation.product
        );
        break;
      case 'budgetConstraints':
        contribution *= this.getBudgetRelevance(
          factor.value as number,
          recommendation.product
        );
        break;
      case 'styleConsistency':
        contribution *= this.getStyleRelevance(
          context.userPreferences,
          recommendation.product
        );
        break;
      default:
        break;
    }

    return Math.min(1, contribution);
  }

  private getFactorExplanation(
    factorName: string,
    factor: PersonalizationFactor,
    recommendation: RecommendationResult
  ): string {
    const templates = this.explanationTemplates.get(factorName) || [
      `${factorName} influenced this recommendation`
    ];

    const template = templates[Math.floor(Math.random() * templates.length)];

    // Replace placeholders with actual values
    return template
      .replace('{value}', String(factor.value))
      .replace('{product_name}', recommendation.product.name)
      .replace('{brand}', recommendation.product.brand)
      .replace('{category}', recommendation.product.category.main);
  }

  private getAlgorithmExplanation(
    algorithm: string,
    score: number,
    recommendation: RecommendationResult
  ): string {
    const explanations: { [key: string]: string } = {
      collaborative: `Users with similar preferences gave this ${recommendation.product.category.main} high ratings`,
      contentBased: `This ${recommendation.product.name} matches your style preferences and past choices`,
      contextual: `Perfect timing and context for this ${recommendation.product.category.main}`,
      deepLearning: `Our AI analysis suggests this is an excellent match for you`,
      reinforcement: `Learning from your interactions, this appears to be a great choice`
    };

    return explanations[algorithm] || `${algorithm} analysis suggests this is a good match`;
  }

  private async generateReasoning(
    recommendation: RecommendationResult,
    context: ExplanationContext,
    factorBreakdown: any[]
  ) {
    const whyRecommended: ExplanationReason[] = [];
    const whyNot: ExplanationReason[] = [];
    const alternatives: AlternativeExplanation[] = [];

    // Generate positive reasons
    whyRecommended.push(...this.generatePositiveReasons(recommendation, context, factorBreakdown));

    // Generate cautionary reasons
    whyNot.push(...this.generateCautionaryReasons(recommendation, context));

    // Generate alternatives
    alternatives.push(...await this.generateAlternatives(recommendation, context));

    return { whyRecommended, whyNot, alternatives };
  }

  private generatePositiveReasons(
    recommendation: RecommendationResult,
    context: ExplanationContext,
    factorBreakdown: any[]
  ): ExplanationReason[] {
    const reasons: ExplanationReason[] = [];

    // Style match reasons
    if (this.isStyleMatch(recommendation.product, context.userPreferences)) {
      reasons.push({
        reason: `Perfect match for your ${context.userPreferences.shopping.style.preferences.join(', ')} style`,
        confidence: 0.9,
        weight: 0.25,
        evidence: [
          `Your style preferences: ${context.userPreferences.shopping.style.preferences.join(', ')}`,
          `Product tags: ${recommendation.product.category.tags.join(', ')}`
        ],
        category: 'style'
      });
    }

    // Price match reasons
    if (this.isPriceMatch(recommendation.product, context.userPreferences)) {
      const priceRange = context.userPreferences.shopping.priceRange;
      reasons.push({
        reason: `Within your budget of $${priceRange.min}-$${priceRange.max}`,
        confidence: 0.95,
        weight: 0.2,
        evidence: [
          `Your budget: $${priceRange.min}-$${priceRange.max}`,
          `Product price: $${recommendation.product.price.current}`
        ],
        category: 'preference'
      });
    }

    // Contextual reasons
    const contextualReason = this.getContextualReason(recommendation, context);
    if (contextualReason) {
      reasons.push(contextualReason);
    }

    // Social reasons
    const socialReason = this.getSocialReason(recommendation, context);
    if (socialReason) {
      reasons.push(socialReason);
    }

    // Behavioral reasons
    const behavioralReason = this.getBehavioralReason(recommendation, context);
    if (behavioralReason) {
      reasons.push(behavioralReason);
    }

    return reasons.sort((a, b) => (b.confidence * b.weight) - (a.confidence * a.weight));
  }

  private generateCautionaryReasons(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): ExplanationReason[] {
    const reasons: ExplanationReason[] = [];

    // Price concerns
    if (recommendation.product.price.current > context.userPreferences.shopping.priceRange.max * 0.8) {
      reasons.push({
        reason: 'This is at the higher end of your budget',
        confidence: 0.8,
        weight: 0.15,
        evidence: [`Price: $${recommendation.product.price.current}`, `Your max: $${context.userPreferences.shopping.priceRange.max}`],
        category: 'preference'
      });
    }

    // Style stretch
    if (!this.isStrictStyleMatch(recommendation.product, context.userPreferences)) {
      reasons.push({
        reason: 'This explores a slightly different style than your usual preferences',
        confidence: 0.7,
        weight: 0.1,
        evidence: ['Expanding your style horizons', 'Based on similar users\' choices'],
        category: 'style'
      });
    }

    // Seasonal mismatch
    if (this.isSeasonalMismatch(recommendation.product, context.context)) {
      reasons.push({
        reason: 'This might be more suitable for a different season',
        confidence: 0.6,
        weight: 0.1,
        evidence: ['Current season considerations', 'Product seasonal tags'],
        category: 'environmental'
      });
    }

    return reasons;
  }

  private async generateAlternatives(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): Promise<AlternativeExplanation[]> {
    // This would typically query for similar products
    // For now, we'll create placeholder alternatives
    return [
      {
        productId: 'alt_1',
        reason: 'Similar style but 20% less expensive',
        confidence: 0.8,
        tradeoffs: ['Lower price', 'Different brand', 'Similar quality']
      },
      {
        productId: 'alt_2',
        reason: 'Same brand but different color options',
        confidence: 0.75,
        tradeoffs: ['Same quality', 'More color choices', 'Slightly higher price']
      }
    ];
  }

  private async generateVisualExplanation(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ) {
    const product = recommendation.product;

    // Determine the best visual explanation type
    if (context.userPreferences.shopping.style.colors.length > 0) {
      return {
        type: 'color_harmony' as const,
        data: {
          userColors: context.userPreferences.shopping.style.colors,
          productColors: product.colors || [],
          harmony: this.calculateColorHarmony(
            context.userPreferences.shopping.style.colors,
            product.colors || []
          )
        }
      };
    } else if (context.userPreferences.shopping.priceRange) {
      return {
        type: 'price_comparison' as const,
        data: {
          userBudget: context.userPreferences.shopping.priceRange,
          productPrice: product.price.current,
          comparison: this.generatePriceComparison(product, context.userPreferences)
        }
      };
    } else {
      return {
        type: 'style_match' as const,
        data: {
          userStyles: context.userPreferences.shopping.style.preferences,
          productTags: product.category.tags,
          matchScore: this.calculateStyleMatchScore(product, context.userPreferences)
        }
      };
    }
  }

  private generatePrimaryExplanation(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): string {
    const confidence = recommendation.score.confidence;
    const product = recommendation.product;

    if (confidence >= this.confidenceThresholds.high) {
      return `This ${product.category.main} is an excellent match based on your preferences and current context.`;
    } else if (confidence >= this.confidenceThresholds.medium) {
      return `This ${product.name} appears to be a good fit for you.`;
    } else {
      return `You might like this ${product.category.main} - it's worth exploring.`;
    }
  }

  private generateSecondaryExplanations(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): string[] {
    const explanations: string[] = [];
    const product = recommendation.product;

    // Brand explanation
    if (context.userPreferences.shopping.favoriteBrands.includes(product.brand)) {
      explanations.push(`From ${product.brand}, one of your favorite brands`);
    }

    // Price explanation
    if (this.isPriceMatch(product, context.userPreferences)) {
      explanations.push(`Fits perfectly within your budget`);
    }

    // Contextual explanations
    if (context.context.timeOfDay === 'morning' && product.category.tags.includes('workwear')) {
      explanations.push(`Perfect for your morning routine and work setting`);
    }

    // Weather explanations
    if (context.context.weather) {
      const temp = context.context.weather.temperature;
      if (temp < 10 && product.category.tags.includes('warm')) {
        explanations.push(`Ideal for the current cold weather`);
      } else if (temp > 25 && product.category.tags.includes('light')) {
        explanations.push(`Great choice for the warm weather`);
      }
    }

    // Social explanations
    if (recommendation.category === 'trending') {
      explanations.push(`Currently trending among users with similar taste`);
    }

    return explanations.slice(0, 3); // Limit to top 3
  }

  private calculateExplanationConfidence(
    recommendation: RecommendationResult,
    factorBreakdown: any[],
    reasoning: any
  ): number {
    let confidence = recommendation.score.confidence * 0.4;

    // Factor contribution confidence
    const avgFactorConfidence = factorBreakdown.reduce(
      (sum, factor) => sum + factor.confidence, 0
    ) / factorBreakdown.length;
    confidence += avgFactorConfidence * 0.3;

    // Reasoning strength
    const reasoningStrength = reasoning.whyRecommended.reduce(
      (sum: number, reason: ExplanationReason) => sum + (reason.confidence * reason.weight), 0
    );
    confidence += reasoningStrength * 0.3;

    return Math.min(1, confidence);
  }

  private getAbTestInfo(abTestGroup: string) {
    return {
      group: abTestGroup,
      variant: Math.random() > 0.5 ? 'explanation_detailed' : 'explanation_simple',
      experimentId: 'exp_explanation_depth_001'
    };
  }

  private generateFeedbackQuestions(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): SuggestedFeedback[] {
    const questions: SuggestedFeedback[] = [];

    // Basic satisfaction
    questions.push({
      question: 'How helpful was this explanation?',
      type: 'rating',
      importance: 'high'
    });

    // Explanation clarity
    questions.push({
      question: 'Was the reasoning clear and easy to understand?',
      type: 'binary',
      importance: 'high'
    });

    // Missing information
    questions.push({
      question: 'What other information would help you make this decision?',
      type: 'multiple_choice',
      options: [
        'More size information',
        'Better photos',
        'Customer reviews',
        'Styling suggestions',
        'Price comparison',
        'Return policy'
      ],
      importance: 'medium'
    });

    // Confidence calibration
    questions.push({
      question: 'How confident are you about this recommendation?',
      type: 'rating',
      importance: 'medium'
    });

    return questions;
  }

  // Utility methods
  private initializeTemplates(): void {
    this.explanationTemplates.set('temperature', [
      'Perfect for {value}°C weather',
      'The current temperature of {value}°C makes this {category} ideal',
      'Weather-appropriate choice for {value}°C conditions'
    ]);

    this.explanationTemplates.set('timeOfDay', [
      'Great choice for {value} activities',
      'Perfect timing - this {category} fits your {value} routine',
      'Ideal for your {value} schedule'
    ]);

    this.explanationTemplates.set('budgetConstraints', [
      'Fits perfectly within your ${value} budget',
      'Great value at this price point',
      'Within your comfortable spending range'
    ]);

    this.explanationTemplates.set('brandLoyalty', [
      'From {brand}, which matches your brand preferences',
      'You\'ve shown interest in {brand} before',
      '{brand} aligns with your taste'
    ]);

    // Add more templates for other factors...
  }

  private getTemperatureRelevance(temp: number, product: IProduct): number {
    const coldWeatherTags = ['warm', 'winter', 'coat', 'sweater', 'boots'];
    const warmWeatherTags = ['light', 'summer', 'shorts', 'sandals', 'tank'];

    if (temp < 10) {
      return coldWeatherTags.some(tag => product.category.tags.includes(tag)) ? 1 : 0.3;
    } else if (temp > 25) {
      return warmWeatherTags.some(tag => product.category.tags.includes(tag)) ? 1 : 0.3;
    }
    return 0.7; // Moderate relevance for moderate temperatures
  }

  private getTimeRelevance(timeOfDay: string, product: IProduct): number {
    const timeRelevance: { [key: string]: string[] } = {
      morning: ['workwear', 'professional', 'casual'],
      afternoon: ['casual', 'sporty', 'comfortable'],
      evening: ['formal', 'dressy', 'social'],
      night: ['comfortable', 'lounge', 'sleepwear']
    };

    const relevantTags = timeRelevance[timeOfDay] || [];
    return relevantTags.some(tag => product.category.tags.includes(tag)) ? 1 : 0.5;
  }

  private getBudgetRelevance(budget: number, product: IProduct): number {
    const price = product.price.current;
    if (price <= budget) {
      return 1 - (price / budget) * 0.5 + 0.5; // Higher relevance for lower prices within budget
    }
    return Math.max(0, 1 - ((price - budget) / budget)); // Decreasing relevance as price exceeds budget
  }

  private getStyleRelevance(preferences: IUserPreferences, product: IProduct): number {
    const userStyles = preferences.shopping.style.preferences;
    const productTags = product.category.tags;

    const matches = userStyles.filter(style => productTags.includes(style)).length;
    return matches / Math.max(userStyles.length, 1);
  }

  private isStyleMatch(product: IProduct, preferences: IUserPreferences): boolean {
    return preferences.shopping.style.preferences.some(style =>
      product.category.tags.includes(style)
    );
  }

  private isStrictStyleMatch(product: IProduct, preferences: IUserPreferences): boolean {
    const matches = preferences.shopping.style.preferences.filter(style =>
      product.category.tags.includes(style)
    );
    return matches.length >= Math.min(2, preferences.shopping.style.preferences.length);
  }

  private isPriceMatch(product: IProduct, preferences: IUserPreferences): boolean {
    const price = product.price.current;
    return price >= preferences.shopping.priceRange.min &&
           price <= preferences.shopping.priceRange.max;
  }

  private isSeasonalMismatch(product: IProduct, context: RecommendationContext): boolean {
    const now = new Date(context.timestamp);
    const month = now.getMonth();
    const season = this.getSeason(month);

    const seasonalTags: { [key: string]: string[] } = {
      winter: ['winter', 'warm', 'coat', 'boots', 'sweater'],
      summer: ['summer', 'light', 'shorts', 'sandals', 'tank'],
      spring: ['spring', 'light', 'jacket', 'transitional'],
      fall: ['fall', 'autumn', 'layering', 'jacket', 'boots']
    };

    const currentSeasonTags = seasonalTags[season] || [];
    const hasSeasonalTags = product.category.tags.some(tag =>
      Object.values(seasonalTags).flat().includes(tag)
    );

    return hasSeasonalTags && !currentSeasonTags.some(tag =>
      product.category.tags.includes(tag)
    );
  }

  private getSeason(month: number): string {
    if (month >= 2 && month <= 4) return 'spring';
    if (month >= 5 && month <= 7) return 'summer';
    if (month >= 8 && month <= 10) return 'fall';
    return 'winter';
  }

  private getContextualReason(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): ExplanationReason | null {
    if (context.context.calendar?.hasEvents) {
      return {
        reason: `Perfect for your upcoming ${context.context.calendar.eventTypes.join(' and ')} events`,
        confidence: 0.8,
        weight: 0.2,
        evidence: [
          `Events in calendar: ${context.context.calendar.eventTypes.join(', ')}`,
          `Formality level: ${context.context.calendar.formalityLevel}`
        ],
        category: 'contextual'
      };
    }
    return null;
  }

  private getSocialReason(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): ExplanationReason | null {
    if (recommendation.category === 'trending') {
      return {
        reason: 'Currently popular among users with similar style preferences',
        confidence: 0.7,
        weight: 0.15,
        evidence: ['Trending in your style category', 'High engagement from similar users'],
        category: 'social'
      };
    }
    return null;
  }

  private getBehavioralReason(
    recommendation: RecommendationResult,
    context: ExplanationContext
  ): ExplanationReason | null {
    if (context.previousInteractions.length > 0) {
      return {
        reason: 'Based on your browsing and purchase patterns',
        confidence: 0.75,
        weight: 0.18,
        evidence: ['Your interaction history', 'Similar user behaviors'],
        category: 'behavioral'
      };
    }
    return null;
  }

  private calculateColorHarmony(userColors: string[], productColors: string[]): number {
    if (userColors.length === 0 || productColors.length === 0) return 0.5;

    const matches = userColors.filter(color =>
      productColors.some(pColor =>
        pColor.toLowerCase().includes(color.toLowerCase()) ||
        color.toLowerCase().includes(pColor.toLowerCase())
      )
    );

    return matches.length / userColors.length;
  }

  private generatePriceComparison(
    product: IProduct,
    preferences: IUserPreferences
  ) {
    const price = product.price.current;
    const budget = preferences.shopping.priceRange;

    return {
      position: (price - budget.min) / (budget.max - budget.min),
      message: price <= budget.max * 0.5 ? 'Great value' :
               price <= budget.max * 0.8 ? 'Good price' : 'Premium choice'
    };
  }

  private calculateStyleMatchScore(
    product: IProduct,
    preferences: IUserPreferences
  ): number {
    const styleMatches = preferences.shopping.style.preferences.filter(style =>
      product.category.tags.includes(style)
    ).length;

    const colorMatches = preferences.shopping.style.colors.filter(color =>
      product.colors?.some(pColor =>
        pColor.toLowerCase().includes(color.toLowerCase())
      )
    ).length;

    const brandMatch = preferences.shopping.favoriteBrands.includes(product.brand) ? 1 : 0;

    return (styleMatches * 0.5 + colorMatches * 0.3 + brandMatch * 0.2) /
           Math.max(1, preferences.shopping.style.preferences.length);
  }
}