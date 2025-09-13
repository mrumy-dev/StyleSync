import { Schema, model, Document } from 'mongoose';

export interface IOutfit extends Document {
  id: string;
  userId: string;
  name: string;
  description?: string;
  items: Array<{
    itemId: string;
    category: string;
    essential: boolean;
    alternatives?: string[];
  }>;
  occasions: string[];
  seasons: string[];
  formality: 'casual' | 'business' | 'formal' | 'athletic' | 'lounge';
  colors: {
    palette: string[];
    dominant: string;
    accent?: string;
    harmony: 'monochrome' | 'analogous' | 'complementary' | 'triadic' | 'split_complementary';
  };
  style: {
    aesthetic: string[];
    mood: string;
    inspiration?: string;
  };
  weather: {
    minTemp?: number;
    maxTemp?: number;
    conditions: string[];
    indoor: boolean;
  };
  images: {
    main?: string;
    flat_lay?: string;
    worn?: string[];
    details?: string[];
  };
  ratings: {
    comfort: number;
    style: number;
    versatility: number;
    overall: number;
    notes?: string;
  };
  usage: {
    timesWorn: number;
    lastWorn?: Date;
    plannedWears: Array<{
      date: Date;
      occasion: string;
      location?: string;
      notes?: string;
    }>;
    feedback: Array<{
      date: Date;
      rating: number;
      comments?: string;
      improvements?: string[];
    }>;
  };
  capsule: {
    isCapsule: boolean;
    capsuleName?: string;
    essential: boolean;
    versatilityScore: number;
  };
  tags: string[];
  metadata: {
    createdAt: Date;
    lastModified: Date;
    source: 'manual' | 'ai_generated' | 'inspiration' | 'recommendation';
    aiScore?: number;
    popularity?: number;
  };
}

export interface IOutfitSet extends Document {
  id: string;
  userId: string;
  name: string;
  description?: string;
  outfits: string[];
  type: 'capsule' | 'seasonal' | 'occasion' | 'travel' | 'work_week';
  theme: {
    style: string;
    colors: string[];
    pieces: number;
    versatility: number;
  };
  rules: Array<{
    type: 'mixing' | 'matching' | 'layering' | 'seasonal';
    description: string;
    priority: number;
  }>;
  analytics: {
    totalOutfits: number;
    averageRating: number;
    mostWorn: string;
    leastWorn: string;
    gapAnalysis: string[];
  };
  metadata: {
    createdAt: Date;
    lastUpdated: Date;
    isActive: boolean;
  };
}

const OutfitSchema = new Schema<IOutfit>({
  id: { type: String, required: true, unique: true },
  userId: { type: String, required: true, index: true },
  name: { type: String, required: true },
  description: String,
  items: [{
    itemId: { type: String, required: true },
    category: { type: String, required: true },
    essential: { type: Boolean, default: true },
    alternatives: [String]
  }],
  occasions: [String],
  seasons: [String],
  formality: {
    type: String,
    enum: ['casual', 'business', 'formal', 'athletic', 'lounge'],
    required: true
  },
  colors: {
    palette: [String],
    dominant: { type: String, required: true },
    accent: String,
    harmony: {
      type: String,
      enum: ['monochrome', 'analogous', 'complementary', 'triadic', 'split_complementary']
    }
  },
  style: {
    aesthetic: [String],
    mood: { type: String, required: true },
    inspiration: String
  },
  weather: {
    minTemp: Number,
    maxTemp: Number,
    conditions: [String],
    indoor: { type: Boolean, default: false }
  },
  images: {
    main: String,
    flat_lay: String,
    worn: [String],
    details: [String]
  },
  ratings: {
    comfort: { type: Number, min: 1, max: 5, default: 3 },
    style: { type: Number, min: 1, max: 5, default: 3 },
    versatility: { type: Number, min: 1, max: 5, default: 3 },
    overall: { type: Number, min: 1, max: 5, default: 3 },
    notes: String
  },
  usage: {
    timesWorn: { type: Number, default: 0 },
    lastWorn: Date,
    plannedWears: [{
      date: { type: Date, required: true },
      occasion: { type: String, required: true },
      location: String,
      notes: String
    }],
    feedback: [{
      date: { type: Date, required: true },
      rating: { type: Number, min: 1, max: 5, required: true },
      comments: String,
      improvements: [String]
    }]
  },
  capsule: {
    isCapsule: { type: Boolean, default: false },
    capsuleName: String,
    essential: { type: Boolean, default: false },
    versatilityScore: { type: Number, default: 0 }
  },
  tags: [String],
  metadata: {
    createdAt: { type: Date, default: Date.now },
    lastModified: { type: Date, default: Date.now },
    source: {
      type: String,
      enum: ['manual', 'ai_generated', 'inspiration', 'recommendation'],
      default: 'manual'
    },
    aiScore: Number,
    popularity: Number
  }
}, {
  timestamps: true,
  indexes: [
    { userId: 1, name: 1 },
    { formality: 1, seasons: 1 },
    { occasions: 1 },
    { 'ratings.overall': 1 },
    { 'usage.timesWorn': 1 },
    { 'capsule.isCapsule': 1 },
    { tags: 1 }
  ]
});

const OutfitSetSchema = new Schema<IOutfitSet>({
  id: { type: String, required: true, unique: true },
  userId: { type: String, required: true, index: true },
  name: { type: String, required: true },
  description: String,
  outfits: [String],
  type: {
    type: String,
    enum: ['capsule', 'seasonal', 'occasion', 'travel', 'work_week'],
    required: true
  },
  theme: {
    style: { type: String, required: true },
    colors: [String],
    pieces: { type: Number, required: true },
    versatility: { type: Number, default: 0 }
  },
  rules: [{
    type: {
      type: String,
      enum: ['mixing', 'matching', 'layering', 'seasonal'],
      required: true
    },
    description: { type: String, required: true },
    priority: { type: Number, default: 1 }
  }],
  analytics: {
    totalOutfits: { type: Number, default: 0 },
    averageRating: { type: Number, default: 0 },
    mostWorn: String,
    leastWorn: String,
    gapAnalysis: [String]
  },
  metadata: {
    createdAt: { type: Date, default: Date.now },
    lastUpdated: { type: Date, default: Date.now },
    isActive: { type: Boolean, default: true }
  }
}, {
  timestamps: true,
  indexes: [
    { userId: 1, type: 1 },
    { 'metadata.isActive': 1 }
  ]
});

export const Outfit = model<IOutfit>('Outfit', OutfitSchema);
export const OutfitSet = model<IOutfitSet>('OutfitSet', OutfitSetSchema);