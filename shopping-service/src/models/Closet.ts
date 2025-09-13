import { Schema, model, Document } from 'mongoose';

export interface IClosetSpace extends Document {
  id: string;
  name: string;
  type: 'walk_in' | 'reach_in' | 'wardrobe' | 'dresser' | 'chest' | 'armoire';
  dimensions: {
    width: number;
    height: number;
    depth: number;
    unit: 'cm' | 'inch';
  };
  sections: Array<{
    id: string;
    name: string;
    type: 'hanging_rod' | 'shelf' | 'drawer' | 'shoe_rack' | 'accessory_hooks';
    position: {
      x: number;
      y: number;
      z: number;
    };
    dimensions: {
      width: number;
      height: number;
      depth: number;
    };
    capacity: number;
    currentItems: string[];
    organizationRules?: {
      sortBy: 'color' | 'category' | 'season' | 'frequency' | 'brand';
      groupBy: 'type' | 'outfit' | 'season' | 'occasion';
      autoOrganize: boolean;
    };
  }>;
  climate: {
    temperature?: number;
    humidity?: number;
    lastMeasured?: Date;
    idealRange: {
      tempMin: number;
      tempMax: number;
      humidityMin: number;
      humidityMax: number;
    };
    sensors?: string[];
  };
  lighting: {
    type: 'led' | 'fluorescent' | 'incandescent' | 'natural';
    brightness?: number;
    colorTemperature?: number;
    motionActivated: boolean;
    lastChanged?: Date;
  };
  security: {
    locked: boolean;
    accessControl: string[];
    cameras?: string[];
    alarms?: string[];
  };
  metadata: {
    createdAt: Date;
    lastReorganized?: Date;
    utilizationScore: number;
    maintenanceSchedule: Date;
  };
}

export interface ICloset extends Document {
  id: string;
  userId: string;
  name: string;
  description?: string;
  spaces: IClosetSpace[];
  items: string[];
  organization: {
    strategy: 'konmari' | 'color_coordination' | 'frequency_based' | 'seasonal' | 'custom';
    autoOrganize: boolean;
    lastOrganized: Date;
    rules: Array<{
      condition: Record<string, any>;
      action: string;
      priority: number;
    }>;
  };
  digitalTwin: {
    enabled: boolean;
    lastScanned?: Date;
    model3DUrl?: string;
    arMarkers?: string[];
    virtualTourUrl?: string;
  };
  analytics: {
    totalItems: number;
    categories: Record<string, number>;
    brands: Record<string, number>;
    colors: Record<string, number>;
    utilizationRate: number;
    averageWearFrequency: number;
    lastAnalyzed: Date;
  };
  preferences: {
    seasonalRotation: boolean;
    capsuleWardrobe: boolean;
    sustainabilityFocus: boolean;
    budgetTracking: boolean;
    notifications: {
      maintenance: boolean;
      organization: boolean;
      seasonal: boolean;
      purchases: boolean;
    };
  };
  metadata: {
    createdAt: Date;
    lastUpdated: Date;
    version: number;
    isActive: boolean;
  };
}

const ClosetSpaceSchema = new Schema<IClosetSpace>({
  id: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  type: {
    type: String,
    enum: ['walk_in', 'reach_in', 'wardrobe', 'dresser', 'chest', 'armoire'],
    required: true
  },
  dimensions: {
    width: { type: Number, required: true },
    height: { type: Number, required: true },
    depth: { type: Number, required: true },
    unit: { type: String, enum: ['cm', 'inch'], default: 'cm' }
  },
  sections: [{
    id: { type: String, required: true },
    name: { type: String, required: true },
    type: {
      type: String,
      enum: ['hanging_rod', 'shelf', 'drawer', 'shoe_rack', 'accessory_hooks'],
      required: true
    },
    position: {
      x: { type: Number, required: true },
      y: { type: Number, required: true },
      z: { type: Number, required: true }
    },
    dimensions: {
      width: { type: Number, required: true },
      height: { type: Number, required: true },
      depth: { type: Number, required: true }
    },
    capacity: { type: Number, required: true },
    currentItems: [String],
    organizationRules: {
      sortBy: {
        type: String,
        enum: ['color', 'category', 'season', 'frequency', 'brand']
      },
      groupBy: {
        type: String,
        enum: ['type', 'outfit', 'season', 'occasion']
      },
      autoOrganize: { type: Boolean, default: false }
    }
  }],
  climate: {
    temperature: Number,
    humidity: Number,
    lastMeasured: Date,
    idealRange: {
      tempMin: { type: Number, default: 18 },
      tempMax: { type: Number, default: 24 },
      humidityMin: { type: Number, default: 40 },
      humidityMax: { type: Number, default: 60 }
    },
    sensors: [String]
  },
  lighting: {
    type: {
      type: String,
      enum: ['led', 'fluorescent', 'incandescent', 'natural'],
      default: 'led'
    },
    brightness: Number,
    colorTemperature: Number,
    motionActivated: { type: Boolean, default: true },
    lastChanged: Date
  },
  security: {
    locked: { type: Boolean, default: false },
    accessControl: [String],
    cameras: [String],
    alarms: [String]
  },
  metadata: {
    createdAt: { type: Date, default: Date.now },
    lastReorganized: Date,
    utilizationScore: { type: Number, default: 0 },
    maintenanceSchedule: Date
  }
});

const ClosetSchema = new Schema<ICloset>({
  id: { type: String, required: true, unique: true },
  userId: { type: String, required: true, index: true },
  name: { type: String, required: true },
  description: String,
  spaces: [ClosetSpaceSchema],
  items: [String],
  organization: {
    strategy: {
      type: String,
      enum: ['konmari', 'color_coordination', 'frequency_based', 'seasonal', 'custom'],
      default: 'frequency_based'
    },
    autoOrganize: { type: Boolean, default: true },
    lastOrganized: { type: Date, default: Date.now },
    rules: [{
      condition: Schema.Types.Mixed,
      action: { type: String, required: true },
      priority: { type: Number, default: 1 }
    }]
  },
  digitalTwin: {
    enabled: { type: Boolean, default: false },
    lastScanned: Date,
    model3DUrl: String,
    arMarkers: [String],
    virtualTourUrl: String
  },
  analytics: {
    totalItems: { type: Number, default: 0 },
    categories: Schema.Types.Mixed,
    brands: Schema.Types.Mixed,
    colors: Schema.Types.Mixed,
    utilizationRate: { type: Number, default: 0 },
    averageWearFrequency: { type: Number, default: 0 },
    lastAnalyzed: { type: Date, default: Date.now }
  },
  preferences: {
    seasonalRotation: { type: Boolean, default: true },
    capsuleWardrobe: { type: Boolean, default: false },
    sustainabilityFocus: { type: Boolean, default: false },
    budgetTracking: { type: Boolean, default: true },
    notifications: {
      maintenance: { type: Boolean, default: true },
      organization: { type: Boolean, default: true },
      seasonal: { type: Boolean, default: true },
      purchases: { type: Boolean, default: true }
    }
  },
  metadata: {
    createdAt: { type: Date, default: Date.now },
    lastUpdated: { type: Date, default: Date.now },
    version: { type: Number, default: 1 },
    isActive: { type: Boolean, default: true }
  }
}, {
  timestamps: true,
  indexes: [
    { userId: 1, name: 1 },
    { 'organization.strategy': 1 },
    { 'analytics.totalItems': 1 },
    { 'metadata.isActive': 1 }
  ]
});

export const Closet = model<ICloset>('Closet', ClosetSchema);