import { Schema, model, Document } from 'mongoose';

export interface IUserPreferences extends Document {
  userId: string;
  shopping: {
    favoriteCategories: string[];
    favoriteBrands: string[];
    preferredStores: string[];
    priceRange: {
      min: number;
      max: number;
    };
    sizes: {
      tops: string[];
      bottoms: string[];
      shoes: string[];
      dresses: string[];
    };
    style: {
      preferences: ('casual' | 'formal' | 'sporty' | 'bohemian' | 'minimalist' | 'vintage')[];
      colors: string[];
      patterns: string[];
      occasions: string[];
    };
    sustainability: {
      importance: 'low' | 'medium' | 'high';
      certifications: string[];
      preferEcoFriendly: boolean;
    };
  };
  notifications: {
    priceDrops: {
      enabled: boolean;
      threshold: number; // percentage
    };
    stockAlerts: boolean;
    newArrivals: boolean;
    salesAndOffers: boolean;
    recommendations: boolean;
    channels: ('push' | 'email' | 'sms' | 'in_app')[];
    frequency: 'immediate' | 'daily' | 'weekly';
    quietHours: {
      enabled: boolean;
      start: string; // HH:MM format
      end: string; // HH:MM format
    };
  };
  privacy: {
    dataRetentionDays: number;
    shareWithPartners: boolean;
    personalizedAds: boolean;
    trackingOptOut: boolean;
    anonymousMode: boolean;
  };
  recommendations: {
    visualSimilarity: {
      enabled: boolean;
      weight: number;
    };
    styleSimilarity: {
      enabled: boolean;
      weight: number;
    };
    priceBasedSuggestions: boolean;
    crossCategoryRecommendations: boolean;
    trendingItems: boolean;
  };
  accessibility: {
    highContrast: boolean;
    largeText: boolean;
    screenReader: boolean;
    colorBlindFriendly: boolean;
  };
  metadata: {
    createdAt: Date;
    lastUpdated: Date;
    profileCompleteness: number; // 0-1
    onboardingCompleted: boolean;
  };
}

const UserPreferencesSchema = new Schema<IUserPreferences>({
  userId: { type: String, required: true, unique: true, index: true },
  shopping: {
    favoriteCategories: [String],
    favoriteBrands: [String],
    preferredStores: [String],
    priceRange: {
      min: { type: Number, default: 0 },
      max: { type: Number, default: 1000 }
    },
    sizes: {
      tops: [String],
      bottoms: [String],
      shoes: [String],
      dresses: [String]
    },
    style: {
      preferences: [{
        type: String,
        enum: ['casual', 'formal', 'sporty', 'bohemian', 'minimalist', 'vintage']
      }],
      colors: [String],
      patterns: [String],
      occasions: [String]
    },
    sustainability: {
      importance: { type: String, enum: ['low', 'medium', 'high'], default: 'medium' },
      certifications: [String],
      preferEcoFriendly: { type: Boolean, default: false }
    }
  },
  notifications: {
    priceDrops: {
      enabled: { type: Boolean, default: true },
      threshold: { type: Number, default: 15 }
    },
    stockAlerts: { type: Boolean, default: true },
    newArrivals: { type: Boolean, default: false },
    salesAndOffers: { type: Boolean, default: true },
    recommendations: { type: Boolean, default: true },
    channels: [{
      type: String,
      enum: ['push', 'email', 'sms', 'in_app'],
      default: ['push', 'in_app']
    }],
    frequency: { type: String, enum: ['immediate', 'daily', 'weekly'], default: 'immediate' },
    quietHours: {
      enabled: { type: Boolean, default: false },
      start: { type: String, default: '22:00' },
      end: { type: String, default: '08:00' }
    }
  },
  privacy: {
    dataRetentionDays: { type: Number, default: 90 },
    shareWithPartners: { type: Boolean, default: false },
    personalizedAds: { type: Boolean, default: false },
    trackingOptOut: { type: Boolean, default: true },
    anonymousMode: { type: Boolean, default: false }
  },
  recommendations: {
    visualSimilarity: {
      enabled: { type: Boolean, default: true },
      weight: { type: Number, default: 0.4 }
    },
    styleSimilarity: {
      enabled: { type: Boolean, default: true },
      weight: { type: Number, default: 0.3 }
    },
    priceBasedSuggestions: { type: Boolean, default: true },
    crossCategoryRecommendations: { type: Boolean, default: true },
    trendingItems: { type: Boolean, default: false }
  },
  accessibility: {
    highContrast: { type: Boolean, default: false },
    largeText: { type: Boolean, default: false },
    screenReader: { type: Boolean, default: false },
    colorBlindFriendly: { type: Boolean, default: false }
  },
  metadata: {
    createdAt: { type: Date, default: Date.now },
    lastUpdated: { type: Date, default: Date.now },
    profileCompleteness: { type: Number, default: 0, min: 0, max: 1 },
    onboardingCompleted: { type: Boolean, default: false }
  }
}, {
  timestamps: true
});

UserPreferencesSchema.methods.calculateCompleteness = function(): number {
  const fields = [
    this.shopping.favoriteCategories.length > 0,
    this.shopping.favoriteBrands.length > 0,
    this.shopping.sizes.tops.length > 0 || this.shopping.sizes.bottoms.length > 0,
    this.shopping.style.preferences.length > 0,
    this.shopping.style.colors.length > 0,
    this.shopping.priceRange.max > this.shopping.priceRange.min
  ];
  
  return fields.filter(Boolean).length / fields.length;
};

UserPreferencesSchema.pre('save', function(next) {
  this.metadata.lastUpdated = new Date();
  this.metadata.profileCompleteness = this.calculateCompleteness();
  next();
});

export const UserPreferences = model<IUserPreferences>('UserPreferences', UserPreferencesSchema);