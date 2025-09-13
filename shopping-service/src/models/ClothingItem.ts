import { Schema, model, Document } from 'mongoose';

export interface IClothingItem extends Document {
  id: string;
  name: string;
  brand?: string;
  category: {
    main: string;
    sub: string;
    type: string;
    season: string[];
    occasion: string[];
    formality: 'casual' | 'business' | 'formal' | 'athletic' | 'lounge';
  };
  colors: {
    primary: string;
    secondary?: string[];
    colorCodes: Record<string, string>;
    colorFamily: string;
  };
  materials: {
    primary: string;
    composition: Record<string, number>;
    careInstructions: string[];
    sustainability: {
      score?: number;
      certifications: string[];
      recyclable: boolean;
    };
  };
  size: {
    label: string;
    measurements?: Record<string, number>;
    fit: 'tight' | 'fitted' | 'regular' | 'loose' | 'oversized';
  };
  condition: {
    status: 'new' | 'excellent' | 'good' | 'fair' | 'poor';
    notes?: string;
    defects?: string[];
    repairHistory?: Array<{
      date: Date;
      description: string;
      cost?: number;
    }>;
  };
  purchase: {
    date?: Date;
    price?: number;
    currency?: string;
    store?: string;
    receipt?: string;
    warranty?: {
      expires: Date;
      terms: string;
    };
  };
  valuation: {
    current?: number;
    original?: number;
    depreciationRate?: number;
    lastUpdated?: Date;
  };
  images: {
    main: string;
    gallery: string[];
    thumbnail?: string;
    details?: string[];
  };
  tags: string[];
  notes?: string;
  metadata: {
    addedAt: Date;
    lastWorn?: Date;
    wearCount: number;
    lastUpdated: Date;
    source: 'manual' | 'import' | 'receipt_scan' | 'barcode';
    rfidTag?: string;
    barcode?: string;
  };
}

const ClothingItemSchema = new Schema<IClothingItem>({
  id: { type: String, required: true, unique: true },
  name: { type: String, required: true, index: true },
  brand: { type: String, index: true },
  category: {
    main: { type: String, required: true, index: true },
    sub: { type: String, required: true },
    type: { type: String, required: true },
    season: [String],
    occasion: [String],
    formality: {
      type: String,
      enum: ['casual', 'business', 'formal', 'athletic', 'lounge'],
      required: true
    }
  },
  colors: {
    primary: { type: String, required: true, index: true },
    secondary: [String],
    colorCodes: Schema.Types.Mixed,
    colorFamily: { type: String, required: true, index: true }
  },
  materials: {
    primary: { type: String, required: true },
    composition: Schema.Types.Mixed,
    careInstructions: [String],
    sustainability: {
      score: Number,
      certifications: [String],
      recyclable: { type: Boolean, default: false }
    }
  },
  size: {
    label: { type: String, required: true },
    measurements: Schema.Types.Mixed,
    fit: {
      type: String,
      enum: ['tight', 'fitted', 'regular', 'loose', 'oversized'],
      required: true
    }
  },
  condition: {
    status: {
      type: String,
      enum: ['new', 'excellent', 'good', 'fair', 'poor'],
      required: true
    },
    notes: String,
    defects: [String],
    repairHistory: [{
      date: { type: Date, required: true },
      description: { type: String, required: true },
      cost: Number
    }]
  },
  purchase: {
    date: Date,
    price: Number,
    currency: { type: String, default: 'USD' },
    store: String,
    receipt: String,
    warranty: {
      expires: Date,
      terms: String
    }
  },
  valuation: {
    current: Number,
    original: Number,
    depreciationRate: Number,
    lastUpdated: Date
  },
  images: {
    main: { type: String, required: true },
    gallery: [String],
    thumbnail: String,
    details: [String]
  },
  tags: [String],
  notes: String,
  metadata: {
    addedAt: { type: Date, default: Date.now },
    lastWorn: Date,
    wearCount: { type: Number, default: 0 },
    lastUpdated: { type: Date, default: Date.now },
    source: {
      type: String,
      enum: ['manual', 'import', 'receipt_scan', 'barcode'],
      default: 'manual'
    },
    rfidTag: String,
    barcode: String
  }
}, {
  timestamps: true,
  indexes: [
    { name: 1, brand: 1 },
    { 'category.main': 1, 'category.sub': 1 },
    { 'colors.primary': 1, 'colors.colorFamily': 1 },
    { 'category.formality': 1 },
    { 'metadata.lastWorn': 1 },
    { 'metadata.wearCount': 1 },
    { tags: 1 }
  ]
});

export const ClothingItem = model<IClothingItem>('ClothingItem', ClothingItemSchema);