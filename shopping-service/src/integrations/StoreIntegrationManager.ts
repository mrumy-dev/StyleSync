import { BaseStoreIntegration, SearchFilters, ProductSearchResult } from './BaseStoreIntegration';
import { ZalandoIntegration } from './ZalandoIntegration';
import { ASOSIntegration } from './ASOSIntegration';
import { NordstromIntegration } from './NordstromIntegration';
import { IProduct } from '../models/Product';

export interface StoreIntegrationConfig {
  enabled: boolean;
  priority: number;
  maxConcurrentRequests?: number;
}

export class StoreIntegrationManager {
  private integrations: Map<string, BaseStoreIntegration> = new Map();
  private config: Map<string, StoreIntegrationConfig> = new Map();

  constructor() {
    this.initializeIntegrations();
  }

  private initializeIntegrations() {
    // Initialize store integrations
    this.integrations.set('zalando', new ZalandoIntegration());
    this.integrations.set('asos', new ASOSIntegration());
    this.integrations.set('nordstrom', new NordstromIntegration());

    // Set default configurations
    this.config.set('zalando', { enabled: true, priority: 1, maxConcurrentRequests: 5 });
    this.config.set('asos', { enabled: true, priority: 2, maxConcurrentRequests: 8 });
    this.config.set('nordstrom', { enabled: true, priority: 3, maxConcurrentRequests: 3 });
  }

  async searchAllStores(filters: SearchFilters): Promise<{
    results: Map<string, ProductSearchResult>;
    aggregated: ProductSearchResult;
    errors: Map<string, Error>;
  }> {
    const enabledStores = Array.from(this.integrations.entries())
      .filter(([storeName]) => this.config.get(storeName)?.enabled)
      .sort(([a], [b]) => {
        const priorityA = this.config.get(a)?.priority || 999;
        const priorityB = this.config.get(b)?.priority || 999;
        return priorityA - priorityB;
      });

    const results = new Map<string, ProductSearchResult>();
    const errors = new Map<string, Error>();
    
    // Search all stores concurrently
    const searchPromises = enabledStores.map(async ([storeName, integration]) => {
      try {
        const result = await integration.searchProducts(filters);
        results.set(storeName, result);
      } catch (error) {
        errors.set(storeName, error as Error);
      }
    });

    await Promise.allSettled(searchPromises);

    // Aggregate results
    const aggregated = this.aggregateSearchResults(results);

    return { results, aggregated, errors };
  }

  async getProductFromStore(storeName: string, productId: string): Promise<IProduct | null> {
    const integration = this.integrations.get(storeName);
    if (!integration) {
      throw new Error(`Store integration not found: ${storeName}`);
    }

    const config = this.config.get(storeName);
    if (!config?.enabled) {
      throw new Error(`Store integration disabled: ${storeName}`);
    }

    return integration.getProduct(productId);
  }

  async searchSingleStore(storeName: string, filters: SearchFilters): Promise<ProductSearchResult> {
    const integration = this.integrations.get(storeName);
    if (!integration) {
      throw new Error(`Store integration not found: ${storeName}`);
    }

    const config = this.config.get(storeName);
    if (!config?.enabled) {
      throw new Error(`Store integration disabled: ${storeName}`);
    }

    return integration.searchProducts(filters);
  }

  async getAllCategories(): Promise<Map<string, string[]>> {
    const categories = new Map<string, string[]>();
    
    const categoryPromises = Array.from(this.integrations.entries())
      .filter(([storeName]) => this.config.get(storeName)?.enabled)
      .map(async ([storeName, integration]) => {
        try {
          const storeCategories = await integration.getCategories();
          categories.set(storeName, storeCategories);
        } catch (error) {
          console.error(`Failed to get categories from ${storeName}:`, error);
          categories.set(storeName, []);
        }
      });

    await Promise.allSettled(categoryPromises);
    return categories;
  }

  async getAllBrands(): Promise<Map<string, string[]>> {
    const brands = new Map<string, string[]>();
    
    const brandPromises = Array.from(this.integrations.entries())
      .filter(([storeName]) => this.config.get(storeName)?.enabled)
      .map(async ([storeName, integration]) => {
        try {
          const storeBrands = await integration.getBrands();
          brands.set(storeName, storeBrands);
        } catch (error) {
          console.error(`Failed to get brands from ${storeName}:`, error);
          brands.set(storeName, []);
        }
      });

    await Promise.allSettled(brandPromises);
    return brands;
  }

  private aggregateSearchResults(results: Map<string, ProductSearchResult>): ProductSearchResult {
    const allProducts: Partial<IProduct>[] = [];
    const allCategories: Set<string> = new Set();
    const allBrands: Set<string> = new Set();
    const allColors: Set<string> = new Set();
    const allSizes: Set<string> = new Set();
    
    let totalCount = 0;
    let minPrice = Infinity;
    let maxPrice = 0;
    let hasMore = false;

    for (const [storeName, result] of results) {
      allProducts.push(...result.products);
      totalCount += result.totalCount;
      hasMore = hasMore || result.hasMore;

      // Aggregate filters
      result.filters.categories.forEach(cat => allCategories.add(cat));
      result.filters.brands.forEach(brand => allBrands.add(brand));
      result.filters.colors.forEach(color => allColors.add(color));
      result.filters.sizes.forEach(size => allSizes.add(size));
      
      minPrice = Math.min(minPrice, result.filters.priceRange.min);
      maxPrice = Math.max(maxPrice, result.filters.priceRange.max);
    }

    // Remove duplicates and sort products by relevance/price
    const uniqueProducts = this.deduplicateProducts(allProducts);
    const sortedProducts = this.sortProductsByRelevance(uniqueProducts);

    return {
      products: sortedProducts,
      totalCount,
      hasMore,
      filters: {
        categories: Array.from(allCategories).sort(),
        brands: Array.from(allBrands).sort(),
        priceRange: {
          min: minPrice === Infinity ? 0 : minPrice,
          max: maxPrice
        },
        colors: Array.from(allColors).sort(),
        sizes: Array.from(allSizes).sort()
      }
    };
  }

  private deduplicateProducts(products: Partial<IProduct>[]): Partial<IProduct>[] {
    const seen = new Map<string, Partial<IProduct>>();
    
    for (const product of products) {
      if (!product.name || !product.brand) continue;
      
      const key = `${product.name.toLowerCase()}-${product.brand.toLowerCase()}`;
      const existing = seen.get(key);
      
      if (!existing || (product.metadata?.dataQuality || 0) > (existing.metadata?.dataQuality || 0)) {
        seen.set(key, product);
      }
    }
    
    return Array.from(seen.values());
  }

  private sortProductsByRelevance(products: Partial<IProduct>[]): Partial<IProduct>[] {
    return products.sort((a, b) => {
      // Sort by data quality first
      const qualityA = a.metadata?.dataQuality || 0;
      const qualityB = b.metadata?.dataQuality || 0;
      
      if (qualityA !== qualityB) {
        return qualityB - qualityA;
      }
      
      // Then by availability
      const stockA = a.availability?.inStock ? 1 : 0;
      const stockB = b.availability?.inStock ? 1 : 0;
      
      if (stockA !== stockB) {
        return stockB - stockA;
      }
      
      // Finally by rating
      const ratingA = a.ratings?.average || 0;
      const ratingB = b.ratings?.average || 0;
      
      return ratingB - ratingA;
    });
  }

  getEnabledStores(): string[] {
    return Array.from(this.integrations.keys())
      .filter(storeName => this.config.get(storeName)?.enabled);
  }

  configureStore(storeName: string, config: StoreIntegrationConfig): void {
    if (!this.integrations.has(storeName)) {
      throw new Error(`Store integration not found: ${storeName}`);
    }
    
    this.config.set(storeName, config);
  }

  getStoreConfig(storeName: string): StoreIntegrationConfig | undefined {
    return this.config.get(storeName);
  }
}