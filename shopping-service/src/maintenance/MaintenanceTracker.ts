import { IMaintenanceRecord, IMaintenanceSchedule } from '../models/MaintenanceRecord';
import { IClothingItem } from '../models/ClothingItem';
import { NotificationService } from '../realtime/NotificationService';

export interface MaintenanceAlert {
  id: string;
  itemId: string;
  type: 'due' | 'overdue' | 'reminder' | 'seasonal';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  message: string;
  dueDate: Date;
  actions: string[];
}

export interface CleaningSchedule {
  itemId: string;
  frequency: number;
  lastCleaned?: Date;
  nextDue: Date;
  cleaningType: string;
  estimatedCost: number;
  provider?: string;
}

export interface RepairTracker {
  itemId: string;
  issues: Array<{
    type: 'tear' | 'stain' | 'wear' | 'alteration' | 'missing_button' | 'zipper';
    severity: 'minor' | 'moderate' | 'major' | 'critical';
    location: string;
    dateReported: Date;
    estimatedCost: number;
    urgency: number;
  }>;
  history: Array<{
    date: Date;
    repair: string;
    cost: number;
    provider: string;
    warranty?: Date;
  }>;
}

export interface SeasonalRotation {
  season: string;
  startDate: Date;
  endDate: Date;
  itemsToStore: string[];
  itemsToRetrieve: string[];
  storageInstructions: Array<{
    itemId: string;
    instructions: string[];
    materials: string[];
    location: string;
  }>;
}

export interface MothPrevention {
  riskLevel: 'low' | 'medium' | 'high' | 'critical';
  vulnerableItems: string[];
  preventiveMeasures: string[];
  inspectionSchedule: Date[];
  treatments: Array<{
    type: 'cedar' | 'lavender' | 'pheromone_trap' | 'temperature' | 'chemical';
    itemIds: string[];
    applicationDate: Date;
    effectiveDuration: number;
    cost: number;
  }>;
}

export interface ClimateControl {
  temperature: {
    current?: number;
    target: number;
    range: { min: number; max: number };
    alerts: boolean;
  };
  humidity: {
    current?: number;
    target: number;
    range: { min: number; max: number };
    dehumidifier: boolean;
  };
  ventilation: {
    airflow: number;
    filtration: boolean;
    lastServiced: Date;
  };
  monitoring: {
    sensors: string[];
    frequency: number;
    dataRetention: number;
  };
}

export class MaintenanceTracker {
  private notificationService: NotificationService;
  private maintenanceCache = new Map<string, IMaintenanceRecord[]>();
  private scheduleCache = new Map<string, IMaintenanceSchedule>();

  constructor(notificationService: NotificationService) {
    this.notificationService = notificationService;
  }

  async scheduleMaintenanceTask(
    userId: string,
    itemId: string,
    type: string,
    dueDate: Date,
    options: {
      priority?: string;
      recurring?: boolean;
      interval?: number;
      provider?: any;
      estimatedCost?: number;
    }
  ): Promise<IMaintenanceRecord> {
    const record: IMaintenanceRecord = {
      id: `maint_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      userId,
      itemId,
      type: type as any,
      status: 'scheduled',
      priority: (options.priority as any) || 'medium',
      details: {
        description: `${type} maintenance for item ${itemId}`,
        estimatedCost: options.estimatedCost
      },
      scheduling: {
        scheduledDate: new Date(),
        dueDate,
        remindersSent: 0,
        recurringInterval: options.recurring ? options.interval : undefined
      },
      provider: options.provider || { type: 'self' },
      notes: [],
      photos: {},
      history: [{
        date: new Date(),
        action: 'scheduled',
        status: 'scheduled',
        notes: 'Task scheduled automatically'
      }],
      metadata: {
        createdAt: new Date(),
        lastUpdated: new Date(),
        source: 'automatic',
        isRecurring: options.recurring || false
      }
    } as IMaintenanceRecord;

    await this.cacheMaintenanceRecord(userId, record);
    await this.scheduleReminders(record);

    return record;
  }

  async createCleaningSchedule(userId: string, items: IClothingItem[]): Promise<CleaningSchedule[]> {
    const schedules: CleaningSchedule[] = [];

    for (const item of items) {
      const cleaningFreq = this.calculateCleaningFrequency(item);
      const cleaningType = this.determineCleaningType(item);
      const cost = this.estimateCleaningCost(item, cleaningType);

      const schedule: CleaningSchedule = {
        itemId: item.id,
        frequency: cleaningFreq,
        nextDue: this.calculateNextCleaningDate(item, cleaningFreq),
        cleaningType,
        estimatedCost: cost,
        provider: cleaningType === 'dry_clean' ? 'professional_dry_cleaner' : undefined
      };

      schedules.push(schedule);

      await this.scheduleMaintenanceTask(userId, item.id, 'cleaning', schedule.nextDue, {
        priority: 'medium',
        recurring: true,
        interval: cleaningFreq,
        estimatedCost: cost
      });
    }

    return schedules;
  }

  async trackRepairs(userId: string, itemId: string): Promise<RepairTracker> {
    const existingTracker = await this.getRepairTracker(userId, itemId);
    if (existingTracker) {
      return existingTracker;
    }

    const tracker: RepairTracker = {
      itemId,
      issues: [],
      history: []
    };

    await this.saveRepairTracker(userId, tracker);
    return tracker;
  }

  async reportIssue(
    userId: string,
    itemId: string,
    issue: {
      type: string;
      severity: string;
      location: string;
      description: string;
      photos?: string[];
    }
  ): Promise<void> {
    const tracker = await this.trackRepairs(userId, itemId);

    const newIssue = {
      type: issue.type as any,
      severity: issue.severity as any,
      location: issue.location,
      dateReported: new Date(),
      estimatedCost: this.estimateRepairCost(issue.type, issue.severity),
      urgency: this.calculateUrgency(issue.severity, issue.type)
    };

    tracker.issues.push(newIssue);
    await this.saveRepairTracker(userId, tracker);

    if (newIssue.urgency > 0.7) {
      await this.scheduleMaintenanceTask(userId, itemId, 'repair', new Date(Date.now() + 86400000), {
        priority: 'high',
        estimatedCost: newIssue.estimatedCost
      });
    }

    await this.notificationService.sendNotification(userId, {
      type: 'maintenance_issue',
      title: 'Repair Needed',
      message: `${issue.type} issue reported for your item`,
      data: { itemId, issueType: issue.type, severity: issue.severity }
    });
  }

  async planSeasonalRotation(
    userId: string,
    items: IClothingItem[],
    season: string,
    location: string
  ): Promise<SeasonalRotation> {
    const seasonalItems = this.categorizeByseason(items, season);
    const climate = this.getClimateData(location);
    const rotationDates = this.calculateRotationDates(season, climate);

    const rotation: SeasonalRotation = {
      season,
      startDate: rotationDates.start,
      endDate: rotationDates.end,
      itemsToStore: seasonalItems.toStore.map(item => item.id),
      itemsToRetrieve: seasonalItems.toRetrieve.map(item => item.id),
      storageInstructions: this.generateStorageInstructions(seasonalItems.toStore)
    };

    await this.scheduleMaintenanceTask(userId, 'seasonal_rotation', 'storage', rotationDates.start, {
      priority: 'medium',
      recurring: true,
      interval: 90
    });

    return rotation;
  }

  async implementMothPrevention(
    userId: string,
    items: IClothingItem[],
    closetId: string
  ): Promise<MothPrevention> {
    const vulnerableItems = this.identifyVulnerableItems(items);
    const riskLevel = this.assessMothRisk(items, vulnerableItems.length);
    const preventiveMeasures = this.recommendPreventiveMeasures(riskLevel);

    const prevention: MothPrevention = {
      riskLevel,
      vulnerableItems: vulnerableItems.map(item => item.id),
      preventiveMeasures,
      inspectionSchedule: this.createInspectionSchedule(riskLevel),
      treatments: await this.planTreatments(vulnerableItems, riskLevel)
    };

    for (const inspectionDate of prevention.inspectionSchedule) {
      await this.scheduleMaintenanceTask(userId, closetId, 'inspection', inspectionDate, {
        priority: riskLevel === 'critical' ? 'high' : 'medium'
      });
    }

    return prevention;
  }

  async setupClimateControl(
    userId: string,
    closetId: string,
    preferences: {
      targetTemp?: number;
      targetHumidity?: number;
      autoControl?: boolean;
    }
  ): Promise<ClimateControl> {
    const control: ClimateControl = {
      temperature: {
        target: preferences.targetTemp || 20,
        range: { min: 18, max: 24 },
        alerts: true
      },
      humidity: {
        target: preferences.targetHumidity || 45,
        range: { min: 40, max: 60 },
        dehumidifier: false
      },
      ventilation: {
        airflow: 0.5,
        filtration: true,
        lastServiced: new Date()
      },
      monitoring: {
        sensors: [`temp_${closetId}`, `humid_${closetId}`],
        frequency: 300,
        dataRetention: 30
      }
    };

    await this.scheduleMaintenanceTask(userId, closetId, 'preventive', new Date(Date.now() + 2592000000), {
      priority: 'low',
      recurring: true,
      interval: 30
    });

    return control;
  }

  async getDueMaintenanceTasks(userId: string): Promise<MaintenanceAlert[]> {
    const records = await this.getUserMaintenanceRecords(userId);
    const alerts: MaintenanceAlert[] = [];
    const now = new Date();

    for (const record of records) {
      if (record.status === 'scheduled' && record.scheduling.dueDate) {
        const daysDue = Math.ceil((record.scheduling.dueDate.getTime() - now.getTime()) / 86400000);

        if (daysDue <= 0) {
          alerts.push({
            id: record.id,
            itemId: record.itemId,
            type: 'overdue',
            priority: 'urgent',
            message: `${record.type} is overdue for ${record.itemId}`,
            dueDate: record.scheduling.dueDate,
            actions: ['Schedule Now', 'Postpone', 'Mark Complete']
          });
        } else if (daysDue <= 7) {
          alerts.push({
            id: record.id,
            itemId: record.itemId,
            type: 'due',
            priority: record.priority as any,
            message: `${record.type} due in ${daysDue} days`,
            dueDate: record.scheduling.dueDate,
            actions: ['Schedule', 'Remind Later', 'View Details']
          });
        }
      }
    }

    return alerts.sort((a, b) => {
      const priorityOrder = { urgent: 4, high: 3, medium: 2, low: 1 };
      return priorityOrder[b.priority] - priorityOrder[a.priority];
    });
  }

  async completeMaintenanceTask(
    userId: string,
    recordId: string,
    completion: {
      actualCost?: number;
      notes?: string;
      photos?: string[];
      rating?: number;
      provider?: string;
    }
  ): Promise<void> {
    const record = await this.getMaintenanceRecord(userId, recordId);
    if (!record) {
      throw new Error('Maintenance record not found');
    }

    record.status = 'completed';
    record.scheduling.completedDate = new Date();
    record.details.actualCost = completion.actualCost;

    if (completion.notes) {
      record.notes.push(completion.notes);
    }

    if (completion.photos) {
      record.photos.after = completion.photos;
    }

    record.history.push({
      date: new Date(),
      action: 'completed',
      status: 'completed',
      notes: completion.notes,
      cost: completion.actualCost
    });

    if (record.metadata.isRecurring && record.scheduling.recurringInterval) {
      const nextDue = new Date(Date.now() + record.scheduling.recurringInterval * 86400000);
      await this.scheduleMaintenanceTask(userId, record.itemId, record.type, nextDue, {
        priority: record.priority,
        recurring: true,
        interval: record.scheduling.recurringInterval,
        provider: record.provider
      });
    }

    await this.updateMaintenanceRecord(userId, record);

    await this.notificationService.sendNotification(userId, {
      type: 'maintenance_completed',
      title: 'Maintenance Complete',
      message: `${record.type} completed for your item`,
      data: { recordId, itemId: record.itemId }
    });
  }

  async generateMaintenanceReport(
    userId: string,
    period: { start: Date; end: Date }
  ): Promise<{
    summary: {
      totalTasks: number;
      completed: number;
      overdue: number;
      totalCost: number;
      avgCost: number;
    };
    breakdown: Record<string, number>;
    trends: Array<{ month: string; tasks: number; cost: number }>;
    recommendations: string[];
  }> {
    const records = await this.getUserMaintenanceRecords(userId);
    const periodRecords = records.filter(r =>
      r.metadata.createdAt >= period.start && r.metadata.createdAt <= period.end
    );

    const summary = {
      totalTasks: periodRecords.length,
      completed: periodRecords.filter(r => r.status === 'completed').length,
      overdue: periodRecords.filter(r => r.status === 'scheduled' &&
        r.scheduling.dueDate && r.scheduling.dueDate < new Date()).length,
      totalCost: periodRecords.reduce((sum, r) => sum + (r.details.actualCost || 0), 0),
      avgCost: 0
    };
    summary.avgCost = summary.totalCost / Math.max(summary.completed, 1);

    const breakdown: Record<string, number> = {};
    periodRecords.forEach(r => {
      breakdown[r.type] = (breakdown[r.type] || 0) + 1;
    });

    const trends = this.calculateMaintenanceTrends(periodRecords);
    const recommendations = this.generateMaintenanceRecommendations(records);

    return { summary, breakdown, trends, recommendations };
  }

  private calculateCleaningFrequency(item: IClothingItem): number {
    const baseFreq = this.getBaseCleaningFrequency(item.category.type);
    const wearFreq = item.metadata.wearCount || 0;
    const material = item.materials.primary.toLowerCase();

    let frequency = baseFreq;

    if (wearFreq > 50) frequency = Math.max(frequency - 7, 7);
    if (material.includes('wool') || material.includes('silk')) frequency += 14;
    if (item.colors.primary === 'white') frequency = Math.max(frequency - 3, 3);

    return frequency;
  }

  private determineCleaningType(item: IClothingItem): string {
    const careInstructions = item.materials.careInstructions || [];

    if (careInstructions.includes('dry clean only')) return 'dry_clean';
    if (careInstructions.includes('hand wash')) return 'hand_wash';
    if (item.materials.primary.includes('silk') || item.materials.primary.includes('wool')) return 'hand_wash';
    if (item.category.formality === 'formal') return 'dry_clean';

    return 'machine_wash';
  }

  private estimateCleaningCost(item: IClothingItem, cleaningType: string): number {
    const costs = {
      machine_wash: 2,
      hand_wash: 5,
      dry_clean: 15,
      spot_clean: 8,
      professional: 25
    };

    const baseCost = costs[cleaningType as keyof typeof costs] || 10;

    if (item.category.formality === 'formal') return baseCost * 1.5;
    if (item.materials.primary.includes('cashmere') || item.materials.primary.includes('silk')) {
      return baseCost * 2;
    }

    return baseCost;
  }

  private calculateNextCleaningDate(item: IClothingItem, frequency: number): Date {
    const lastCleaned = item.metadata.lastWorn || item.metadata.addedAt;
    return new Date(lastCleaned.getTime() + frequency * 86400000);
  }

  private async getRepairTracker(userId: string, itemId: string): Promise<RepairTracker | null> {
    return null;
  }

  private async saveRepairTracker(userId: string, tracker: RepairTracker): Promise<void> {
  }

  private estimateRepairCost(type: string, severity: string): number {
    const baseCosts = {
      tear: { minor: 15, moderate: 35, major: 75, critical: 150 },
      stain: { minor: 10, moderate: 25, major: 50, critical: 100 },
      wear: { minor: 20, moderate: 40, major: 80, critical: 160 },
      alteration: { minor: 25, moderate: 50, major: 100, critical: 200 },
      missing_button: { minor: 5, moderate: 10, major: 15, critical: 20 },
      zipper: { minor: 20, moderate: 40, major: 80, critical: 120 }
    };

    return baseCosts[type as keyof typeof baseCosts]?.[severity as keyof typeof baseCosts[typeof type]] || 50;
  }

  private calculateUrgency(severity: string, type: string): number {
    const urgencyMap = {
      critical: 1.0,
      major: 0.8,
      moderate: 0.5,
      minor: 0.3
    };

    const typeMultiplier = {
      tear: 1.2,
      stain: 0.8,
      wear: 0.6,
      missing_button: 0.4,
      zipper: 1.0,
      alteration: 0.5
    };

    return (urgencyMap[severity as keyof typeof urgencyMap] || 0.5) *
           (typeMultiplier[type as keyof typeof typeMultiplier] || 1.0);
  }

  private categorizeByseason(items: IClothingItem[], targetSeason: string) {
    const toStore: IClothingItem[] = [];
    const toRetrieve: IClothingItem[] = [];

    items.forEach(item => {
      const seasons = item.category.season || [];

      if (seasons.includes(targetSeason) || seasons.includes('all') || seasons.length === 0) {
        toRetrieve.push(item);
      } else {
        toStore.push(item);
      }
    });

    return { toStore, toRetrieve };
  }

  private getClimateData(location: string) {
    return { temperate: true, humid: false };
  }

  private calculateRotationDates(season: string, climate: any) {
    const seasonStart = {
      spring: new Date(new Date().getFullYear(), 2, 20),
      summer: new Date(new Date().getFullYear(), 5, 20),
      autumn: new Date(new Date().getFullYear(), 8, 22),
      winter: new Date(new Date().getFullYear(), 11, 21)
    };

    const start = seasonStart[season as keyof typeof seasonStart];
    const end = new Date(start.getTime() + 90 * 86400000);

    return { start, end };
  }

  private generateStorageInstructions(items: IClothingItem[]) {
    return items.map(item => ({
      itemId: item.id,
      instructions: this.getStorageInstructions(item),
      materials: ['cedar blocks', 'acid-free tissue', 'breathable garment bag'],
      location: 'climate-controlled storage area'
    }));
  }

  private getStorageInstructions(item: IClothingItem): string[] {
    const instructions = ['Clean before storage', 'Use breathable storage'];

    if (item.materials.primary.includes('wool')) {
      instructions.push('Add cedar blocks for moth protection');
    }

    if (item.category.formality === 'formal') {
      instructions.push('Hang on padded hangers', 'Cover with breathable garment bag');
    }

    if (item.colors.primary === 'white') {
      instructions.push('Wrap in acid-free tissue paper');
    }

    return instructions;
  }

  private identifyVulnerableItems(items: IClothingItem[]): IClothingItem[] {
    return items.filter(item => {
      const material = item.materials.primary.toLowerCase();
      return material.includes('wool') ||
             material.includes('cashmere') ||
             material.includes('silk') ||
             material.includes('cotton');
    });
  }

  private assessMothRisk(items: IClothingItem[], vulnerableCount: number): 'low' | 'medium' | 'high' | 'critical' {
    const ratio = vulnerableCount / items.length;

    if (ratio > 0.7) return 'critical';
    if (ratio > 0.5) return 'high';
    if (ratio > 0.3) return 'medium';
    return 'low';
  }

  private recommendPreventiveMeasures(riskLevel: string): string[] {
    const baseMeasures = [
      'Regular cleaning and inspection',
      'Proper ventilation',
      'Cedar blocks or lavender sachets'
    ];

    if (riskLevel === 'high' || riskLevel === 'critical') {
      baseMeasures.push(
        'Professional pest control consultation',
        'Pheromone traps',
        'Temperature treatment for infested items'
      );
    }

    return baseMeasures;
  }

  private createInspectionSchedule(riskLevel: string): Date[] {
    const frequency = riskLevel === 'critical' ? 30 : riskLevel === 'high' ? 60 : 90;
    const schedule: Date[] = [];

    for (let i = 0; i < 4; i++) {
      schedule.push(new Date(Date.now() + (frequency * (i + 1) * 86400000)));
    }

    return schedule;
  }

  private async planTreatments(items: IClothingItem[], riskLevel: string) {
    const treatments = [];

    if (riskLevel === 'medium' || riskLevel === 'high' || riskLevel === 'critical') {
      treatments.push({
        type: 'cedar' as const,
        itemIds: items.map(item => item.id),
        applicationDate: new Date(),
        effectiveDuration: 180,
        cost: 25
      });
    }

    if (riskLevel === 'critical') {
      treatments.push({
        type: 'pheromone_trap' as const,
        itemIds: items.map(item => item.id),
        applicationDate: new Date(Date.now() + 7 * 86400000),
        effectiveDuration: 90,
        cost: 45
      });
    }

    return treatments;
  }

  private getBaseCleaningFrequency(type: string): number {
    const frequencies = {
      underwear: 1,
      socks: 1,
      t_shirt: 3,
      shirt: 5,
      pants: 7,
      jeans: 14,
      sweater: 21,
      jacket: 30,
      coat: 60,
      suit: 7,
      dress: 5
    };

    return frequencies[type as keyof typeof frequencies] || 14;
  }

  private async cacheMaintenanceRecord(userId: string, record: IMaintenanceRecord): Promise<void> {
    const userRecords = this.maintenanceCache.get(userId) || [];
    userRecords.push(record);
    this.maintenanceCache.set(userId, userRecords);
  }

  private async scheduleReminders(record: IMaintenanceRecord): Promise<void> {
    if (record.scheduling.dueDate) {
      const reminderDate = new Date(record.scheduling.dueDate.getTime() - 86400000);

      setTimeout(() => {
        this.notificationService.sendNotification(record.userId, {
          type: 'maintenance_reminder',
          title: 'Maintenance Due Soon',
          message: `${record.type} due tomorrow`,
          data: { recordId: record.id, itemId: record.itemId }
        });
      }, reminderDate.getTime() - Date.now());
    }
  }

  private async getUserMaintenanceRecords(userId: string): Promise<IMaintenanceRecord[]> {
    return this.maintenanceCache.get(userId) || [];
  }

  private async getMaintenanceRecord(userId: string, recordId: string): Promise<IMaintenanceRecord | null> {
    const records = this.maintenanceCache.get(userId) || [];
    return records.find(r => r.id === recordId) || null;
  }

  private async updateMaintenanceRecord(userId: string, record: IMaintenanceRecord): Promise<void> {
    const records = this.maintenanceCache.get(userId) || [];
    const index = records.findIndex(r => r.id === record.id);

    if (index >= 0) {
      records[index] = record;
      this.maintenanceCache.set(userId, records);
    }
  }

  private calculateMaintenanceTrends(records: IMaintenanceRecord[]) {
    const monthlyData = new Map<string, { tasks: number; cost: number }>();

    records.forEach(record => {
      const month = record.metadata.createdAt.toISOString().slice(0, 7);
      const current = monthlyData.get(month) || { tasks: 0, cost: 0 };

      current.tasks++;
      current.cost += record.details.actualCost || 0;

      monthlyData.set(month, current);
    });

    return Array.from(monthlyData.entries()).map(([month, data]) => ({
      month,
      tasks: data.tasks,
      cost: data.cost
    }));
  }

  private generateMaintenanceRecommendations(records: IMaintenanceRecord[]): string[] {
    const recommendations: string[] = [];

    const avgCost = records.reduce((sum, r) => sum + (r.details.actualCost || 0), 0) / records.length;

    if (avgCost > 50) {
      recommendations.push('Consider preventive maintenance to reduce repair costs');
    }

    const overdueCount = records.filter(r =>
      r.status === 'scheduled' && r.scheduling.dueDate && r.scheduling.dueDate < new Date()
    ).length;

    if (overdueCount > 3) {
      recommendations.push('Set up automated reminders to stay on top of maintenance');
    }

    return recommendations;
  }
}