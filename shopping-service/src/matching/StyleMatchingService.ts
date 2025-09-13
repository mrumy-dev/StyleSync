import { IProduct } from '../models/Product';
import { VisualSimilarityEngine, SimilarityMatch } from './VisualSimilarityEngine';
import Fuse from 'fuse.js';

export interface StyleMatchingOptions {
  visualWeight: number;
  textualWeight: number;
  priceWeight: number;
  materialWeight: number;
  maxResults: number;
  minSimilarityThreshold: number;
  priceRangeTolerance: number;
  includeSustainableAlternatives: boolean;
  includeBrandAlternatives: boolean;
}

export interface StyleMatchResult extends SimilarityMatch {
  matchType: 'visual' | 'textual' | 'material' | 'price' | 'brand' | 'sustainable';
  priceComparison: {
    difference: number;
    percentage: number;
    betterDeal: boolean;
  };
  sustainabilityComparison?: {
    targetScore: number;
    matchScore: number;
    moreSustainable: boolean;
  };
}

export class StyleMatchingService {
  private visualEngine: VisualSimilarityEngine;
  private fuseOptions: Fuse.IFuseOptions<IProduct>;

  constructor() {
    this.visualEngine = new VisualSimilarityEngine();
    this.fuseOptions = {
      keys: [
        { name: 'name', weight: 0.4 },
        { name: 'description', weight: 0.3 },
        { name: 'brand', weight: 0.2 },
        { name: 'category.tags', weight: 0.1 }
      ],
      threshold: 0.4,
      includeScore: true
    };
  }

  async findStyleMatches(
    targetProduct: IProduct,
    candidateProducts: IProduct[],
    options: Partial<StyleMatchingOptions> = {}
  ): Promise<StyleMatchResult[]> {
    const config: StyleMatchingOptions = {
      visualWeight: 0.4,
      textualWeight: 0.3,
      priceWeight: 0.2,
      materialWeight: 0.1,
      maxResults: 20,
      minSimilarityThreshold: 0.3,
      priceRangeTolerance: 0.5,
      includeSustainableAlternatives: true,
      includeBrandAlternatives: true,
      ...options
    };

    const matches: StyleMatchResult[] = [];

    // 1. Visual similarity matching
    const visualMatches = await this.getVisualMatches(targetProduct, candidateProducts, config);
    matches.push(...visualMatches);

    // 2. Textual similarity matching
    const textualMatches = this.getTextualMatches(targetProduct, candidateProducts, config);
    matches.push(...textualMatches);

    // 3. Material-based matching
    const materialMatches = this.getMaterialMatches(targetProduct, candidateProducts, config);
    matches.push(...materialMatches);

    // 4. Price-based alternatives
    const priceMatches = this.getPriceAlternatives(targetProduct, candidateProducts, config);
    matches.push(...priceMatches);

    // 5. Brand alternatives
    if (config.includeBrandAlternatives) {
      const brandMatches = this.getBrandAlternatives(targetProduct, candidateProducts, config);
      matches.push(...brandMatches);
    }

    // 6. Sustainable alternatives
    if (config.includeSustainableAlternatives) {
      const sustainableMatches = this.getSustainableAlternatives(targetProduct, candidateProducts, config);
      matches.push(...sustainableMatches);
    }

    // Deduplicate and combine scores
    const uniqueMatches = this.deduplicateMatches(matches);
    
    // Calculate final similarity scores
    const scoredMatches = uniqueMatches.map(match => ({
      ...match,
      similarityScore: this.calculateFinalSimilarityScore(match, config)
    }));

    // Filter and sort results
    return scoredMatches
      .filter(match => match.similarityScore >= config.minSimilarityThreshold)
      .sort((a, b) => b.similarityScore - a.similarityScore)
      .slice(0, config.maxResults);
  }

  private async getVisualMatches(
    targetProduct: IProduct,
    candidates: IProduct[],
    config: StyleMatchingOptions
  ): Promise<StyleMatchResult[]> {
    try {
      const visualMatches = await this.visualEngine.findSimilarProducts(
        targetProduct,
        candidates,
        {
          colorWeight: 0.4,
          styleWeight: 0.3,
          shapeWeight: 0.3,
          minSimilarityThreshold: 0.3,
          maxResults: config.maxResults * 2
        }
      );

      return visualMatches.map(match => ({
        ...match,
        matchType: 'visual' as const,
        priceComparison: this.calculatePriceComparison(targetProduct, match.product),
        sustainabilityComparison: this.calculateSustainabilityComparison(targetProduct, match.product)
      }));
    } catch (error) {
      console.error('Visual matching failed:', error);
      return [];
    }
  }

  private getTextualMatches(
    targetProduct: IProduct,
    candidates: IProduct[],
    config: StyleMatchingOptions
  ): Promise<StyleMatchResult[]> {
    const fuse = new Fuse(candidates, this.fuseOptions);
    const searchQuery = `${targetProduct.name} ${targetProduct.description}`;
    const results = fuse.search(searchQuery);

    return Promise.resolve(
      results
        .filter(result => result.score && result.score < 0.6)
        .map(result => ({
          product: result.item,
          similarityScore: 1 - (result.score || 1),
          breakdown: {
            colorSimilarity: 0,
            styleSimilarity: 1 - (result.score || 1),
            shapeSimilarity: 0,
            overallMatch: 1 - (result.score || 1)
          },
          matchReasons: ['Similar product description', 'Matching keywords'],
          matchType: 'textual' as const,
          priceComparison: this.calculatePriceComparison(targetProduct, result.item),
          sustainabilityComparison: this.calculateSustainabilityComparison(targetProduct, result.item)
        }))
    );
  }

  private getMaterialMatches(
    targetProduct: IProduct,
    candidates: IProduct[],
    config: StyleMatchingOptions
  ): StyleMatchResult[] {
    if (!targetProduct.materials?.length) return [];

    const matches: StyleMatchResult[] = [];

    for (const candidate of candidates) {
      if (!candidate.materials?.length || candidate.id === targetProduct.id) continue;

      const commonMaterials = targetProduct.materials.filter(material =>
        candidate.materials!.includes(material)
      );

      if (commonMaterials.length > 0) {
        const materialSimilarity = commonMaterials.length / Math.max(
          targetProduct.materials.length,
          candidate.materials.length
        );

        if (materialSimilarity >= 0.5) {
          matches.push({
            product: candidate,
            similarityScore: materialSimilarity,
            breakdown: {
              colorSimilarity: 0,
              styleSimilarity: materialSimilarity,
              shapeSimilarity: 0,
              overallMatch: materialSimilarity
            },
            matchReasons: [`Shared materials: ${commonMaterials.join(', ')}`],
            matchType: 'material',
            priceComparison: this.calculatePriceComparison(targetProduct, candidate),
            sustainabilityComparison: this.calculateSustainabilityComparison(targetProduct, candidate)
          });
        }
      }
    }

    return matches;
  }

  private getPriceAlternatives(
    targetProduct: IProduct,
    candidates: IProduct[],
    config: StyleMatchingOptions
  ): StyleMatchResult[] {
    const targetPrice = targetProduct.price.current;
    const toleranceAmount = targetPrice * config.priceRangeTolerance;
    
    const matches: StyleMatchResult[] = [];

    for (const candidate of candidates) {
      if (candidate.id === targetProduct.id) continue;

      const priceDiff = Math.abs(candidate.price.current - targetPrice);
      const isWithinRange = priceDiff <= toleranceAmount;
      const isSimilarCategory = candidate.category.main === targetProduct.category.main;

      if (isWithinRange && isSimilarCategory) {
        const priceSimilarity = 1 - (priceDiff / (targetPrice + toleranceAmount));
        
        matches.push({
          product: candidate,
          similarityScore: priceSimilarity * 0.7, // Lower weight for price-only matches
          breakdown: {
            colorSimilarity: 0,
            styleSimilarity: 0,
            shapeSimilarity: 0,
            overallMatch: priceSimilarity
          },
          matchReasons: [`Similar price range`, `Same category: ${candidate.category.main}`],
          matchType: 'price',
          priceComparison: this.calculatePriceComparison(targetProduct, candidate),
          sustainabilityComparison: this.calculateSustainabilityComparison(targetProduct, candidate)
        });
      }
    }

    return matches;
  }

  private getBrandAlternatives(
    targetProduct: IProduct,
    candidates: IProduct[],
    config: StyleMatchingOptions
  ): StyleMatchResult[] {
    // Find alternatives from different brands but similar style
    const matches: StyleMatchResult[] = [];
    const targetBrand = targetProduct.brand.toLowerCase();

    const brandTiers: Record<string, string[]> = {
      luxury: ['gucci', 'prada', 'louis vuitton', 'hermès', 'chanel', 'dior'],
      premium: ['ralph lauren', 'hugo boss', 'calvin klein', 'tommy hilfiger', 'armani'],
      contemporary: ['zara', 'h&m', 'uniqlo', 'cos', 'arket', 'massimo dutti'],
      fast_fashion: ['shein', 'primark', 'forever 21', 'boohoo'],
      sustainable: ['everlane', 'reformation', 'eileen fisher', 'patagonia']
    };

    const targetTier = this.findBrandTier(targetBrand, brandTiers);

    for (const candidate of candidates) {
      const candidateBrand = candidate.brand.toLowerCase();
      const candidateTier = this.findBrandTier(candidateBrand, brandTiers);

      if (candidateBrand !== targetBrand && 
          targetTier && 
          candidateTier === targetTier &&
          candidate.category.main === targetProduct.category.main) {
        
        const categorySimilarity = this.calculateCategorySimilarity(targetProduct, candidate);
        
        if (categorySimilarity > 0.5) {
          matches.push({
            product: candidate,
            similarityScore: categorySimilarity * 0.8,
            breakdown: {
              colorSimilarity: 0,
              styleSimilarity: categorySimilarity,
              shapeSimilarity: 0,
              overallMatch: categorySimilarity
            },
            matchReasons: [`Alternative from ${candidateTier} tier`, `Same category`],
            matchType: 'brand',
            priceComparison: this.calculatePriceComparison(targetProduct, candidate),
            sustainabilityComparison: this.calculateSustainabilityComparison(targetProduct, candidate)
          });
        }
      }
    }

    return matches;
  }

  private getSustainableAlternatives(
    targetProduct: IProduct,
    candidates: IProduct[],
    config: StyleMatchingOptions
  ): StyleMatchResult[] {
    const matches: StyleMatchResult[] = [];
    const targetSustainabilityScore = targetProduct.sustainability?.score || 0;

    for (const candidate of candidates) {
      if (candidate.id === targetProduct.id) continue;

      const candidateScore = candidate.sustainability?.score || 0;
      const hasCertifications = candidate.sustainability?.certifications?.length || 0;
      
      if (candidateScore > targetSustainabilityScore || hasCertifications > 0) {
        const categorySimilarity = this.calculateCategorySimilarity(targetProduct, candidate);
        
        if (categorySimilarity > 0.4) {
          const sustainabilityBonus = (candidateScore - targetSustainabilityScore) / 10;
          const finalScore = categorySimilarity + sustainabilityBonus;
          
          matches.push({
            product: candidate,
            similarityScore: Math.min(1, finalScore),
            breakdown: {
              colorSimilarity: 0,
              styleSimilarity: categorySimilarity,
              shapeSimilarity: 0,
              overallMatch: finalScore
            },
            matchReasons: [
              'More sustainable option',
              ...candidate.sustainability?.certifications || []
            ],
            matchType: 'sustainable',
            priceComparison: this.calculatePriceComparison(targetProduct, candidate),
            sustainabilityComparison: this.calculateSustainabilityComparison(targetProduct, candidate)
          });
        }
      }
    }

    return matches;
  }

  private deduplicateMatches(matches: StyleMatchResult[]): StyleMatchResult[] {
    const seen = new Map<string, StyleMatchResult>();

    for (const match of matches) {
      const key = match.product.id;
      const existing = seen.get(key);
      
      if (!existing || match.similarityScore > existing.similarityScore) {
        seen.set(key, match);
      }
    }

    return Array.from(seen.values());
  }

  private calculateFinalSimilarityScore(
    match: StyleMatchResult,
    config: StyleMatchingOptions
  ): number {
    const baseScore = match.similarityScore;
    
    // Apply weights based on match type
    const typeWeights = {
      visual: config.visualWeight,
      textual: config.textualWeight,
      material: config.materialWeight,
      price: config.priceWeight,
      brand: 0.15,
      sustainable: 0.1
    };

    const weight = typeWeights[match.matchType] || 0.1;
    return baseScore * weight;
  }

  private calculatePriceComparison(product1: IProduct, product2: IProduct) {
    const price1 = product1.price.current;
    const price2 = product2.price.current;
    const difference = price2 - price1;
    const percentage = price1 > 0 ? (difference / price1) * 100 : 0;

    return {
      difference,
      percentage,
      betterDeal: difference < 0
    };
  }

  private calculateSustainabilityComparison(product1: IProduct, product2: IProduct) {
    const score1 = product1.sustainability?.score || 0;
    const score2 = product2.sustainability?.score || 0;

    return {
      targetScore: score1,
      matchScore: score2,
      moreSustainable: score2 > score1
    };
  }

  private calculateCategorySimilarity(product1: IProduct, product2: IProduct): number {
    let similarity = 0;
    
    if (product1.category.main === product2.category.main) similarity += 0.5;
    if (product1.category.sub === product2.category.sub) similarity += 0.3;
    
    const commonTags = product1.category.tags.filter(tag => 
      product2.category.tags.includes(tag)
    );
    similarity += (commonTags.length / Math.max(product1.category.tags.length, 1)) * 0.2;
    
    return Math.min(1, similarity);
  }

  private findBrandTier(brand: string, brandTiers: Record<string, string[]>): string | null {
    for (const [tier, brands] of Object.entries(brandTiers)) {
      if (brands.some(b => brand.includes(b) || b.includes(brand))) {
        return tier;
      }
    }
    return null;
  }
}