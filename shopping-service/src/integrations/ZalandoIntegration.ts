import axios from 'axios';
import { BaseStoreIntegration, StoreConfig, SearchFilters, ProductSearchResult } from './BaseStoreIntegration';
import { IProduct } from '../models/Product';

export class ZalandoIntegration extends BaseStoreIntegration {
  constructor() {
    const config: StoreConfig = {
      name: 'Zalando',
      baseUrl: 'https://api.zalando.com',
      rateLimits: {
        requestsPerMinute: 100,
        requestsPerHour: 1000
      },
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'StyleSync-Shopping-Service/1.0'
      },
      endpoints: {
        products: '/articles',
        search: '/articles',
        categories: '/categories',
        product: '/articles/{id}'
      }
    };
    super(config);
  }

  async searchProducts(filters: SearchFilters): Promise<ProductSearchResult> {
    return this.rateLimitedRequest(async () => {
      const params = new URLSearchParams();
      
      if (filters.query) params.append('fullText', filters.query);
      if (filters.category) params.append('category', filters.category);
      if (filters.brand) params.append('brand', filters.brand);
      if (filters.priceMin) params.append('priceFrom', filters.priceMin.toString());
      if (filters.priceMax) params.append('priceTo', filters.priceMax.toString());
      if (filters.colors?.length) params.append('color', filters.colors.join(','));
      if (filters.sizes?.length) params.append('size', filters.sizes.join(','));
      if (filters.limit) params.append('pageSize', filters.limit.toString());
      if (filters.offset) params.append('page', Math.floor(filters.offset / (filters.limit || 20)).toString());

      const response = await axios.get(`${this.config.baseUrl}${this.config.endpoints.search}`, {
        params,
        headers: this.config.headers
      });

      const products = response.data.content.map((item: any) => this.transformZalandoProduct(item));
      
      return {
        products,
        totalCount: response.data.totalElements || 0,
        hasMore: response.data.totalPages > (response.data.number + 1),
        filters: {
          categories: response.data.filters?.categories || [],
          brands: response.data.filters?.brands || [],
          priceRange: {
            min: response.data.filters?.priceRange?.min || 0,
            max: response.data.filters?.priceRange?.max || 1000
          },
          colors: response.data.filters?.colors || [],
          sizes: response.data.filters?.sizes || []
        }
      };
    });
  }

  async getProduct(productId: string): Promise<IProduct | null> {
    return this.rateLimitedRequest(async () => {
      try {
        const response = await axios.get(
          `${this.config.baseUrl}${this.config.endpoints.product?.replace('{id}', productId)}`,
          { headers: this.config.headers }
        );
        
        return this.transformZalandoProduct(response.data, true);
      } catch (error) {
        if (axios.isAxiosError(error) && error.response?.status === 404) {
          return null;
        }
        throw error;
      }
    });
  }

  async getCategories(): Promise<string[]> {
    return this.rateLimitedRequest(async () => {
      const response = await axios.get(`${this.config.baseUrl}${this.config.endpoints.categories}`, {
        headers: this.config.headers
      });
      
      return response.data.map((cat: any) => cat.name);
    });
  }

  async getBrands(): Promise<string[]> {
    return this.rateLimitedRequest(async () => {
      const response = await axios.get(`${this.config.baseUrl}/brands`, {
        headers: this.config.headers
      });
      
      return response.data.map((brand: any) => brand.name);
    });
  }

  private transformZalandoProduct(item: any, detailed: boolean = false): Partial<IProduct> {
    const colors = this.extractColors(item.name + ' ' + (item.color || ''));
    const sizes = item.units?.map((unit: any) => unit.size) || [];
    const materials = this.extractMaterials(item.description || '');

    const product: Partial<IProduct> = {
      id: this.generateProductId(item.sku),
      name: item.name,
      brand: item.brand?.name || 'Unknown',
      description: item.description || '',
      price: {
        current: this.normalizePrice(item.price?.value || 0),
        original: item.originalPrice ? this.normalizePrice(item.originalPrice.value) : undefined,
        currency: item.price?.currency || 'EUR'
      },
      images: {
        main: item.media?.images?.[0]?.largeUrl || '',
        gallery: item.media?.images?.map((img: any) => img.largeUrl) || [],
        thumbnail: item.media?.images?.[0]?.smallUrl
      },
      sizes: {
        available: sizes,
        sizeChart: item.sizeGuide
      },
      colors: {
        available: colors,
        colorCodes: {}
      },
      materials,
      category: {
        main: item.category?.name || 'Fashion',
        sub: item.subCategory?.name || 'General',
        tags: item.tags || []
      },
      store: {
        name: 'Zalando',
        url: item.shopUrl || `https://www.zalando.com/products/${item.sku}`,
        productId: item.sku
      },
      availability: {
        inStock: item.available || false,
        quantity: item.units?.reduce((sum: number, unit: any) => sum + (unit.stock || 0), 0)
      },
      ratings: {
        average: item.rating?.average || 0,
        count: item.rating?.count || 0,
        reviews: detailed ? item.reviews : undefined
      },
      sustainability: {
        certifications: item.sustainability?.certifications || [],
        score: item.sustainability?.score
      },
      metadata: {
        scrapedAt: new Date(),
        lastUpdated: new Date(),
        dataQuality: detailed ? 1.0 : 0.8,
        source: 'zalando-api'
      }
    };

    return product;
  }
}