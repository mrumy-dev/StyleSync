import { Product, PriceHistory } from '../models/Product';
import { logger } from '../middleware/ErrorHandler';

export interface PricePrediction {
  predictedPrice: number;
  confidence: number;
  trend: 'increasing' | 'decreasing' | 'stable';
  timeframe: number; // days
  factors: PriceFactor[];
}

export interface PriceFactor {
  factor: string;
  impact: number; // -1 to 1
  confidence: number;
  description: string;
}

export interface CompetitorAnalysis {
  productId: string;
  competitors: CompetitorPrice[];
  positionRanking: number; // 1-based ranking
  averageMarketPrice: number;
  priceAdvantage: number; // percentage vs market
  recommendedAction: 'hold' | 'monitor' | 'alert_user';
}

export interface CompetitorPrice {
  store: string;
  price: number;
  availability: boolean;
  shippingCost?: number;
  totalCost: number;
  url?: string;
  lastUpdated: Date;
}

export interface DealScore {
  score: number; // 0-100
  classification: 'excellent' | 'good' | 'fair' | 'poor';
  factors: {
    historicalComparison: number;
    marketComparison: number;
    trendAnalysis: number;
    seasonality: number;
  };
  recommendation: string;
}

export interface CurrencyRate {
  from: string;
  to: string;
  rate: number;
  lastUpdated: Date;
}

export class PriceIntelligenceEngine {
  private currencyRates: Map<string, CurrencyRate[]> = new Map();
  private seasonalityData: Map<string, SeasonalTrend[]> = new Map();
  private taxRates: Map<string, TaxInfo> = new Map();

  constructor() {
    this.initializeCurrencyRates();
    this.initializeSeasonalityData();
    this.initializeTaxRates();
  }

  async analyzePriceHistory(productId: string, history: PriceHistory[]): Promise<PricePrediction> {
    if (history.length < 7) {
      return {
        predictedPrice: history[history.length - 1]?.price || 0,
        confidence: 0.3,
        trend: 'stable',
        timeframe: 30,
        factors: [{
          factor: 'insufficient_data',
          impact: 0,
          confidence: 1,
          description: 'Not enough historical data for accurate prediction'
        }]
      };
    }

    const sortedHistory = history.sort((a, b) => a.recordedAt.getTime() - b.recordedAt.getTime());
    const recentPrices = sortedHistory.slice(-30); // Last 30 entries
    const factors: PriceFactor[] = [];

    // Calculate trend using linear regression
    const trendAnalysis = this.calculateTrend(recentPrices);
    factors.push({
      factor: 'price_trend',
      impact: trendAnalysis.slope > 0 ? 0.3 : -0.3,
      confidence: trendAnalysis.correlation,
      description: `Price ${trendAnalysis.slope > 0 ? 'increasing' : 'decreasing'} trend detected`
    });

    // Volatility analysis
    const volatility = this.calculateVolatility(recentPrices);
    factors.push({
      factor: 'volatility',
      impact: volatility > 0.1 ? 0.2 : -0.1,
      confidence: 0.8,
      description: `${volatility > 0.1 ? 'High' : 'Low'} price volatility detected`
    });

    // Seasonality impact
    const seasonalImpact = this.analyzeSeasonality(productId, new Date());
    if (seasonalImpact) {
      factors.push(seasonalImpact);
    }

    // Cyclical patterns
    const cyclicalPattern = this.detectCyclicalPatterns(recentPrices);
    if (cyclicalPattern) {
      factors.push(cyclicalPattern);
    }

    // Calculate prediction
    const currentPrice = recentPrices[recentPrices.length - 1].price;
    const trendImpact = trendAnalysis.slope * 30; // 30-day projection
    const seasonalAdjustment = seasonalImpact ? seasonalImpact.impact * currentPrice * 0.1 : 0;
    const cyclicalAdjustment = cyclicalPattern ? cyclicalPattern.impact * currentPrice * 0.05 : 0;

    const predictedPrice = Math.max(0, currentPrice + trendImpact + seasonalAdjustment + cyclicalAdjustment);

    // Calculate overall confidence
    const avgConfidence = factors.reduce((sum, f) => sum + f.confidence, 0) / factors.length;

    return {
      predictedPrice,
      confidence: Math.min(avgConfidence * (history.length / 50), 0.95), // Cap at 95%
      trend: trendAnalysis.slope > 0.01 ? 'increasing' : trendAnalysis.slope < -0.01 ? 'decreasing' : 'stable',
      timeframe: 30,
      factors
    };
  }

  async analyzeCompetitors(productId: string, competitors: Product[]): Promise<CompetitorAnalysis> {
    const competitorPrices: CompetitorPrice[] = competitors.map(competitor => ({
      store: competitor.store || 'Unknown',
      price: competitor.currentPrice || 0,
      availability: competitor.availability || false,
      shippingCost: competitor.shippingCost,
      totalCost: (competitor.currentPrice || 0) + (competitor.shippingCost || 0),
      url: competitor.url,
      lastUpdated: competitor.lastUpdated || new Date()
    }));

    // Sort by total cost
    competitorPrices.sort((a, b) => a.totalCost - b.totalCost);

    // Find current product position
    const currentProduct = competitors.find(c => c.id === productId);
    const currentPrice = currentProduct?.currentPrice || 0;
    const currentTotalCost = currentPrice + (currentProduct?.shippingCost || 0);

    let positionRanking = 1;
    for (const competitor of competitorPrices) {
      if (competitor.totalCost < currentTotalCost) {
        positionRanking++;
      } else {
        break;
      }
    }

    // Calculate market statistics
    const availablePrices = competitorPrices.filter(c => c.availability).map(c => c.totalCost);
    const averageMarketPrice = availablePrices.reduce((sum, price) => sum + price, 0) / availablePrices.length;
    const priceAdvantage = ((averageMarketPrice - currentTotalCost) / averageMarketPrice) * 100;

    // Determine recommended action
    let recommendedAction: 'hold' | 'monitor' | 'alert_user' = 'hold';
    if (positionRanking <= 3 && priceAdvantage > 10) {
      recommendedAction = 'hold';
    } else if (positionRanking > 3 || priceAdvantage < -5) {
      recommendedAction = 'alert_user';
    } else {
      recommendedAction = 'monitor';
    }

    return {
      productId,
      competitors: competitorPrices,
      positionRanking,
      averageMarketPrice,
      priceAdvantage,
      recommendedAction
    };
  }

  async calculateDealScore(product: Product, history: PriceHistory[], competitors: Product[]): Promise<DealScore> {
    const currentPrice = product.currentPrice || 0;
    const factors = {
      historicalComparison: 0,
      marketComparison: 0,
      trendAnalysis: 0,
      seasonality: 0
    };

    // Historical comparison (40% weight)
    if (history.length > 0) {
      const avgHistoricalPrice = history.reduce((sum, h) => sum + h.price, 0) / history.length;
      const minPrice = Math.min(...history.map(h => h.price));
      const maxPrice = Math.max(...history.map(h => h.price));

      if (avgHistoricalPrice > 0) {
        const historicalDiscount = ((avgHistoricalPrice - currentPrice) / avgHistoricalPrice) * 100;
        factors.historicalComparison = Math.max(0, Math.min(100, historicalDiscount * 2));
      }
    }

    // Market comparison (30% weight)
    if (competitors.length > 0) {
      const competitorPrices = competitors
        .filter(c => c.currentPrice && c.availability)
        .map(c => c.currentPrice!);

      if (competitorPrices.length > 0) {
        const avgMarketPrice = competitorPrices.reduce((sum, price) => sum + price, 0) / competitorPrices.length;
        const marketDiscount = ((avgMarketPrice - currentPrice) / avgMarketPrice) * 100;
        factors.marketComparison = Math.max(0, Math.min(100, marketDiscount * 2));
      }
    }

    // Trend analysis (20% weight)
    if (history.length >= 7) {
      const recentHistory = history.slice(-14);
      const trend = this.calculateTrend(recentHistory);

      if (trend.slope < 0) {
        // Price is trending down - better deal
        factors.trendAnalysis = Math.min(100, Math.abs(trend.slope) * 100);
      } else {
        // Price is trending up - may get worse
        factors.trendAnalysis = Math.max(0, 50 - (trend.slope * 100));
      }
    } else {
      factors.trendAnalysis = 50; // Neutral when no trend data
    }

    // Seasonality (10% weight)
    const seasonalFactor = this.analyzeSeasonality(product.id, new Date());
    if (seasonalFactor) {
      factors.seasonality = seasonalFactor.impact > 0 ? 75 : 25; // Good season vs bad season
    } else {
      factors.seasonality = 50; // Neutral
    }

    // Calculate weighted score
    const score = Math.round(
      (factors.historicalComparison * 0.4) +
      (factors.marketComparison * 0.3) +
      (factors.trendAnalysis * 0.2) +
      (factors.seasonality * 0.1)
    );

    // Classify the deal
    let classification: DealScore['classification'];
    let recommendation: string;

    if (score >= 80) {
      classification = 'excellent';
      recommendation = 'Outstanding deal! This is significantly better than historical and market averages.';
    } else if (score >= 65) {
      classification = 'good';
      recommendation = 'Good deal! Price is favorable compared to recent history and competitors.';
    } else if (score >= 40) {
      classification = 'fair';
      recommendation = 'Fair price. Consider waiting for a better deal or comparing alternatives.';
    } else {
      classification = 'poor';
      recommendation = 'Not a great deal. Price is above historical average and market competition.';
    }

    return {
      score,
      classification,
      factors,
      recommendation
    };
  }

  async convertCurrency(amount: number, fromCurrency: string, toCurrency: string): Promise<number> {
    if (fromCurrency === toCurrency) return amount;

    const rates = this.currencyRates.get(fromCurrency);
    if (!rates) {
      throw new Error(`Currency rates not available for ${fromCurrency}`);
    }

    const rate = rates.find(r => r.to === toCurrency);
    if (!rate) {
      throw new Error(`Conversion rate not available from ${fromCurrency} to ${toCurrency}`);
    }

    // Check if rate is recent (within 24 hours)
    const ageHours = (Date.now() - rate.lastUpdated.getTime()) / (1000 * 60 * 60);
    if (ageHours > 24) {
      logger.warn(`Currency rate for ${fromCurrency}->${toCurrency} is ${ageHours.toFixed(1)} hours old`);
    }

    return amount * rate.rate;
  }

  async calculateTotalCost(product: Product, userLocation: string, currency: string = 'USD'): Promise<TotalCostBreakdown> {
    const basePrice = product.currentPrice || 0;
    let convertedPrice = basePrice;

    // Convert currency if needed
    if (product.currency && product.currency !== currency) {
      convertedPrice = await this.convertCurrency(basePrice, product.currency, currency);
    }

    // Calculate tax
    const taxInfo = this.taxRates.get(userLocation);
    const taxAmount = taxInfo ? convertedPrice * (taxInfo.rate / 100) : 0;

    // Calculate shipping
    const shippingCost = product.shippingCost || 0;
    const convertedShipping = product.currency && product.currency !== currency
      ? await this.convertCurrency(shippingCost, product.currency, currency)
      : shippingCost;

    // Calculate duties for international orders
    let dutyAmount = 0;
    if (product.store && this.isInternationalOrder(product.store, userLocation)) {
      const dutyRate = this.getDutyRate(product.category?.main || 'general', userLocation);
      dutyAmount = convertedPrice * dutyRate;
    }

    const totalCost = convertedPrice + taxAmount + convertedShipping + dutyAmount;

    return {
      basePrice: convertedPrice,
      tax: taxAmount,
      shipping: convertedShipping,
      duties: dutyAmount,
      total: totalCost,
      currency,
      breakdown: {
        basePricePercentage: (convertedPrice / totalCost) * 100,
        taxPercentage: (taxAmount / totalCost) * 100,
        shippingPercentage: (convertedShipping / totalCost) * 100,
        dutiesPercentage: (dutyAmount / totalCost) * 100
      }
    };
  }

  private calculateTrend(history: PriceHistory[]): { slope: number; correlation: number } {
    if (history.length < 2) return { slope: 0, correlation: 0 };

    const n = history.length;
    const xValues = history.map((_, index) => index);
    const yValues = history.map(h => h.price);

    const sumX = xValues.reduce((sum, x) => sum + x, 0);
    const sumY = yValues.reduce((sum, y) => sum + y, 0);
    const sumXY = xValues.reduce((sum, x, i) => sum + x * yValues[i], 0);
    const sumXX = xValues.reduce((sum, x) => sum + x * x, 0);
    const sumYY = yValues.reduce((sum, y) => sum + y * y, 0);

    const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);

    // Calculate correlation coefficient
    const correlation = (n * sumXY - sumX * sumY) /
      Math.sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY));

    return {
      slope: isNaN(slope) ? 0 : slope,
      correlation: isNaN(correlation) ? 0 : Math.abs(correlation)
    };
  }

  private calculateVolatility(history: PriceHistory[]): number {
    if (history.length < 2) return 0;

    const prices = history.map(h => h.price);
    const mean = prices.reduce((sum, price) => sum + price, 0) / prices.length;
    const variance = prices.reduce((sum, price) => sum + Math.pow(price - mean, 2), 0) / prices.length;
    const standardDeviation = Math.sqrt(variance);

    return mean > 0 ? standardDeviation / mean : 0; // Coefficient of variation
  }

  private analyzeSeasonality(productId: string, date: Date): PriceFactor | null {
    // This is a simplified seasonality analysis
    const month = date.getMonth();
    const category = this.getCategoryFromProductId(productId);

    let seasonalImpact = 0;
    let description = '';

    switch (category) {
      case 'clothing':
        if ([10, 11, 0].includes(month)) { // Nov, Dec, Jan - winter sales
          seasonalImpact = -0.2;
          description = 'Winter season - typically good deals on clothing';
        } else if ([5, 6, 7].includes(month)) { // Jun, Jul, Aug - summer
          seasonalImpact = 0.1;
          description = 'Summer season - higher demand for clothing';
        }
        break;
      case 'electronics':
        if ([10, 11].includes(month)) { // Black Friday, Cyber Monday
          seasonalImpact = -0.3;
          description = 'Holiday season - expect significant electronics discounts';
        } else if ([8, 9].includes(month)) { // Back to school
          seasonalImpact = 0.1;
          description = 'Back-to-school season - higher electronics prices';
        }
        break;
    }

    return seasonalImpact !== 0 ? {
      factor: 'seasonality',
      impact: seasonalImpact,
      confidence: 0.7,
      description
    } : null;
  }

  private detectCyclicalPatterns(history: PriceHistory[]): PriceFactor | null {
    if (history.length < 14) return null;

    // Look for weekly patterns (7-day cycles)
    const weeklyPattern = this.findCyclicalPattern(history, 7);
    if (weeklyPattern && weeklyPattern.strength > 0.6) {
      return {
        factor: 'weekly_cycle',
        impact: weeklyPattern.impact,
        confidence: weeklyPattern.strength,
        description: `Weekly pricing pattern detected - ${weeklyPattern.impact > 0 ? 'prices typically higher' : 'prices typically lower'} at this time`
      };
    }

    return null;
  }

  private findCyclicalPattern(history: PriceHistory[], cycleLength: number): { impact: number; strength: number } | null {
    if (history.length < cycleLength * 2) return null;

    const cycles: number[][] = [];
    for (let i = 0; i <= history.length - cycleLength; i += cycleLength) {
      const cycle = history.slice(i, i + cycleLength).map(h => h.price);
      if (cycle.length === cycleLength) {
        cycles.push(cycle);
      }
    }

    if (cycles.length < 2) return null;

    // Calculate average pattern
    const averagePattern = new Array(cycleLength).fill(0);
    cycles.forEach(cycle => {
      cycle.forEach((price, index) => {
        averagePattern[index] += price / cycles.length;
      });
    });

    // Calculate pattern strength (how consistent the pattern is)
    let strength = 0;
    cycles.forEach(cycle => {
      const correlation = this.calculateCorrelation(cycle, averagePattern);
      strength += correlation;
    });
    strength /= cycles.length;

    // Calculate current position impact
    const currentDayOfCycle = history.length % cycleLength;
    const avgPrice = averagePattern.reduce((sum, p) => sum + p, 0) / averagePattern.length;
    const currentPositionPrice = averagePattern[currentDayOfCycle];
    const impact = avgPrice > 0 ? (currentPositionPrice - avgPrice) / avgPrice : 0;

    return { impact, strength: Math.abs(strength) };
  }

  private calculateCorrelation(array1: number[], array2: number[]): number {
    const n = array1.length;
    const sum1 = array1.reduce((sum, x) => sum + x, 0);
    const sum2 = array2.reduce((sum, x) => sum + x, 0);
    const sum12 = array1.reduce((sum, x, i) => sum + x * array2[i], 0);
    const sum11 = array1.reduce((sum, x) => sum + x * x, 0);
    const sum22 = array2.reduce((sum, x) => sum + x * x, 0);

    const correlation = (n * sum12 - sum1 * sum2) /
      Math.sqrt((n * sum11 - sum1 * sum1) * (n * sum22 - sum2 * sum2));

    return isNaN(correlation) ? 0 : correlation;
  }

  private getCategoryFromProductId(productId: string): string {
    // In a real implementation, this would look up the product category
    // For now, return a default
    return 'general';
  }

  private isInternationalOrder(store: string, userLocation: string): boolean {
    // Simple heuristic - in production, this would be more sophisticated
    const storeCountry = this.getStoreCountry(store);
    const userCountry = this.getUserCountry(userLocation);
    return storeCountry !== userCountry;
  }

  private getStoreCountry(store: string): string {
    // Simplified mapping
    const storeCountries: Record<string, string> = {
      'amazon': 'US',
      'zalando': 'DE',
      'asos': 'UK',
      'shein': 'CN'
    };
    return storeCountries[store.toLowerCase()] || 'US';
  }

  private getUserCountry(location: string): string {
    // Extract country from location string
    return location.split(',').pop()?.trim() || 'US';
  }

  private getDutyRate(category: string, location: string): number {
    // Simplified duty rates - in production, use official tariff databases
    const dutyRates: Record<string, number> = {
      'clothing': 0.12,
      'electronics': 0.08,
      'shoes': 0.15,
      'general': 0.10
    };
    return dutyRates[category] || 0.10;
  }

  private initializeCurrencyRates(): void {
    // In production, fetch real-time rates from currency API
    const rates = [
      { from: 'USD', to: 'EUR', rate: 0.85, lastUpdated: new Date() },
      { from: 'USD', to: 'GBP', rate: 0.75, lastUpdated: new Date() },
      { from: 'EUR', to: 'USD', rate: 1.18, lastUpdated: new Date() },
      { from: 'GBP', to: 'USD', rate: 1.33, lastUpdated: new Date() }
    ];

    rates.forEach(rate => {
      if (!this.currencyRates.has(rate.from)) {
        this.currencyRates.set(rate.from, []);
      }
      this.currencyRates.get(rate.from)!.push(rate);
    });
  }

  private initializeSeasonalityData(): void {
    // Initialize with typical seasonal patterns
    // In production, this would be learned from historical data
  }

  private initializeTaxRates(): void {
    // Initialize with common tax rates
    this.taxRates.set('US-CA', { rate: 8.25, type: 'sales_tax' });
    this.taxRates.set('US-NY', { rate: 8.0, type: 'sales_tax' });
    this.taxRates.set('UK', { rate: 20.0, type: 'vat' });
    this.taxRates.set('DE', { rate: 19.0, type: 'vat' });
  }
}

interface SeasonalTrend {
  month: number;
  impact: number;
  confidence: number;
}

interface TaxInfo {
  rate: number;
  type: 'sales_tax' | 'vat' | 'gst';
}

interface TotalCostBreakdown {
  basePrice: number;
  tax: number;
  shipping: number;
  duties: number;
  total: number;
  currency: string;
  breakdown: {
    basePricePercentage: number;
    taxPercentage: number;
    shippingPercentage: number;
    dutiesPercentage: number;
  };
}