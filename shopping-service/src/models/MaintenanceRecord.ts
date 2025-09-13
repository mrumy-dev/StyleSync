import { Schema, model, Document } from 'mongoose';

export interface IMaintenanceRecord extends Document {
  id: string;
  userId: string;
  itemId: string;
  type: 'cleaning' | 'repair' | 'alteration' | 'storage' | 'preventive' | 'inspection';
  status: 'scheduled' | 'in_progress' | 'completed' | 'cancelled' | 'overdue';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  details: {
    description: string;
    instructions?: string;
    estimatedCost?: number;
    actualCost?: number;
    estimatedDuration?: number;
    actualDuration?: number;
    materials?: string[];
    tools?: string[];
  };
  scheduling: {
    scheduledDate: Date;
    dueDate?: Date;
    completedDate?: Date;
    remindersSent: number;
    recurringInterval?: number;
    nextDueDate?: Date;
  };
  provider: {
    type: 'self' | 'professional' | 'dry_cleaner' | 'tailor' | 'cobbler';
    name?: string;
    contact?: string;
    address?: string;
    specialties?: string[];
    rating?: number;
  };
  care: {
    cleaningType?: 'dry_clean' | 'hand_wash' | 'machine_wash' | 'spot_clean' | 'professional';
    temperature?: string;
    detergent?: string;
    specialInstructions?: string[];
    dryingMethod?: string;
    ironingTemp?: string;
  };
  notes: string[];
  photos: {
    before?: string[];
    during?: string[];
    after?: string[];
  };
  history: Array<{
    date: Date;
    action: string;
    status: string;
    notes?: string;
    cost?: number;
  }>;
  metadata: {
    createdAt: Date;
    lastUpdated: Date;
    source: 'manual' | 'automatic' | 'calendar_sync';
    isRecurring: boolean;
  };
}

export interface IMaintenanceSchedule extends Document {
  id: string;
  userId: string;
  name: string;
  description?: string;
  rules: Array<{
    condition: {
      category?: string[];
      material?: string[];
      color?: string[];
      brand?: string[];
      age?: number;
      wearCount?: number;
      season?: string[];
    };
    action: {
      type: string;
      interval: number;
      priority: string;
      autoSchedule: boolean;
    };
    enabled: boolean;
  }>;
  preferences: {
    reminders: {
      advance: number;
      frequency: 'daily' | 'weekly' | 'monthly';
      channels: string[];
    };
    automation: {
      autoSchedule: boolean;
      autoBook: boolean;
      preferredProviders: string[];
    };
  };
  analytics: {
    totalScheduled: number;
    completed: number;
    overdue: number;
    averageCost: number;
    mostCommonType: string;
    lastAnalyzed: Date;
  };
  metadata: {
    createdAt: Date;
    lastUpdated: Date;
    isActive: boolean;
  };
}

const MaintenanceRecordSchema = new Schema<IMaintenanceRecord>({
  id: { type: String, required: true, unique: true },
  userId: { type: String, required: true, index: true },
  itemId: { type: String, required: true, index: true },
  type: {
    type: String,
    enum: ['cleaning', 'repair', 'alteration', 'storage', 'preventive', 'inspection'],
    required: true
  },
  status: {
    type: String,
    enum: ['scheduled', 'in_progress', 'completed', 'cancelled', 'overdue'],
    default: 'scheduled'
  },
  priority: {
    type: String,
    enum: ['low', 'medium', 'high', 'urgent'],
    default: 'medium'
  },
  details: {
    description: { type: String, required: true },
    instructions: String,
    estimatedCost: Number,
    actualCost: Number,
    estimatedDuration: Number,
    actualDuration: Number,
    materials: [String],
    tools: [String]
  },
  scheduling: {
    scheduledDate: { type: Date, required: true },
    dueDate: Date,
    completedDate: Date,
    remindersSent: { type: Number, default: 0 },
    recurringInterval: Number,
    nextDueDate: Date
  },
  provider: {
    type: {
      type: String,
      enum: ['self', 'professional', 'dry_cleaner', 'tailor', 'cobbler'],
      default: 'self'
    },
    name: String,
    contact: String,
    address: String,
    specialties: [String],
    rating: { type: Number, min: 1, max: 5 }
  },
  care: {
    cleaningType: {
      type: String,
      enum: ['dry_clean', 'hand_wash', 'machine_wash', 'spot_clean', 'professional']
    },
    temperature: String,
    detergent: String,
    specialInstructions: [String],
    dryingMethod: String,
    ironingTemp: String
  },
  notes: [String],
  photos: {
    before: [String],
    during: [String],
    after: [String]
  },
  history: [{
    date: { type: Date, required: true },
    action: { type: String, required: true },
    status: { type: String, required: true },
    notes: String,
    cost: Number
  }],
  metadata: {
    createdAt: { type: Date, default: Date.now },
    lastUpdated: { type: Date, default: Date.now },
    source: {
      type: String,
      enum: ['manual', 'automatic', 'calendar_sync'],
      default: 'manual'
    },
    isRecurring: { type: Boolean, default: false }
  }
}, {
  timestamps: true,
  indexes: [
    { userId: 1, status: 1 },
    { itemId: 1, type: 1 },
    { 'scheduling.dueDate': 1 },
    { priority: 1, status: 1 },
    { type: 1, status: 1 }
  ]
});

const MaintenanceScheduleSchema = new Schema<IMaintenanceSchedule>({
  id: { type: String, required: true, unique: true },
  userId: { type: String, required: true, index: true },
  name: { type: String, required: true },
  description: String,
  rules: [{
    condition: {
      category: [String],
      material: [String],
      color: [String],
      brand: [String],
      age: Number,
      wearCount: Number,
      season: [String]
    },
    action: {
      type: { type: String, required: true },
      interval: { type: Number, required: true },
      priority: {
        type: String,
        enum: ['low', 'medium', 'high', 'urgent'],
        default: 'medium'
      },
      autoSchedule: { type: Boolean, default: false }
    },
    enabled: { type: Boolean, default: true }
  }],
  preferences: {
    reminders: {
      advance: { type: Number, default: 7 },
      frequency: {
        type: String,
        enum: ['daily', 'weekly', 'monthly'],
        default: 'weekly'
      },
      channels: [String]
    },
    automation: {
      autoSchedule: { type: Boolean, default: false },
      autoBook: { type: Boolean, default: false },
      preferredProviders: [String]
    }
  },
  analytics: {
    totalScheduled: { type: Number, default: 0 },
    completed: { type: Number, default: 0 },
    overdue: { type: Number, default: 0 },
    averageCost: { type: Number, default: 0 },
    mostCommonType: String,
    lastAnalyzed: { type: Date, default: Date.now }
  },
  metadata: {
    createdAt: { type: Date, default: Date.now },
    lastUpdated: { type: Date, default: Date.now },
    isActive: { type: Boolean, default: true }
  }
}, {
  timestamps: true,
  indexes: [
    { userId: 1, 'metadata.isActive': 1 },
    { 'analytics.overdue': 1 }
  ]
});

export const MaintenanceRecord = model<IMaintenanceRecord>('MaintenanceRecord', MaintenanceRecordSchema);
export const MaintenanceSchedule = model<IMaintenanceSchedule>('MaintenanceSchedule', MaintenanceScheduleSchema);