import { RecommendationContext } from './RecommendationEngine';
import { IUserPreferences } from '../models/UserPreferences';
import { IProduct } from '../models/Product';
import axios from 'axios';

export interface PersonalizationFactor {
  name: string;
  value: number | string | boolean;
  weight: number;
  confidence: number;
  source: 'explicit' | 'implicit' | 'inferred' | 'environmental';
  category: 'temporal' | 'environmental' | 'behavioral' | 'contextual' | 'social' | 'personal';
  lastUpdated: Date;
}

export interface PersonalizationProfile {
  userId: string;
  factors: Map<string, PersonalizationFactor>;
  timestamp: Date;
  contextHash: string;
}

export class PersonalizationFactorsCollector {
  private weatherApiKey: string;
  private calendarIntegrations: Map<string, any> = new Map();
  private socialDataCache: Map<string, any> = new Map();
  private behaviorPatterns: Map<string, any> = new Map();

  constructor(weatherApiKey: string = '') {
    this.weatherApiKey = weatherApiKey;
  }

  async collectAllFactors(
    userId: string,
    preferences: IUserPreferences,
    context: RecommendationContext,
    recentInteractions: any[] = [],
    recentPurchases: IProduct[] = []
  ): Promise<PersonalizationProfile> {
    const factors = new Map<string, PersonalizationFactor>();
    const timestamp = new Date();

    // 1. Temporal Factors (Time-based)
    await this.collectTemporalFactors(factors, context, timestamp);

    // 2. Environmental Factors (Weather, Location)
    await this.collectEnvironmentalFactors(factors, context, timestamp);

    // 3. Behavioral Factors (Usage patterns, preferences)
    await this.collectBehavioralFactors(factors, userId, recentInteractions, recentPurchases, timestamp);

    // 4. Contextual Factors (Calendar, social plans)
    await this.collectContextualFactors(factors, context, timestamp);

    // 5. Social Factors (Peer influence, trends)
    await this.collectSocialFactors(factors, userId, context, timestamp);

    // 6. Personal Factors (Style preferences, constraints)
    await this.collectPersonalFactors(factors, preferences, timestamp);

    // 7. Advanced Inference Factors
    await this.collectInferredFactors(factors, userId, preferences, context, timestamp);

    const contextHash = this.generateContextHash(context);

    return {
      userId,
      factors,
      timestamp,
      contextHash
    };
  }

  private async collectTemporalFactors(
    factors: Map<string, PersonalizationFactor>,
    context: RecommendationContext,
    timestamp: Date
  ): Promise<void> {
    const now = new Date(timestamp);
    const hour = now.getHours();
    const day = now.getDay();
    const month = now.getMonth();

    // Factor 1: Time of Day Preference
    factors.set('timeOfDay', {
      name: 'Time of Day',
      value: context.timeOfDay,
      weight: 0.15,
      confidence: 0.9,
      source: 'environmental',
      category: 'temporal',
      lastUpdated: timestamp
    });

    // Factor 2: Day of Week Shopping Pattern
    factors.set('dayOfWeek', {
      name: 'Day of Week',
      value: context.dayOfWeek,
      weight: 0.1,
      confidence: 0.8,
      source: 'environmental',
      category: 'temporal',
      lastUpdated: timestamp
    });

    // Factor 3: Hour-specific Preferences
    factors.set('hourOfDay', {
      name: 'Hour of Day',
      value: hour,
      weight: 0.08,
      confidence: 0.7,
      source: 'environmental',
      category: 'temporal',
      lastUpdated: timestamp
    });

    // Factor 4: Weekend vs Weekday
    factors.set('isWeekend', {
      name: 'Weekend Pattern',
      value: day === 0 || day === 6,
      weight: 0.12,
      confidence: 0.8,
      source: 'environmental',
      category: 'temporal',
      lastUpdated: timestamp
    });

    // Factor 5: Season Preference
    factors.set('season', {
      name: 'Season',
      value: this.getSeason(month),
      weight: 0.2,
      confidence: 0.9,
      source: 'environmental',
      category: 'temporal',
      lastUpdated: timestamp
    });

    // Factor 6: Morning vs Evening Person
    factors.set('timePreference', {
      name: 'Time Preference',
      value: hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening',
      weight: 0.1,
      confidence: 0.6,
      source: 'inferred',
      category: 'temporal',
      lastUpdated: timestamp
    });

    // Factor 7: Rush Hour Context
    factors.set('rushHour', {
      name: 'Rush Hour',
      value: (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19),
      weight: 0.08,
      confidence: 0.8,
      source: 'environmental',
      category: 'temporal',
      lastUpdated: timestamp
    });

    // Factor 8: Late Night Shopping
    factors.set('lateNightShopping', {
      name: 'Late Night Shopping',
      value: hour >= 22 || hour <= 6,
      weight: 0.12,
      confidence: 0.9,
      source: 'environmental',
      category: 'temporal',
      lastUpdated: timestamp
    });
  }

  private async collectEnvironmentalFactors(
    factors: Map<string, PersonalizationFactor>,
    context: RecommendationContext,
    timestamp: Date
  ): Promise<void> {
    // Factor 9: Weather Temperature
    if (context.weather) {
      factors.set('temperature', {
        name: 'Temperature',
        value: context.weather.temperature,
        weight: 0.25,
        confidence: 0.9,
        source: 'environmental',
        category: 'environmental',
        lastUpdated: timestamp
      });

      // Factor 10: Weather Condition
      factors.set('weatherCondition', {
        name: 'Weather Condition',
        value: context.weather.condition,
        weight: 0.2,
        confidence: 0.9,
        source: 'environmental',
        category: 'environmental',
        lastUpdated: timestamp
      });

      // Factor 11: Humidity Level
      factors.set('humidity', {
        name: 'Humidity',
        value: context.weather.humidity,
        weight: 0.1,
        confidence: 0.8,
        source: 'environmental',
        category: 'environmental',
        lastUpdated: timestamp
      });

      // Factor 12: Weather Comfort Index
      factors.set('weatherComfort', {
        name: 'Weather Comfort',
        value: this.calculateWeatherComfort(context.weather.temperature, context.weather.humidity),
        weight: 0.15,
        confidence: 0.7,
        source: 'inferred',
        category: 'environmental',
        lastUpdated: timestamp
      });
    }

    // Factor 13: Location Context
    if (context.location) {
      factors.set('locationContext', {
        name: 'Location Context',
        value: context.location.context,
        weight: 0.2,
        confidence: 0.85,
        source: 'environmental',
        category: 'environmental',
        lastUpdated: timestamp
      });

      // Factor 14: Geographic Climate Zone
      factors.set('climateZone', {
        name: 'Climate Zone',
        value: this.inferClimateZone(context.location.latitude),
        weight: 0.12,
        confidence: 0.7,
        source: 'inferred',
        category: 'environmental',
        lastUpdated: timestamp
      });
    }

    // Factor 15: Air Quality Impact
    factors.set('airQuality', {
      name: 'Air Quality',
      value: await this.getAirQuality(context.location),
      weight: 0.08,
      confidence: 0.6,
      source: 'environmental',
      category: 'environmental',
      lastUpdated: timestamp
    });

    // Factor 16: UV Index
    factors.set('uvIndex', {
      name: 'UV Index',
      value: await this.getUVIndex(context.location),
      weight: 0.1,
      confidence: 0.7,
      source: 'environmental',
      category: 'environmental',
      lastUpdated: timestamp
    });
  }

  private async collectBehavioralFactors(
    factors: Map<string, PersonalizationFactor>,
    userId: string,
    recentInteractions: any[],
    recentPurchases: IProduct[],
    timestamp: Date
  ): Promise<void> {
    const userBehavior = this.behaviorPatterns.get(userId) || {};

    // Factor 17: Shopping Frequency
    factors.set('shoppingFrequency', {
      name: 'Shopping Frequency',
      value: this.calculateShoppingFrequency(recentPurchases),
      weight: 0.15,
      confidence: 0.8,
      source: 'implicit',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 18: Browse vs Buy Ratio
    factors.set('browseBuyRatio', {
      name: 'Browse vs Buy Ratio',
      value: this.calculateBrowseBuyRatio(recentInteractions, recentPurchases),
      weight: 0.12,
      confidence: 0.7,
      source: 'implicit',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 19: Brand Loyalty
    factors.set('brandLoyalty', {
      name: 'Brand Loyalty',
      value: this.calculateBrandLoyalty(recentPurchases),
      weight: 0.18,
      confidence: 0.8,
      source: 'implicit',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 20: Price Sensitivity
    factors.set('priceSensitivity', {
      name: 'Price Sensitivity',
      value: this.calculatePriceSensitivity(recentPurchases, recentInteractions),
      weight: 0.2,
      confidence: 0.75,
      source: 'implicit',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 21: Return Rate Pattern
    factors.set('returnRate', {
      name: 'Return Rate',
      value: userBehavior.returnRate || 0,
      weight: 0.1,
      confidence: 0.6,
      source: 'implicit',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 22: Average Session Duration
    factors.set('sessionDuration', {
      name: 'Session Duration',
      value: userBehavior.avgSessionDuration || 300,
      weight: 0.08,
      confidence: 0.7,
      source: 'implicit',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 23: Impulse Buying Tendency
    factors.set('impulseBuying', {
      name: 'Impulse Buying',
      value: this.calculateImpulseBuyingTendency(recentPurchases),
      weight: 0.14,
      confidence: 0.6,
      source: 'inferred',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 24: Discovery vs Targeted Shopping
    factors.set('discoveryVsTargeted', {
      name: 'Discovery vs Targeted',
      value: this.calculateDiscoveryTendency(recentInteractions),
      weight: 0.12,
      confidence: 0.65,
      source: 'implicit',
      category: 'behavioral',
      lastUpdated: timestamp
    });
  }

  private async collectContextualFactors(
    factors: Map<string, PersonalizationFactor>,
    context: RecommendationContext,
    timestamp: Date
  ): Promise<void> {
    // Factor 25: Calendar Events
    if (context.calendar) {
      factors.set('hasEvents', {
        name: 'Has Calendar Events',
        value: context.calendar.hasEvents,
        weight: 0.15,
        confidence: 0.9,
        source: 'explicit',
        category: 'contextual',
        lastUpdated: timestamp
      });

      // Factor 26: Event Formality Level
      factors.set('eventFormality', {
        name: 'Event Formality',
        value: context.calendar.formalityLevel,
        weight: 0.25,
        confidence: 0.85,
        source: 'explicit',
        category: 'contextual',
        lastUpdated: timestamp
      });

      // Factor 27: Event Types
      factors.set('eventTypes', {
        name: 'Event Types',
        value: context.calendar.eventTypes.join(','),
        weight: 0.2,
        confidence: 0.8,
        source: 'explicit',
        category: 'contextual',
        lastUpdated: timestamp
      });
    }

    // Factor 28: Social Plans
    factors.set('socialPlans', {
      name: 'Social Plans',
      value: context.socialPlans || false,
      weight: 0.18,
      confidence: 0.7,
      source: 'explicit',
      category: 'contextual',
      lastUpdated: timestamp
    });

    // Factor 29: Work Schedule Impact
    factors.set('workSchedule', {
      name: 'Work Schedule',
      value: this.inferWorkSchedule(context),
      weight: 0.12,
      confidence: 0.6,
      source: 'inferred',
      category: 'contextual',
      lastUpdated: timestamp
    });

    // Factor 30: Travel Plans
    factors.set('travelPlans', {
      name: 'Travel Plans',
      value: context.location?.context === 'travel',
      weight: 0.2,
      confidence: 0.8,
      source: 'environmental',
      category: 'contextual',
      lastUpdated: timestamp
    });

    // Factor 31: Mood Detection
    if (context.mood) {
      factors.set('detectedMood', {
        name: 'Detected Mood',
        value: context.mood.detected,
        weight: 0.15,
        confidence: context.mood.confidence,
        source: 'inferred',
        category: 'contextual',
        lastUpdated: timestamp
      });
    }

    // Factor 32: Energy Level
    factors.set('energyLevel', {
      name: 'Energy Level',
      value: context.energyLevel || 'medium',
      weight: 0.1,
      confidence: 0.5,
      source: 'inferred',
      category: 'contextual',
      lastUpdated: timestamp
    });
  }

  private async collectSocialFactors(
    factors: Map<string, PersonalizationFactor>,
    userId: string,
    context: RecommendationContext,
    timestamp: Date
  ): Promise<void> {
    const socialData = this.socialDataCache.get(userId) || {};

    // Factor 33: Peer Preferences
    factors.set('peerPreferences', {
      name: 'Peer Preferences',
      value: socialData.peerInfluence || 0.5,
      weight: 0.12,
      confidence: 0.6,
      source: 'social',
      category: 'social',
      lastUpdated: timestamp
    });

    // Factor 34: Trending Items Interest
    factors.set('trendingInterest', {
      name: 'Trending Interest',
      value: socialData.trendFollowing || 0.5,
      weight: 0.15,
      confidence: 0.7,
      source: 'social',
      category: 'social',
      lastUpdated: timestamp
    });

    // Factor 35: Social Media Influence
    factors.set('socialMediaInfluence', {
      name: 'Social Media Influence',
      value: await this.getSocialMediaInfluence(userId),
      weight: 0.18,
      confidence: 0.6,
      source: 'social',
      category: 'social',
      lastUpdated: timestamp
    });

    // Factor 36: Celebrity/Influencer Following
    factors.set('influencerFollowing', {
      name: 'Influencer Following',
      value: socialData.influencerImpact || 0.3,
      weight: 0.1,
      confidence: 0.5,
      source: 'social',
      category: 'social',
      lastUpdated: timestamp
    });

    // Factor 37: Friend Recommendations
    factors.set('friendRecommendations', {
      name: 'Friend Recommendations',
      value: socialData.friendRecommendations || [],
      weight: 0.14,
      confidence: 0.8,
      source: 'social',
      category: 'social',
      lastUpdated: timestamp
    });

    // Factor 38: Social Validation Seeking
    factors.set('socialValidation', {
      name: 'Social Validation',
      value: this.calculateSocialValidationTendency(socialData),
      weight: 0.08,
      confidence: 0.5,
      source: 'inferred',
      category: 'social',
      lastUpdated: timestamp
    });

    // Factor 39: Group Shopping Behavior
    factors.set('groupShopping', {
      name: 'Group Shopping',
      value: socialData.groupShoppingFrequency || 0,
      weight: 0.1,
      confidence: 0.6,
      source: 'implicit',
      category: 'social',
      lastUpdated: timestamp
    });
  }

  private async collectPersonalFactors(
    factors: Map<string, PersonalizationFactor>,
    preferences: IUserPreferences,
    timestamp: Date
  ): Promise<void> {
    // Factor 40: Budget Constraints
    factors.set('budgetConstraints', {
      name: 'Budget Constraints',
      value: preferences.shopping.priceRange.max,
      weight: 0.25,
      confidence: 0.9,
      source: 'explicit',
      category: 'personal',
      lastUpdated: timestamp
    });

    // Factor 41: Sustainability Importance
    factors.set('sustainabilityImportance', {
      name: 'Sustainability Importance',
      value: preferences.shopping.sustainability.importance,
      weight: 0.18,
      confidence: 0.85,
      source: 'explicit',
      category: 'personal',
      lastUpdated: timestamp
    });

    // Factor 42: Style Consistency
    factors.set('styleConsistency', {
      name: 'Style Consistency',
      value: this.calculateStyleConsistency(preferences.shopping.style.preferences),
      weight: 0.15,
      confidence: 0.8,
      source: 'inferred',
      category: 'personal',
      lastUpdated: timestamp
    });

    // Factor 43: Color Preferences Strength
    factors.set('colorPreferenceStrength', {
      name: 'Color Preference Strength',
      value: preferences.shopping.style.colors.length,
      weight: 0.12,
      confidence: 0.9,
      source: 'explicit',
      category: 'personal',
      lastUpdated: timestamp
    });

    // Factor 44: Size Consistency
    factors.set('sizeConsistency', {
      name: 'Size Consistency',
      value: this.calculateSizeConsistency(preferences.shopping.sizes),
      weight: 0.1,
      confidence: 0.95,
      source: 'explicit',
      category: 'personal',
      lastUpdated: timestamp
    });

    // Factor 45: Brand Diversity
    factors.set('brandDiversity', {
      name: 'Brand Diversity',
      value: preferences.shopping.favoriteBrands.length,
      weight: 0.08,
      confidence: 0.8,
      source: 'explicit',
      category: 'personal',
      lastUpdated: timestamp
    });

    // Factor 46: Occasion Diversity
    factors.set('occasionDiversity', {
      name: 'Occasion Diversity',
      value: preferences.shopping.style.occasions.length,
      weight: 0.1,
      confidence: 0.85,
      source: 'explicit',
      category: 'personal',
      lastUpdated: timestamp
    });
  }

  private async collectInferredFactors(
    factors: Map<string, PersonalizationFactor>,
    userId: string,
    preferences: IUserPreferences,
    context: RecommendationContext,
    timestamp: Date
  ): Promise<void> {
    // Factor 47: Laundry Status Impact
    if (context.wardrobeStatus) {
      factors.set('laundryStatus', {
        name: 'Laundry Status',
        value: context.wardrobeStatus.laundryPending.length,
        weight: 0.12,
        confidence: 0.7,
        source: 'environmental',
        category: 'personal',
        lastUpdated: timestamp
      });

      // Factor 48: Wardrobe Availability
      factors.set('wardrobeAvailability', {
        name: 'Wardrobe Availability',
        value: context.wardrobeStatus.availableItems.length,
        weight: 0.15,
        confidence: 0.8,
        source: 'environmental',
        category: 'personal',
        lastUpdated: timestamp
      });
    }

    // Factor 49: Recent Purchase Fatigue
    factors.set('purchaseFatigue', {
      name: 'Purchase Fatigue',
      value: this.calculatePurchaseFatigue(context.recentPurchases || []),
      weight: 0.1,
      confidence: 0.6,
      source: 'inferred',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 50: Style Evolution Trend
    factors.set('styleEvolution', {
      name: 'Style Evolution',
      value: await this.calculateStyleEvolution(userId),
      weight: 0.08,
      confidence: 0.5,
      source: 'inferred',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 51: Decision Making Speed
    factors.set('decisionSpeed', {
      name: 'Decision Speed',
      value: await this.calculateDecisionSpeed(userId),
      weight: 0.1,
      confidence: 0.6,
      source: 'inferred',
      category: 'behavioral',
      lastUpdated: timestamp
    });

    // Factor 52: Risk Tolerance in Fashion
    factors.set('fashionRiskTolerance', {
      name: 'Fashion Risk Tolerance',
      value: this.calculateFashionRiskTolerance(preferences),
      weight: 0.12,
      confidence: 0.7,
      source: 'inferred',
      category: 'personal',
      lastUpdated: timestamp
    });

    // Factor 53: Seasonal Adaptation Rate
    factors.set('seasonalAdaptation', {
      name: 'Seasonal Adaptation',
      value: await this.calculateSeasonalAdaptation(userId),
      weight: 0.1,
      confidence: 0.6,
      source: 'inferred',
      category: 'temporal',
      lastUpdated: timestamp
    });
  }

  // Utility methods for calculations
  private getSeason(month: number): string {
    if (month >= 2 && month <= 4) return 'spring';
    if (month >= 5 && month <= 7) return 'summer';
    if (month >= 8 && month <= 10) return 'fall';
    return 'winter';
  }

  private calculateWeatherComfort(temperature: number, humidity: number): number {
    // Simple heat index calculation
    const hi = temperature - (0.55 - 0.0055 * humidity) * (temperature - 58);
    return Math.max(0, Math.min(100, (100 - Math.abs(hi - 75)) / 25));
  }

  private inferClimateZone(latitude: number): string {
    if (Math.abs(latitude) < 23.5) return 'tropical';
    if (Math.abs(latitude) < 35) return 'subtropical';
    if (Math.abs(latitude) < 50) return 'temperate';
    return 'cold';
  }

  private async getAirQuality(location?: any): Promise<number> {
    // Placeholder - would integrate with air quality API
    return Math.random() * 100;
  }

  private async getUVIndex(location?: any): Promise<number> {
    // Placeholder - would integrate with UV index API
    return Math.random() * 11;
  }

  private calculateShoppingFrequency(purchases: IProduct[]): number {
    if (purchases.length === 0) return 0;
    const daysSinceFirst = (Date.now() - purchases[0].createdAt.getTime()) / (1000 * 60 * 60 * 24);
    return purchases.length / Math.max(1, daysSinceFirst / 30); // purchases per month
  }

  private calculateBrowseBuyRatio(interactions: any[], purchases: IProduct[]): number {
    const browseCount = interactions.filter(i => i.type === 'view').length;
    const buyCount = purchases.length;
    return buyCount / Math.max(1, browseCount);
  }

  private calculateBrandLoyalty(purchases: IProduct[]): number {
    if (purchases.length === 0) return 0;
    const brandCounts = new Map();
    purchases.forEach(p => {
      brandCounts.set(p.brand, (brandCounts.get(p.brand) || 0) + 1);
    });
    const maxBrandCount = Math.max(...brandCounts.values());
    return maxBrandCount / purchases.length;
  }

  private calculatePriceSensitivity(purchases: IProduct[], interactions: any[]): number {
    if (purchases.length === 0) return 0.5;
    const avgPrice = purchases.reduce((sum, p) => sum + p.price.current, 0) / purchases.length;
    const viewedItems = interactions.filter(i => i.type === 'view' && i.product);
    if (viewedItems.length === 0) return 0.5;
    const avgViewedPrice = viewedItems.reduce((sum, i) => sum + i.product.price, 0) / viewedItems.length;
    return 1 - (avgPrice / Math.max(avgViewedPrice, 1));
  }

  private calculateImpulseBuyingTendency(purchases: IProduct[]): number {
    // Calculate based on time between first view and purchase
    // Placeholder implementation
    return Math.random() * 0.5;
  }

  private calculateDiscoveryTendency(interactions: any[]): number {
    const searchInteractions = interactions.filter(i => i.type === 'search').length;
    const browseInteractions = interactions.filter(i => i.type === 'browse').length;
    return browseInteractions / Math.max(1, searchInteractions + browseInteractions);
  }

  private inferWorkSchedule(context: RecommendationContext): string {
    const hour = new Date(context.timestamp).getHours();
    const day = new Date(context.timestamp).getDay();

    if (day >= 1 && day <= 5 && hour >= 9 && hour <= 17) {
      return 'traditional';
    } else if (day >= 1 && day <= 5) {
      return 'flexible';
    }
    return 'non-traditional';
  }

  private async getSocialMediaInfluence(userId: string): Promise<number> {
    // Placeholder - would integrate with social media APIs
    return Math.random() * 0.8;
  }

  private calculateSocialValidationTendency(socialData: any): number {
    return socialData.likesImportance || Math.random() * 0.6;
  }

  private calculateStyleConsistency(stylePreferences: string[]): number {
    // Higher consistency = fewer diverse style preferences
    return Math.max(0, 1 - (stylePreferences.length / 6));
  }

  private calculateSizeConsistency(sizes: any): number {
    const allSizes = [...sizes.tops, ...sizes.bottoms, ...sizes.shoes, ...sizes.dresses];
    const uniqueSizes = new Set(allSizes);
    return uniqueSizes.size / Math.max(1, allSizes.length);
  }

  private calculatePurchaseFatigue(recentPurchases: IProduct[]): number {
    const recentCount = recentPurchases.filter(p =>
      Date.now() - p.createdAt.getTime() < 7 * 24 * 60 * 60 * 1000 // Last 7 days
    ).length;
    return Math.min(1, recentCount / 5); // Fatigue increases with recent purchases
  }

  private async calculateStyleEvolution(userId: string): Promise<number> {
    // Placeholder - would analyze style changes over time
    return Math.random() * 0.3;
  }

  private async calculateDecisionSpeed(userId: string): Promise<number> {
    // Placeholder - would analyze time from view to purchase
    return Math.random() * 1;
  }

  private calculateFashionRiskTolerance(preferences: IUserPreferences): number {
    const conservativeStyles = ['classic', 'minimalist', 'traditional'];
    const riskScore = preferences.shopping.style.preferences.some(style =>
      conservativeStyles.includes(style)
    ) ? 0.3 : 0.7;
    return riskScore;
  }

  private async calculateSeasonalAdaptation(userId: string): Promise<number> {
    // Placeholder - would analyze how quickly user adapts to season changes
    return Math.random() * 0.8;
  }

  private generateContextHash(context: RecommendationContext): string {
    const contextString = `${context.timeOfDay}_${context.dayOfWeek}_${context.weather?.condition}_${context.location?.context}`;
    return Buffer.from(contextString).toString('base64');
  }

  getFactorsByCategory(profile: PersonalizationProfile, category: string): PersonalizationFactor[] {
    return Array.from(profile.factors.values()).filter(f => f.category === category);
  }

  getTopFactors(profile: PersonalizationProfile, count: number = 10): PersonalizationFactor[] {
    return Array.from(profile.factors.values())
      .sort((a, b) => (b.weight * b.confidence) - (a.weight * a.confidence))
      .slice(0, count);
  }

  updateFactor(
    profile: PersonalizationProfile,
    factorName: string,
    value: number | string | boolean,
    confidence?: number
  ): void {
    const factor = profile.factors.get(factorName);
    if (factor) {
      factor.value = value;
      factor.lastUpdated = new Date();
      if (confidence !== undefined) {
        factor.confidence = confidence;
      }
    }
  }
}