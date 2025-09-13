import { IClothingItem } from '../models/ClothingItem';
import { ICloset } from '../models/Closet';
import { IOutfit } from '../models/Outfit';

export interface OrganizationStrategy {
  name: string;
  description: string;
  execute: (items: IClothingItem[], closet: ICloset) => OrganizationPlan;
}

export interface OrganizationPlan {
  strategy: string;
  sections: Array<{
    sectionId: string;
    items: string[];
    reasoning: string;
    priority: number;
  }>;
  recommendations: string[];
  efficiency: number;
}

export interface ColorCoordinationResult {
  groups: Array<{
    colorFamily: string;
    items: string[];
    harmony: string;
    position: 'front' | 'middle' | 'back';
  }>;
  transitions: Array<{
    from: string;
    to: string;
    method: string;
  }>;
}

export interface SeasonalRotationPlan {
  currentSeason: string;
  activeItems: string[];
  storageItems: string[];
  transitionItems: string[];
  rotationDate: Date;
  climate: string;
}

export class ClosetOrganizationAI {
  private colorHarmonies = {
    monochrome: (colors: string[]) => colors.filter(c => this.isSameColorFamily(c, colors[0])),
    analogous: (colors: string[]) => this.getAnalogousColors(colors),
    complementary: (colors: string[]) => this.getComplementaryColors(colors),
    triadic: (colors: string[]) => this.getTriadicColors(colors)
  };

  private seasonalMapping = {
    spring: ['light', 'pastel', 'fresh'],
    summer: ['bright', 'vibrant', 'light'],
    autumn: ['warm', 'earth', 'rich'],
    winter: ['dark', 'deep', 'cool']
  };

  async analyzeCloset(closet: ICloset, items: IClothingItem[]): Promise<{
    utilization: number;
    efficiency: number;
    gaps: string[];
    duplicates: Array<{ items: string[]; reason: string }>;
    recommendations: string[];
  }> {
    const categories = this.categorizeItems(items);
    const utilization = this.calculateUtilization(closet, items);
    const efficiency = this.calculateOrganizationEfficiency(closet, items);
    const gaps = this.identifyGaps(categories);
    const duplicates = this.findDuplicates(items);
    const recommendations = this.generateRecommendations(closet, items, gaps);

    return {
      utilization,
      efficiency,
      gaps,
      duplicates,
      recommendations
    };
  }

  async organizeByFrequency(items: IClothingItem[], closet: ICloset): Promise<OrganizationPlan> {
    const frequencyGroups = this.groupByWearFrequency(items);
    const sections = closet.spaces.flatMap(space => space.sections);

    const plan: OrganizationPlan = {
      strategy: 'frequency_based',
      sections: [],
      recommendations: [],
      efficiency: 0
    };

    const accessibleSections = sections
      .filter(s => s.position.y <= 180)
      .sort((a, b) => a.position.y - b.position.y);

    accessibleSections.forEach((section, index) => {
      const group = frequencyGroups[index] || { items: [], frequency: 'low' };
      plan.sections.push({
        sectionId: section.id,
        items: group.items.map(item => item.id),
        reasoning: `${group.frequency} frequency items at ${this.getAccessibilityLevel(section.position.y)}`,
        priority: this.getPriorityFromFrequency(group.frequency)
      });
    });

    plan.recommendations = this.generateFrequencyRecommendations(frequencyGroups, sections);
    plan.efficiency = this.calculatePlanEfficiency(plan, items);

    return plan;
  }

  async organizeByColor(items: IClothingItem[], closet: ICloset): Promise<ColorCoordinationResult> {
    const colorGroups = this.groupByColorFamily(items);
    const colorFlow = this.calculateOptimalColorFlow(colorGroups);

    return {
      groups: colorGroups.map((group, index) => ({
        colorFamily: group.family,
        items: group.items.map(item => item.id),
        harmony: this.determineHarmony(group.colors),
        position: this.determineColorPosition(index, colorGroups.length)
      })),
      transitions: this.createColorTransitions(colorFlow)
    };
  }

  async organizeByOccasion(items: IClothingItem[], outfits: IOutfit[]): Promise<OrganizationPlan> {
    const occasionGroups = this.groupByOccasion(items, outfits);

    return {
      strategy: 'occasion_based',
      sections: occasionGroups.map((group, index) => ({
        sectionId: `occasion_${index}`,
        items: group.items.map(item => item.id),
        reasoning: `Items for ${group.occasion} occasions`,
        priority: this.getOccasionPriority(group.occasion)
      })),
      recommendations: this.generateOccasionRecommendations(occasionGroups),
      efficiency: this.calculateOccasionEfficiency(occasionGroups)
    };
  }

  async createSeasonalRotation(items: IClothingItem[], location: string): Promise<SeasonalRotationPlan> {
    const currentSeason = this.getCurrentSeason(location);
    const seasonalGroups = this.groupBySeason(items, currentSeason);

    return {
      currentSeason,
      activeItems: seasonalGroups.active.map(item => item.id),
      storageItems: seasonalGroups.storage.map(item => item.id),
      transitionItems: seasonalGroups.transition.map(item => item.id),
      rotationDate: this.calculateNextRotationDate(currentSeason),
      climate: this.getClimateData(location)
    };
  }

  async optimizeByKonMari(items: IClothingItem[]): Promise<{
    keep: string[];
    donate: string[];
    repair: string[];
    categories: Array<{
      name: string;
      items: string[];
      order: number;
    }>;
  }> {
    const joyScore = this.calculateJoyScore(items);
    const condition = this.assessCondition(items);
    const categories = this.konMariCategories();

    return {
      keep: items.filter(item => joyScore[item.id] > 0.7 && condition[item.id] !== 'poor').map(item => item.id),
      donate: items.filter(item => joyScore[item.id] < 0.4 && condition[item.id] !== 'poor').map(item => item.id),
      repair: items.filter(item => condition[item.id] === 'poor' && joyScore[item.id] > 0.6).map(item => item.id),
      categories: categories.map((cat, index) => ({
        name: cat.name,
        items: items.filter(item => cat.matches(item)).map(item => item.id),
        order: index + 1
      }))
    };
  }

  async createCapsuleWardrobe(items: IClothingItem[], preferences: any): Promise<{
    capsule: string[];
    essentials: string[];
    seasonal: string[];
    versatilityScores: Record<string, number>;
    combinations: number;
  }> {
    const versatilityScores = this.calculateVersatilityScores(items);
    const essentials = this.identifyEssentials(items, preferences);
    const seasonal = this.selectSeasonalPieces(items, preferences.seasons || []);

    const capsule = [
      ...essentials.slice(0, preferences.maxPieces * 0.7),
      ...seasonal.slice(0, preferences.maxPieces * 0.3)
    ];

    return {
      capsule,
      essentials,
      seasonal,
      versatilityScores,
      combinations: this.calculatePossibleCombinations(capsule)
    };
  }

  private groupByWearFrequency(items: IClothingItem[]): Array<{ items: IClothingItem[]; frequency: string }> {
    const sorted = items.sort((a, b) => (b.metadata.wearCount || 0) - (a.metadata.wearCount || 0));
    const third = Math.ceil(sorted.length / 3);

    return [
      { items: sorted.slice(0, third), frequency: 'high' },
      { items: sorted.slice(third, third * 2), frequency: 'medium' },
      { items: sorted.slice(third * 2), frequency: 'low' }
    ];
  }

  private groupByColorFamily(items: IClothingItem[]): Array<{
    family: string;
    items: IClothingItem[];
    colors: string[];
  }> {
    const families = new Map<string, IClothingItem[]>();

    items.forEach(item => {
      const family = item.colors.colorFamily;
      if (!families.has(family)) {
        families.set(family, []);
      }
      families.get(family)!.push(item);
    });

    return Array.from(families.entries()).map(([family, items]) => ({
      family,
      items,
      colors: items.map(item => item.colors.primary)
    }));
  }

  private groupByOccasion(items: IClothingItem[], outfits: IOutfit[]): Array<{
    occasion: string;
    items: IClothingItem[];
    outfits: string[];
  }> {
    const occasions = new Map<string, { items: IClothingItem[]; outfits: string[] }>();

    outfits.forEach(outfit => {
      outfit.occasions.forEach(occasion => {
        if (!occasions.has(occasion)) {
          occasions.set(occasion, { items: [], outfits: [] });
        }
        occasions.get(occasion)!.outfits.push(outfit.id);

        outfit.items.forEach(outfitItem => {
          const item = items.find(i => i.id === outfitItem.itemId);
          if (item && !occasions.get(occasion)!.items.find(i => i.id === item.id)) {
            occasions.get(occasion)!.items.push(item);
          }
        });
      });
    });

    return Array.from(occasions.entries()).map(([occasion, data]) => ({
      occasion,
      items: data.items,
      outfits: data.outfits
    }));
  }

  private groupBySeason(items: IClothingItem[], currentSeason: string): {
    active: IClothingItem[];
    storage: IClothingItem[];
    transition: IClothingItem[];
  } {
    const active: IClothingItem[] = [];
    const storage: IClothingItem[] = [];
    const transition: IClothingItem[] = [];

    items.forEach(item => {
      const itemSeasons = item.category.season || [];
      if (itemSeasons.includes(currentSeason)) {
        active.push(item);
      } else if (itemSeasons.length === 0 || itemSeasons.includes('all')) {
        transition.push(item);
      } else {
        storage.push(item);
      }
    });

    return { active, storage, transition };
  }

  private calculateUtilization(closet: ICloset, items: IClothingItem[]): number {
    const totalCapacity = closet.spaces.reduce((sum, space) =>
      sum + space.sections.reduce((sectionSum, section) => sectionSum + section.capacity, 0), 0
    );
    return items.length / totalCapacity;
  }

  private calculateOrganizationEfficiency(closet: ICloset, items: IClothingItem[]): number {
    let score = 0.8;

    if (closet.organization.strategy === 'frequency_based') {
      score += this.evaluateFrequencyOrganization(closet, items) * 0.2;
    }

    return Math.min(score, 1);
  }

  private calculateVersatilityScores(items: IClothingItem[]): Record<string, number> {
    const scores: Record<string, number> = {};

    items.forEach(item => {
      let score = 0.5;

      if (item.colors.primary === 'black' || item.colors.primary === 'white' || item.colors.primary === 'navy') {
        score += 0.2;
      }

      if (item.category.formality === 'business' || item.category.formality === 'casual') {
        score += 0.15;
      }

      if (item.category.season.length > 2) {
        score += 0.15;
      }

      scores[item.id] = Math.min(score, 1);
    });

    return scores;
  }

  private identifyGaps(categories: Record<string, IClothingItem[]>): string[] {
    const gaps: string[] = [];
    const essentials = ['basic_tee', 'jeans', 'blazer', 'dress_shirt', 'little_black_dress'];

    essentials.forEach(essential => {
      if (!categories[essential] || categories[essential].length === 0) {
        gaps.push(essential);
      }
    });

    return gaps;
  }

  private findDuplicates(items: IClothingItem[]): Array<{ items: string[]; reason: string }> {
    const duplicates: Array<{ items: string[]; reason: string }> = [];
    const groups = new Map<string, IClothingItem[]>();

    items.forEach(item => {
      const key = `${item.category.main}_${item.category.sub}_${item.colors.primary}`;
      if (!groups.has(key)) {
        groups.set(key, []);
      }
      groups.get(key)!.push(item);
    });

    groups.forEach((items, key) => {
      if (items.length > 1) {
        duplicates.push({
          items: items.map(item => item.id),
          reason: `Similar ${key.replace(/_/g, ' ')} items`
        });
      }
    });

    return duplicates;
  }

  private categorizeItems(items: IClothingItem[]): Record<string, IClothingItem[]> {
    const categories: Record<string, IClothingItem[]> = {};

    items.forEach(item => {
      const category = `${item.category.main}_${item.category.sub}`;
      if (!categories[category]) {
        categories[category] = [];
      }
      categories[category].push(item);
    });

    return categories;
  }

  private generateRecommendations(closet: ICloset, items: IClothingItem[], gaps: string[]): string[] {
    const recommendations: string[] = [];

    if (gaps.length > 0) {
      recommendations.push(`Consider adding these wardrobe essentials: ${gaps.join(', ')}`);
    }

    if (closet.analytics.utilizationRate < 0.7) {
      recommendations.push('Your closet has good space - consider expanding your wardrobe');
    } else if (closet.analytics.utilizationRate > 0.9) {
      recommendations.push('Consider decluttering or expanding storage space');
    }

    return recommendations;
  }

  private generateFrequencyRecommendations(groups: any[], sections: any[]): string[] {
    return [
      'Place frequently worn items at eye level (60-80cm height)',
      'Store seasonal items in less accessible areas',
      'Keep everyday essentials within arm\'s reach'
    ];
  }

  private generateOccasionRecommendations(groups: any[]): string[] {
    return [
      'Group complete outfits together for efficiency',
      'Place work clothes in easily accessible sections',
      'Store formal wear separately to prevent wrinkles'
    ];
  }

  private calculatePlanEfficiency(plan: OrganizationPlan, items: IClothingItem[]): number {
    return 0.85;
  }

  private calculateOccasionEfficiency(groups: any[]): number {
    return 0.82;
  }

  private getCurrentSeason(location: string): string {
    const month = new Date().getMonth();
    const seasons = ['winter', 'spring', 'summer', 'autumn'];
    return seasons[Math.floor(month / 3)];
  }

  private calculateNextRotationDate(currentSeason: string): Date {
    const nextQuarter = new Date();
    nextQuarter.setMonth(nextQuarter.getMonth() + 3);
    return nextQuarter;
  }

  private getClimateData(location: string): string {
    return 'temperate';
  }

  private calculateJoyScore(items: IClothingItem[]): Record<string, number> {
    const scores: Record<string, number> = {};
    items.forEach(item => {
      scores[item.id] = (item.metadata.wearCount || 0) > 0 ? 0.8 : 0.5;
    });
    return scores;
  }

  private assessCondition(items: IClothingItem[]): Record<string, string> {
    const conditions: Record<string, string> = {};
    items.forEach(item => {
      conditions[item.id] = item.condition.status;
    });
    return conditions;
  }

  private konMariCategories() {
    return [
      { name: 'Tops', matches: (item: IClothingItem) => item.category.main === 'tops' },
      { name: 'Bottoms', matches: (item: IClothingItem) => item.category.main === 'bottoms' },
      { name: 'Dresses', matches: (item: IClothingItem) => item.category.main === 'dresses' },
      { name: 'Outerwear', matches: (item: IClothingItem) => item.category.main === 'outerwear' },
      { name: 'Accessories', matches: (item: IClothingItem) => item.category.main === 'accessories' }
    ];
  }

  private identifyEssentials(items: IClothingItem[], preferences: any): string[] {
    return items
      .filter(item => this.isEssential(item))
      .sort((a, b) => (b.metadata.wearCount || 0) - (a.metadata.wearCount || 0))
      .map(item => item.id);
  }

  private selectSeasonalPieces(items: IClothingItem[], seasons: string[]): string[] {
    return items
      .filter(item => seasons.some(season => item.category.season.includes(season)))
      .map(item => item.id);
  }

  private calculatePossibleCombinations(capsule: string[]): number {
    return Math.pow(2, capsule.length) - 1;
  }

  private isEssential(item: IClothingItem): boolean {
    const essentialTypes = ['basic_tee', 'jeans', 'blazer', 'dress_shirt', 'little_black_dress'];
    return essentialTypes.includes(`${item.category.main}_${item.category.sub}`);
  }

  private isSameColorFamily(color1: string, color2: string): boolean {
    return color1 === color2;
  }

  private getAnalogousColors(colors: string[]): string[] {
    return colors;
  }

  private getComplementaryColors(colors: string[]): string[] {
    return colors;
  }

  private getTriadicColors(colors: string[]): string[] {
    return colors;
  }

  private getAccessibilityLevel(height: number): string {
    if (height <= 60) return 'low level';
    if (height <= 180) return 'eye level';
    return 'high level';
  }

  private getPriorityFromFrequency(frequency: string): number {
    const priorities = { high: 1, medium: 2, low: 3 };
    return priorities[frequency as keyof typeof priorities] || 2;
  }

  private getOccasionPriority(occasion: string): number {
    const priorities = { work: 1, casual: 2, formal: 3, athletic: 4 };
    return priorities[occasion as keyof typeof priorities] || 2;
  }

  private determineHarmony(colors: string[]): string {
    return 'analogous';
  }

  private determineColorPosition(index: number, total: number): 'front' | 'middle' | 'back' {
    if (index < total * 0.33) return 'front';
    if (index < total * 0.66) return 'middle';
    return 'back';
  }

  private calculateOptimalColorFlow(groups: any[]): string[] {
    return groups.map(g => g.family);
  }

  private createColorTransitions(flow: string[]): Array<{ from: string; to: string; method: string }> {
    const transitions = [];
    for (let i = 0; i < flow.length - 1; i++) {
      transitions.push({
        from: flow[i],
        to: flow[i + 1],
        method: 'gradient'
      });
    }
    return transitions;
  }

  private evaluateFrequencyOrganization(closet: ICloset, items: IClothingItem[]): number {
    return 0.8;
  }
}