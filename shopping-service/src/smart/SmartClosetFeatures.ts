import { IClothingItem } from '../models/ClothingItem';
import { IOutfit } from '../models/Outfit';
import { ICloset } from '../models/Closet';

export interface OutfitPreparation {
  id: string;
  userId: string;
  occasion: string;
  date: Date;
  weather: {
    temperature: { min: number; max: number };
    conditions: string[];
    humidity: number;
    windSpeed: number;
  };
  location: {
    venue: string;
    indoor: boolean;
    formality: string;
    dresscode?: string;
  };
  suggestions: Array<{
    outfitId: string;
    items: string[];
    confidence: number;
    reasoning: string[];
    alternatives: Record<string, string[]>;
  }>;
  preparation: {
    timeNeeded: number;
    steps: PreparationStep[];
    reminders: Reminder[];
  };
  status: 'planned' | 'prepared' | 'worn' | 'cancelled';
}

export interface PreparationStep {
  id: string;
  type: 'iron' | 'steam' | 'polish' | 'accessorize' | 'check_fit' | 'spot_clean';
  itemId: string;
  description: string;
  estimatedTime: number;
  priority: 'low' | 'medium' | 'high' | 'critical';
  completed: boolean;
  dependencies?: string[];
}

export interface Reminder {
  id: string;
  type: 'preparation' | 'weather_check' | 'backup_plan' | 'accessories';
  message: string;
  scheduledFor: Date;
  recurring: boolean;
  sent: boolean;
}

export interface PackingPlan {
  id: string;
  userId: string;
  tripId: string;
  destination: {
    location: string;
    climate: string;
    duration: number;
    activities: string[];
  };
  outfits: Array<{
    day: number;
    occasion: string;
    outfitId?: string;
    items: string[];
    packed: boolean;
    notes?: string;
  }>;
  essentials: {
    underwear: number;
    socks: number;
    sleepwear: number;
    accessories: string[];
  };
  packing: {
    method: 'rolling' | 'folding' | 'bundle' | 'mixed';
    luggage: LuggageInfo[];
    weight: number;
    volume: number;
  };
  checklist: PackingItem[];
  status: 'planning' | 'packing' | 'packed' | 'travelling';
}

export interface LuggageInfo {
  id: string;
  type: 'carry_on' | 'checked' | 'personal';
  capacity: { weight: number; volume: number };
  items: string[];
  restrictions: string[];
}

export interface PackingItem {
  itemId: string;
  category: string;
  priority: 'essential' | 'important' | 'optional';
  packed: boolean;
  luggage?: string;
  notes?: string;
}

export interface LendingRecord {
  id: string;
  userId: string;
  itemId: string;
  borrower: {
    name: string;
    contact: string;
    relationship: string;
  };
  lentDate: Date;
  expectedReturn: Date;
  actualReturn?: Date;
  condition: {
    lent: string;
    returned?: string;
    notes?: string[];
  };
  reminders: {
    sent: number;
    nextReminder?: Date;
    frequency: number;
  };
  status: 'active' | 'returned' | 'overdue' | 'damaged' | 'lost';
  value: number;
  insurance: boolean;
}

export interface MissingItemTracker {
  itemId: string;
  lastSeen: {
    date: Date;
    location: string;
    context: string;
  };
  searchHistory: Array<{
    date: Date;
    locations: string[];
    result: 'not_found' | 'found_elsewhere' | 'still_missing';
    notes?: string;
  }>;
  alerts: {
    priority: 'low' | 'medium' | 'high' | 'urgent';
    frequency: number;
    lastSent: Date;
  };
  suggestions: {
    likelyLocations: string[];
    checkWithPeople: string[];
    alternativeItems: string[];
  };
  resolution?: {
    found: boolean;
    location?: string;
    date: Date;
    condition?: string;
  };
}

export interface GapAnalysis {
  category: string;
  missing: Array<{
    type: string;
    priority: 'essential' | 'important' | 'nice_to_have';
    reason: string;
    estimatedCost: number;
    suggestions: string[];
  }>;
  oversupplied: Array<{
    type: string;
    count: number;
    suggestion: 'donate' | 'store' | 'repurpose';
    items: string[];
  }>;
  recommendations: Array<{
    action: 'buy' | 'donate' | 'reorganize' | 'repair';
    items: string[];
    priority: number;
    reasoning: string;
  }>;
}

export interface PurchaseSuggestion {
  id: string;
  category: string;
  type: string;
  priority: 'low' | 'medium' | 'high' | 'urgent';
  reasoning: string[];
  budget: {
    min: number;
    max: number;
    recommended: number;
  };
  specifications: {
    colors: string[];
    materials: string[];
    features: string[];
    brands: string[];
  };
  occasions: string[];
  season: string[];
  versatility: number;
  urgency: Date;
}

export interface DonationCandidate {
  itemId: string;
  reasons: string[];
  confidence: number;
  value: {
    current: number;
    donation: number;
    taxDeduction: number;
  };
  recipient: {
    type: 'charity' | 'friend' | 'consignment' | 'recycling';
    suggestions: string[];
  };
  preparation: {
    cleaning: boolean;
    repair: boolean;
    documentation: boolean;
  };
}

export class SmartClosetFeatures {
  async prepareOutfit(
    userId: string,
    occasion: string,
    date: Date,
    weather: any,
    location: any
  ): Promise<OutfitPreparation> {
    const outfitSuggestions = await this.generateOutfitSuggestions(userId, occasion, weather, location);
    const steps = await this.createPreparationSteps(outfitSuggestions[0]?.items || []);
    const reminders = this.generateReminders(date, steps);

    return {
      id: `prep_${Date.now()}`,
      userId,
      occasion,
      date,
      weather,
      location,
      suggestions: outfitSuggestions,
      preparation: {
        timeNeeded: steps.reduce((total, step) => total + step.estimatedTime, 0),
        steps,
        reminders
      },
      status: 'planned'
    };
  }

  async createPackingPlan(
    userId: string,
    tripDetails: {
      destination: string;
      startDate: Date;
      endDate: Date;
      activities: string[];
      climate: string;
    }
  ): Promise<PackingPlan> {
    const duration = Math.ceil((tripDetails.endDate.getTime() - tripDetails.startDate.getTime()) / 86400000);
    const outfits = await this.planTripOutfits(userId, tripDetails, duration);
    const essentials = this.calculateEssentials(duration, tripDetails.activities);
    const luggage = this.recommendLuggage(outfits, essentials, duration);

    return {
      id: `pack_${Date.now()}`,
      userId,
      tripId: `trip_${Date.now()}`,
      destination: {
        location: tripDetails.destination,
        climate: tripDetails.climate,
        duration,
        activities: tripDetails.activities
      },
      outfits,
      essentials,
      packing: {
        method: this.recommendPackingMethod(duration, outfits.length),
        luggage,
        weight: this.estimateWeight(outfits, essentials),
        volume: this.estimateVolume(outfits, essentials)
      },
      checklist: await this.generatePackingChecklist(outfits, essentials),
      status: 'planning'
    };
  }

  async trackLending(
    userId: string,
    itemId: string,
    borrower: {
      name: string;
      contact: string;
      relationship: string;
    },
    expectedReturn: Date
  ): Promise<LendingRecord> {
    const item = await this.getItemById(itemId);
    const value = this.estimateItemValue(item);

    const record: LendingRecord = {
      id: `lend_${Date.now()}`,
      userId,
      itemId,
      borrower,
      lentDate: new Date(),
      expectedReturn,
      condition: {
        lent: item.condition.status,
        notes: [`Item lent to ${borrower.name} on ${new Date().toISOString().split('T')[0]}`]
      },
      reminders: {
        sent: 0,
        nextReminder: new Date(expectedReturn.getTime() - 86400000),
        frequency: 7
      },
      status: 'active',
      value,
      insurance: value > 200
    };

    await this.saveLendingRecord(record);
    await this.scheduleReturnReminders(record);

    return record;
  }

  async detectMissingItems(userId: string): Promise<MissingItemTracker[]> {
    const items = await this.getUserItems(userId);
    const trackers: MissingItemTracker[] = [];

    for (const item of items) {
      if (this.isPotentiallyMissing(item)) {
        const tracker: MissingItemTracker = {
          itemId: item.id,
          lastSeen: {
            date: item.metadata.lastWorn || item.metadata.addedAt,
            location: 'closet',
            context: 'regular_use'
          },
          searchHistory: [],
          alerts: {
            priority: this.calculateMissingPriority(item),
            frequency: 7,
            lastSent: new Date(0)
          },
          suggestions: {
            likelyLocations: this.suggestSearchLocations(item),
            checkWithPeople: this.suggestPeopleToCheck(item),
            alternativeItems: await this.findAlternativeItems(userId, item)
          }
        };

        trackers.push(tracker);
      }
    }

    return trackers;
  }

  async analyzeGaps(userId: string): Promise<GapAnalysis> {
    const items = await this.getUserItems(userId);
    const outfits = await this.getUserOutfits(userId);

    const categoryAnalysis = this.analyzeCategoryDistribution(items);
    const occasionCoverage = this.analyzeOccasionCoverage(items, outfits);
    const seasonalCoverage = this.analyzeSeasonalCoverage(items);

    const missing = this.identifyMissingItems(categoryAnalysis, occasionCoverage, seasonalCoverage);
    const oversupplied = this.identifyOversuppliedItems(categoryAnalysis);
    const recommendations = this.generateGapRecommendations(missing, oversupplied);

    return {
      category: 'wardrobe_analysis',
      missing,
      oversupplied,
      recommendations
    };
  }

  async generatePurchaseSuggestions(
    userId: string,
    budget?: number,
    preferences?: {
      priorities?: string[];
      excludeCategories?: string[];
      maxItems?: number;
    }
  ): Promise<PurchaseSuggestion[]> {
    const gapAnalysis = await this.analyzeGaps(userId);
    const userStyle = await this.analyzeUserStyle(userId);
    const seasonalNeeds = this.assessSeasonalNeeds();

    const suggestions: PurchaseSuggestion[] = [];

    for (const gap of gapAnalysis.missing) {
      if (preferences?.excludeCategories?.includes(gap.type)) continue;

      const suggestion: PurchaseSuggestion = {
        id: `sug_${Date.now()}_${Math.random().toString(36).substr(2, 4)}`,
        category: gap.type,
        type: gap.type,
        priority: gap.priority === 'essential' ? 'urgent' : gap.priority === 'important' ? 'high' : 'medium',
        reasoning: [gap.reason, ...this.generateAdditionalReasons(gap, userStyle)],
        budget: {
          min: gap.estimatedCost * 0.7,
          max: gap.estimatedCost * 1.5,
          recommended: gap.estimatedCost
        },
        specifications: this.generateSpecifications(gap, userStyle),
        occasions: this.getRelevantOccasions(gap.type),
        season: this.getRelevantSeasons(gap.type),
        versatility: this.calculateVersatility(gap.type),
        urgency: this.calculateUrgencyDate(gap.priority)
      };

      suggestions.push(suggestion);
    }

    if (budget) {
      return this.prioritizeBudget(suggestions, budget);
    }

    return suggestions.sort((a, b) => {
      const priorityOrder = { urgent: 4, high: 3, medium: 2, low: 1 };
      return priorityOrder[b.priority] - priorityOrder[a.priority];
    });
  }

  async identifyDonationCandidates(userId: string): Promise<DonationCandidate[]> {
    const items = await this.getUserItems(userId);
    const candidates: DonationCandidate[] = [];

    for (const item of items) {
      const reasons = this.assessDonationReasons(item);
      if (reasons.length > 0) {
        const confidence = this.calculateDonationConfidence(item, reasons);
        const value = this.calculateDonationValue(item);

        candidates.push({
          itemId: item.id,
          reasons,
          confidence,
          value,
          recipient: this.suggestRecipient(item),
          preparation: this.assessPreparationNeeds(item)
        });
      }
    }

    return candidates.sort((a, b) => b.confidence - a.confidence);
  }

  async trackWearFrequency(userId: string): Promise<{
    mostWorn: Array<{ itemId: string; count: number; efficiency: number }>;
    leastWorn: Array<{ itemId: string; count: number; daysSinceWorn: number }>;
    seasonal: Record<string, Array<{ itemId: string; count: number }>>;
    recommendations: string[];
  }> {
    const items = await this.getUserItems(userId);

    const wearData = items.map(item => ({
      itemId: item.id,
      count: item.metadata.wearCount || 0,
      lastWorn: item.metadata.lastWorn,
      costPerWear: this.calculateCostPerWear(item),
      efficiency: this.calculateWearEfficiency(item)
    }));

    const mostWorn = wearData
      .filter(data => data.count > 0)
      .sort((a, b) => b.count - a.count)
      .slice(0, 10)
      .map(data => ({
        itemId: data.itemId,
        count: data.count,
        efficiency: data.efficiency
      }));

    const leastWorn = wearData
      .filter(data => data.count === 0 || (data.lastWorn && this.daysSince(data.lastWorn) > 90))
      .sort((a, b) => a.count - b.count)
      .slice(0, 10)
      .map(data => ({
        itemId: data.itemId,
        count: data.count,
        daysSinceWorn: data.lastWorn ? this.daysSince(data.lastWorn) : Infinity
      }));

    const seasonal = this.groupWearBySeason(items, wearData);
    const recommendations = this.generateWearRecommendations(mostWorn, leastWorn);

    return { mostWorn, leastWorn, seasonal, recommendations };
  }

  private async generateOutfitSuggestions(userId: string, occasion: string, weather: any, location: any) {
    const items = await this.getUserItems(userId);
    const suitableItems = items.filter(item => this.isItemSuitable(item, occasion, weather, location));

    return [{
      outfitId: `outfit_${Date.now()}`,
      items: suitableItems.slice(0, 5).map(item => item.id),
      confidence: 0.85,
      reasoning: ['Weather appropriate', 'Occasion suitable', 'Color coordinated'],
      alternatives: this.generateAlternatives(suitableItems)
    }];
  }

  private async createPreparationSteps(itemIds: string[]): Promise<PreparationStep[]> {
    const steps: PreparationStep[] = [];

    for (const itemId of itemIds) {
      const item = await this.getItemById(itemId);
      const itemSteps = this.getItemPreparationSteps(item);
      steps.push(...itemSteps);
    }

    return steps.sort((a, b) => {
      const priorityOrder = { critical: 4, high: 3, medium: 2, low: 1 };
      return priorityOrder[b.priority] - priorityOrder[a.priority];
    });
  }

  private generateReminders(date: Date, steps: PreparationStep[]): Reminder[] {
    const reminders: Reminder[] = [];
    const totalTime = steps.reduce((sum, step) => sum + step.estimatedTime, 0);

    reminders.push({
      id: `rem_${Date.now()}`,
      type: 'preparation',
      message: `Start outfit preparation (${totalTime} minutes needed)`,
      scheduledFor: new Date(date.getTime() - totalTime * 60000),
      recurring: false,
      sent: false
    });

    return reminders;
  }

  private async planTripOutfits(userId: string, tripDetails: any, duration: number) {
    const outfits = [];

    for (let day = 1; day <= duration; day++) {
      const occasion = this.determineDayOccasion(day, tripDetails.activities);
      outfits.push({
        day,
        occasion,
        items: [],
        packed: false,
        notes: `Day ${day} - ${occasion}`
      });
    }

    return outfits;
  }

  private calculateEssentials(duration: number, activities: string[]) {
    return {
      underwear: duration + 2,
      socks: duration + 2,
      sleepwear: Math.min(duration, 3),
      accessories: this.getActivityAccessories(activities)
    };
  }

  private recommendLuggage(outfits: any[], essentials: any, duration: number): LuggageInfo[] {
    const totalItems = outfits.length * 5 + essentials.underwear + essentials.socks;

    return [{
      id: 'luggage_1',
      type: duration <= 3 ? 'carry_on' : 'checked',
      capacity: { weight: 23, volume: 55 },
      items: [],
      restrictions: duration <= 3 ? ['liquids_100ml', 'no_sharp_objects'] : []
    }];
  }

  private async generatePackingChecklist(outfits: any[], essentials: any): Promise<PackingItem[]> {
    const checklist: PackingItem[] = [];

    outfits.forEach(outfit => {
      outfit.items.forEach((itemId: string) => {
        checklist.push({
          itemId,
          category: 'outfit',
          priority: 'important',
          packed: false
        });
      });
    });

    return checklist;
  }

  private recommendPackingMethod(duration: number, outfitCount: number): 'rolling' | 'folding' | 'bundle' | 'mixed' {
    if (duration <= 3) return 'rolling';
    if (outfitCount > 10) return 'bundle';
    return 'mixed';
  }

  private estimateWeight(outfits: any[], essentials: any): number {
    return outfits.length * 2.5 + essentials.underwear * 0.1 + essentials.socks * 0.05;
  }

  private estimateVolume(outfits: any[], essentials: any): number {
    return outfits.length * 0.8 + essentials.underwear * 0.02 + essentials.socks * 0.01;
  }

  private async getUserItems(userId: string): Promise<IClothingItem[]> {
    return [];
  }

  private async getUserOutfits(userId: string): Promise<IOutfit[]> {
    return [];
  }

  private async getItemById(itemId: string): Promise<IClothingItem> {
    return {} as IClothingItem;
  }

  private isPotentiallyMissing(item: IClothingItem): boolean {
    const daysSinceLastSeen = this.daysSince(item.metadata.lastWorn || item.metadata.addedAt);
    return daysSinceLastSeen > 30 && (item.metadata.wearCount || 0) > 0;
  }

  private calculateMissingPriority(item: IClothingItem): 'low' | 'medium' | 'high' | 'urgent' {
    const value = item.purchase.price || 0;
    const wearFrequency = item.metadata.wearCount || 0;

    if (value > 200 && wearFrequency > 10) return 'urgent';
    if (value > 100 || wearFrequency > 5) return 'high';
    if (wearFrequency > 0) return 'medium';
    return 'low';
  }

  private suggestSearchLocations(item: IClothingItem): string[] {
    const locations = ['bedroom', 'laundry_room', 'closet'];

    if (item.category.formality === 'athletic') {
      locations.push('gym_bag', 'car', 'sports_equipment_area');
    }

    if (item.category.formality === 'formal') {
      locations.push('garment_bag', 'dry_cleaner', 'special_storage');
    }

    return locations;
  }

  private suggestPeopleToCheck(item: IClothingItem): string[] {
    return ['family_members', 'roommates', 'partner', 'close_friends'];
  }

  private async findAlternativeItems(userId: string, item: IClothingItem): Promise<string[]> {
    const items = await this.getUserItems(userId);
    return items
      .filter(i =>
        i.id !== item.id &&
        i.category.main === item.category.main &&
        i.colors.colorFamily === item.colors.colorFamily
      )
      .slice(0, 3)
      .map(i => i.id);
  }

  private analyzeCategoryDistribution(items: IClothingItem[]) {
    const distribution: Record<string, number> = {};
    items.forEach(item => {
      const category = `${item.category.main}_${item.category.sub}`;
      distribution[category] = (distribution[category] || 0) + 1;
    });
    return distribution;
  }

  private analyzeOccasionCoverage(items: IClothingItem[], outfits: IOutfit[]) {
    const coverage: Record<string, number> = {};
    outfits.forEach(outfit => {
      outfit.occasions.forEach(occasion => {
        coverage[occasion] = (coverage[occasion] || 0) + 1;
      });
    });
    return coverage;
  }

  private analyzeSeasonalCoverage(items: IClothingItem[]) {
    const coverage: Record<string, number> = {};
    items.forEach(item => {
      item.category.season.forEach(season => {
        coverage[season] = (coverage[season] || 0) + 1;
      });
    });
    return coverage;
  }

  private identifyMissingItems(categoryAnalysis: any, occasionCoverage: any, seasonalCoverage: any) {
    const missing = [];
    const essentials = ['basic_tee', 'jeans', 'dress_shirt', 'blazer'];

    essentials.forEach(essential => {
      if (!categoryAnalysis[essential] || categoryAnalysis[essential] < 2) {
        missing.push({
          type: essential,
          priority: 'essential' as const,
          reason: 'Wardrobe essential missing',
          estimatedCost: this.getEstimatedCost(essential),
          suggestions: this.getItemSuggestions(essential)
        });
      }
    });

    return missing;
  }

  private identifyOversuppliedItems(categoryAnalysis: any) {
    const oversupplied = [];

    Object.entries(categoryAnalysis).forEach(([category, count]) => {
      if (typeof count === 'number' && count > 10) {
        oversupplied.push({
          type: category,
          count,
          suggestion: 'donate' as const,
          items: []
        });
      }
    });

    return oversupplied;
  }

  private generateGapRecommendations(missing: any[], oversupplied: any[]) {
    const recommendations = [];

    if (missing.length > 0) {
      recommendations.push({
        action: 'buy' as const,
        items: missing.map(m => m.type),
        priority: 1,
        reasoning: 'Fill essential wardrobe gaps'
      });
    }

    if (oversupplied.length > 0) {
      recommendations.push({
        action: 'donate' as const,
        items: oversupplied.map(o => o.type),
        priority: 2,
        reasoning: 'Reduce closet clutter and help others'
      });
    }

    return recommendations;
  }

  private async analyzeUserStyle(userId: string) {
    return {
      colors: ['black', 'white', 'navy'],
      styles: ['minimalist', 'classic'],
      brands: ['quality_focused'],
      budget: 'medium'
    };
  }

  private assessSeasonalNeeds() {
    const currentSeason = this.getCurrentSeason();
    return {
      current: currentSeason,
      upcoming: this.getUpcomingSeason(currentSeason),
      priorities: this.getSeasonalPriorities(currentSeason)
    };
  }

  private getCurrentSeason(): string {
    const month = new Date().getMonth();
    if (month >= 2 && month <= 4) return 'spring';
    if (month >= 5 && month <= 7) return 'summer';
    if (month >= 8 && month <= 10) return 'autumn';
    return 'winter';
  }

  private getUpcomingSeason(current: string): string {
    const seasons = { spring: 'summer', summer: 'autumn', autumn: 'winter', winter: 'spring' };
    return seasons[current as keyof typeof seasons];
  }

  private getSeasonalPriorities(season: string): string[] {
    const priorities = {
      spring: ['light_jacket', 'transitional_pieces'],
      summer: ['shorts', 'light_tops', 'sandals'],
      autumn: ['sweaters', 'boots', 'layering_pieces'],
      winter: ['coat', 'warm_accessories', 'winter_boots']
    };
    return priorities[season as keyof typeof priorities] || [];
  }

  private generateAdditionalReasons(gap: any, userStyle: any): string[] {
    return ['Matches your style preferences', 'Versatile for multiple occasions'];
  }

  private generateSpecifications(gap: any, userStyle: any) {
    return {
      colors: userStyle.colors || ['black', 'white', 'navy'],
      materials: ['cotton', 'wool', 'linen'],
      features: ['durable', 'comfortable', 'easy_care'],
      brands: userStyle.brands || []
    };
  }

  private getRelevantOccasions(type: string): string[] {
    const occasionMap: Record<string, string[]> = {
      basic_tee: ['casual', 'weekend'],
      dress_shirt: ['business', 'formal'],
      jeans: ['casual', 'weekend'],
      blazer: ['business', 'smart_casual']
    };
    return occasionMap[type] || ['casual'];
  }

  private getRelevantSeasons(type: string): string[] {
    const seasonMap: Record<string, string[]> = {
      shorts: ['spring', 'summer'],
      sweater: ['autumn', 'winter'],
      coat: ['winter'],
      sandals: ['spring', 'summer']
    };
    return seasonMap[type] || ['all'];
  }

  private calculateVersatility(type: string): number {
    const versatilityMap: Record<string, number> = {
      basic_tee: 0.9,
      jeans: 0.8,
      blazer: 0.7,
      dress_shirt: 0.6
    };
    return versatilityMap[type] || 0.5;
  }

  private calculateUrgencyDate(priority: string): Date {
    const days = priority === 'essential' ? 7 : priority === 'important' ? 30 : 90;
    return new Date(Date.now() + days * 86400000);
  }

  private prioritizeBudget(suggestions: PurchaseSuggestion[], budget: number): PurchaseSuggestion[] {
    let remainingBudget = budget;
    const selected: PurchaseSuggestion[] = [];

    const sorted = suggestions.sort((a, b) => {
      const priorityOrder = { urgent: 4, high: 3, medium: 2, low: 1 };
      return priorityOrder[b.priority] - priorityOrder[a.priority];
    });

    for (const suggestion of sorted) {
      if (suggestion.budget.min <= remainingBudget) {
        selected.push(suggestion);
        remainingBudget -= suggestion.budget.recommended;
      }
    }

    return selected;
  }

  private assessDonationReasons(item: IClothingItem): string[] {
    const reasons = [];
    const daysSinceWorn = this.daysSince(item.metadata.lastWorn || item.metadata.addedAt);

    if (daysSinceWorn > 365) reasons.push('Not worn in over a year');
    if ((item.metadata.wearCount || 0) === 0) reasons.push('Never worn');
    if (item.condition.status === 'poor') reasons.push('Poor condition');
    if (item.size.fit === 'tight' || item.size.fit === 'loose') reasons.push('Poor fit');

    return reasons;
  }

  private calculateDonationConfidence(item: IClothingItem, reasons: string[]): number {
    let confidence = 0.1;

    confidence += reasons.length * 0.2;
    if (reasons.includes('Never worn')) confidence += 0.3;
    if (reasons.includes('Not worn in over a year')) confidence += 0.2;
    if (reasons.includes('Poor condition')) confidence += 0.1;

    return Math.min(confidence, 1.0);
  }

  private calculateDonationValue(item: IClothingItem) {
    const originalValue = item.purchase.price || 0;
    const currentValue = originalValue * 0.3;
    const donationValue = currentValue * 0.8;
    const taxDeduction = donationValue * 0.25;

    return {
      current: currentValue,
      donation: donationValue,
      taxDeduction
    };
  }

  private suggestRecipient(item: IClothingItem) {
    if (item.category.formality === 'business') {
      return {
        type: 'charity' as const,
        suggestions: ['Dress for Success', 'Career closet organizations']
      };
    }

    return {
      type: 'charity' as const,
      suggestions: ['Goodwill', 'Local homeless shelter', 'Clothing banks']
    };
  }

  private assessPreparationNeeds(item: IClothingItem) {
    return {
      cleaning: item.condition.status !== 'excellent',
      repair: item.condition.defects && item.condition.defects.length > 0,
      documentation: (item.purchase.price || 0) > 100
    };
  }

  private calculateCostPerWear(item: IClothingItem): number {
    const cost = item.purchase.price || 0;
    const wears = Math.max(item.metadata.wearCount || 0, 1);
    return cost / wears;
  }

  private calculateWearEfficiency(item: IClothingItem): number {
    const costPerWear = this.calculateCostPerWear(item);
    const monthsOwned = this.monthsSince(item.metadata.addedAt);
    const wearsPerMonth = (item.metadata.wearCount || 0) / Math.max(monthsOwned, 1);

    return wearsPerMonth / Math.max(costPerWear / 50, 1);
  }

  private groupWearBySeason(items: IClothingItem[], wearData: any[]): Record<string, Array<{ itemId: string; count: number }>> {
    const seasonal: Record<string, Array<{ itemId: string; count: number }>> = {
      spring: [], summer: [], autumn: [], winter: []
    };

    items.forEach(item => {
      const data = wearData.find(d => d.itemId === item.id);
      if (data) {
        item.category.season.forEach(season => {
          if (seasonal[season]) {
            seasonal[season].push({ itemId: item.id, count: data.count });
          }
        });
      }
    });

    return seasonal;
  }

  private generateWearRecommendations(mostWorn: any[], leastWorn: any[]): string[] {
    const recommendations = [];

    if (mostWorn.length > 0) {
      recommendations.push('Consider buying similar items to your most worn pieces');
    }

    if (leastWorn.length > 5) {
      recommendations.push('Consider donating items you haven\'t worn in over 6 months');
    }

    return recommendations;
  }

  private daysSince(date: Date): number {
    return Math.floor((Date.now() - date.getTime()) / 86400000);
  }

  private monthsSince(date: Date): number {
    return Math.floor(this.daysSince(date) / 30);
  }

  private estimateItemValue(item: IClothingItem): number {
    return item.purchase.price || 0;
  }

  private async saveLendingRecord(record: LendingRecord): Promise<void> {
  }

  private async scheduleReturnReminders(record: LendingRecord): Promise<void> {
  }

  private isItemSuitable(item: IClothingItem, occasion: string, weather: any, location: any): boolean {
    return item.category.occasion.includes(occasion);
  }

  private generateAlternatives(items: IClothingItem[]): Record<string, string[]> {
    return {};
  }

  private getItemPreparationSteps(item: IClothingItem): PreparationStep[] {
    const steps: PreparationStep[] = [];

    if (item.materials.careInstructions.includes('iron')) {
      steps.push({
        id: `step_${Date.now()}`,
        type: 'iron',
        itemId: item.id,
        description: `Iron ${item.name}`,
        estimatedTime: 10,
        priority: 'medium',
        completed: false
      });
    }

    return steps;
  }

  private determineDayOccasion(day: number, activities: string[]): string {
    return activities[Math.min(day - 1, activities.length - 1)] || 'casual';
  }

  private getActivityAccessories(activities: string[]): string[] {
    const accessories: string[] = [];

    if (activities.includes('business')) accessories.push('belt', 'watch');
    if (activities.includes('beach')) accessories.push('sunglasses', 'hat');
    if (activities.includes('hiking')) accessories.push('backpack', 'hiking_boots');

    return accessories;
  }

  private getEstimatedCost(itemType: string): number {
    const costs: Record<string, number> = {
      basic_tee: 25,
      jeans: 80,
      dress_shirt: 60,
      blazer: 150
    };
    return costs[itemType] || 50;
  }

  private getItemSuggestions(itemType: string): string[] {
    return ['Check current sales', 'Consider versatile colors', 'Focus on quality basics'];
  }
}