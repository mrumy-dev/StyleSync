import { Schema, model, Document } from 'mongoose';

export interface IProduct extends Document {
  id: string;
  name: string;
  brand: string;
  description: string;
  price: {
    current: number;
    original?: number;
    currency: string;
  };
  images: {
    main: string;
    gallery: string[];
    thumbnail?: string;
  };
  sizes: {
    available: string[];
    sizeChart?: Record<string, any>;
  };
  colors: {
    available: string[];
    colorCodes: Record<string, string>;
  };
  materials: string[];
  category: {
    main: string;
    sub: string;
    tags: string[];
  };
  store: {
    name: string;
    url: string;
    productId: string;
  };
  availability: {
    inStock: boolean;
    quantity?: number;
    restockDate?: Date;
  };
  ratings: {
    average: number;
    count: number;
    reviews?: any[];
  };
  sustainability: {
    score?: number;
    certifications: string[];
    carbonFootprint?: number;
  };
  metadata: {
    scrapedAt: Date;
    lastUpdated: Date;
    dataQuality: number;
    source: string;
  };
}

const ProductSchema = new Schema<IProduct>({
  id: { type: String, required: true, unique: true },
  name: { type: String, required: true, index: true },
  brand: { type: String, required: true, index: true },
  description: { type: String, required: true },
  price: {
    current: { type: Number, required: true },
    original: Number,
    currency: { type: String, default: 'USD' }
  },
  images: {
    main: { type: String, required: true },
    gallery: [String],
    thumbnail: String
  },
  sizes: {
    available: [String],
    sizeChart: Schema.Types.Mixed
  },
  colors: {
    available: [String],
    colorCodes: Schema.Types.Mixed
  },
  materials: [String],
  category: {
    main: { type: String, required: true, index: true },
    sub: { type: String, required: true },
    tags: [String]
  },
  store: {
    name: { type: String, required: true, index: true },
    url: { type: String, required: true },
    productId: { type: String, required: true }
  },
  availability: {
    inStock: { type: Boolean, required: true },
    quantity: Number,
    restockDate: Date
  },
  ratings: {
    average: { type: Number, default: 0 },
    count: { type: Number, default: 0 },
    reviews: [Schema.Types.Mixed]
  },
  sustainability: {
    score: Number,
    certifications: [String],
    carbonFootprint: Number
  },
  metadata: {
    scrapedAt: { type: Date, default: Date.now },
    lastUpdated: { type: Date, default: Date.now },
    dataQuality: { type: Number, default: 1.0 },
    source: { type: String, required: true }
  }
}, {
  timestamps: true,
  indexes: [
    { name: 1, brand: 1 },
    { 'category.main': 1, 'category.sub': 1 },
    { 'store.name': 1 },
    { 'price.current': 1 },
    { 'availability.inStock': 1 }
  ]
});

export const Product = model<IProduct>('Product', ProductSchema);