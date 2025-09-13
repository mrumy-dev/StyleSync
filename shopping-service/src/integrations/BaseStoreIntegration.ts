import { IProduct } from '../models/Product';

export interface StoreConfig {
  name: string;
  baseUrl: string;
  apiKey?: string;
  rateLimits: {
    requestsPerMinute: number;
    requestsPerHour: number;
  };
  headers: Record<string, string>;
  endpoints: {
    products?: string;
    search?: string;
    categories?: string;
    product?: string;
  };
}

export interface SearchFilters {
  category?: string;
  brand?: string;
  priceMin?: number;
  priceMax?: number;
  colors?: string[];
  sizes?: string[];
  inStock?: boolean;
  onSale?: boolean;
  sustainable?: boolean;
  query?: string;
  limit?: number;
  offset?: number;
}

export interface ProductSearchResult {
  products: Partial<IProduct>[];
  totalCount: number;
  hasMore: boolean;
  filters: {
    categories: string[];
    brands: string[];
    priceRange: { min: number; max: number };
    colors: string[];
    sizes: string[];
  };
}

export abstract class BaseStoreIntegration {
  protected config: StoreConfig;
  protected lastRequestTime: number = 0;
  protected requestCount: { minute: number; hour: number } = { minute: 0, hour: 0 };

  constructor(config: StoreConfig) {
    this.config = config;
  }

  abstract searchProducts(filters: SearchFilters): Promise<ProductSearchResult>;
  abstract getProduct(productId: string): Promise<IProduct | null>;
  abstract getCategories(): Promise<string[]>;
  abstract getBrands(): Promise<string[]>;

  protected async rateLimitedRequest<T>(
    requestFn: () => Promise<T>
  ): Promise<T> {
    const now = Date.now();
    const timeSinceLastRequest = now - this.lastRequestTime;
    const minInterval = 60000 / this.config.rateLimits.requestsPerMinute;

    if (timeSinceLastRequest < minInterval) {
      const waitTime = minInterval - timeSinceLastRequest;
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }

    // Reset counters every minute/hour
    const currentMinute = Math.floor(now / 60000);
    const currentHour = Math.floor(now / 3600000);
    
    if (Math.floor(this.lastRequestTime / 60000) !== currentMinute) {
      this.requestCount.minute = 0;
    }
    if (Math.floor(this.lastRequestTime / 3600000) !== currentHour) {
      this.requestCount.hour = 0;
    }

    this.requestCount.minute++;
    this.requestCount.hour++;
    this.lastRequestTime = now;

    return requestFn();
  }

  protected generateProductId(storeProductId: string): string {
    return `${this.config.name.toLowerCase()}_${storeProductId}`;
  }

  protected normalizePrice(price: string | number): number {
    if (typeof price === 'number') return price;
    return parseFloat(price.replace(/[^\d.]/g, ''));
  }

  protected extractColors(text: string): string[] {
    const colorPattern = /(black|white|red|blue|green|yellow|orange|purple|pink|brown|gray|grey|beige|navy|maroon|teal|olive|lime|aqua|silver|gold|rose|coral|mint|lavender|cream|ivory|tan|khaki|burgundy|magenta|cyan|indigo|violet|turquoise|salmon|peach|plum)/gi;
    const matches = text.match(colorPattern) || [];
    return [...new Set(matches.map(color => color.toLowerCase()))];
  }

  protected extractSizes(text: string): string[] {
    const sizePattern = /\b(XXS|XS|S|M|L|XL|XXL|XXXL|\d{1,2}|\d{2}-\d{2}|\d{1,2}[A-Z]?)\b/gi;
    const matches = text.match(sizePattern) || [];
    return [...new Set(matches)];
  }

  protected extractMaterials(text: string): string[] {
    const materialPattern = /(cotton|wool|silk|linen|polyester|nylon|spandex|elastane|cashmere|leather|suede|denim|canvas|velvet|satin|chiffon|jersey|flannel|tweed|corduroy|bamboo|hemp|organic cotton|recycled polyester)/gi;
    const matches = text.match(materialPattern) || [];
    return [...new Set(matches.map(material => material.toLowerCase()))];
  }
}