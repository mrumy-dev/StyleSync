import { Schema, model, Document } from 'mongoose';

export interface IPriceHistory extends Document {
  productId: string;
  store: string;
  pricePoints: {
    price: number;
    timestamp: Date;
    onSale: boolean;
    salePercentage?: number;
  }[];
  analytics: {
    averagePrice: number;
    lowestPrice: number;
    highestPrice: number;
    priceVolatility: number;
    trend: 'increasing' | 'decreasing' | 'stable';
  };
}

const PriceHistorySchema = new Schema<IPriceHistory>({
  productId: { type: String, required: true, index: true },
  store: { type: String, required: true, index: true },
  pricePoints: [{
    price: { type: Number, required: true },
    timestamp: { type: Date, required: true },
    onSale: { type: Boolean, default: false },
    salePercentage: Number
  }],
  analytics: {
    averagePrice: { type: Number, required: true },
    lowestPrice: { type: Number, required: true },
    highestPrice: { type: Number, required: true },
    priceVolatility: { type: Number, required: true },
    trend: { type: String, enum: ['increasing', 'decreasing', 'stable'], required: true }
  }
}, {
  timestamps: true
});

export const PriceHistory = model<IPriceHistory>('PriceHistory', PriceHistorySchema);