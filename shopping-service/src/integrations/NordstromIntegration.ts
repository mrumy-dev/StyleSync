import axios from 'axios';
import { BaseStoreIntegration, StoreConfig, SearchFilters, ProductSearchResult } from './BaseStoreIntegration';
import { IProduct } from '../models/Product';

export class NordstromIntegration extends BaseStoreIntegration {
  constructor() {
    const config: StoreConfig = {
      name: 'Nordstrom',
      baseUrl: 'https://api.nordstrom.com',
      rateLimits: {
        requestsPerMinute: 60,
        requestsPerHour: 1000
      },
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'StyleSync-Shopping-Service/1.0'
      },
      endpoints: {
        products: '/rest/products/search',
        product: '/rest/products/{id}',
        categories: '/rest/categories'
      }
    };
    super(config);
  }

  async searchProducts(filters: SearchFilters): Promise<ProductSearchResult> {
    return this.rateLimitedRequest(async () => {
      const params = new URLSearchParams();
      
      if (filters.query) params.append('keyword', filters.query);
      if (filters.category) params.append('category', filters.category);
      if (filters.brand) params.append('brand', filters.brand);
      if (filters.priceMin) params.append('price_low', filters.priceMin.toString());
      if (filters.priceMax) params.append('price_high', filters.priceMax.toString());
      if (filters.colors?.length) params.append('color', filters.colors.join(','));
      if (filters.sizes?.length) params.append('size', filters.sizes.join(','));
      if (filters.limit) params.append('limit', filters.limit.toString());
      if (filters.offset) params.append('offset', filters.offset.toString());

      const response = await axios.get(`${this.config.baseUrl}${this.config.endpoints.products}`, {
        params,
        headers: this.config.headers
      });

      const products = response.data._embedded?.products?.map((item: any) => this.transformNordstromProduct(item)) || [];
      
      return {
        products,
        totalCount: response.data.totalResults || 0,
        hasMore: response.data.totalResults > (filters.offset || 0) + products.length,
        filters: {
          categories: response.data._embedded?.facets?.category?.values?.map((f: any) => f.name) || [],
          brands: response.data._embedded?.facets?.brand?.values?.map((f: any) => f.name) || [],
          priceRange: {
            min: response.data._embedded?.facets?.price?.min || 0,
            max: response.data._embedded?.facets?.price?.max || 1000
          },
          colors: response.data._embedded?.facets?.color?.values?.map((f: any) => f.name) || [],
          sizes: response.data._embedded?.facets?.size?.values?.map((f: any) => f.name) || []
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
        
        return this.transformNordstromProduct(response.data, true);
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
      
      return response.data._embedded?.categories?.map((cat: any) => cat.name) || [];
    });
  }

  async getBrands(): Promise<string[]> {
    return this.rateLimitedRequest(async () => {
      const response = await axios.get(`${this.config.baseUrl}/rest/brands`, {
        headers: this.config.headers
      });
      
      return response.data._embedded?.brands?.map((brand: any) => brand.name) || [];
    });
  }

  private transformNordstromProduct(item: any, detailed: boolean = false): Partial<IProduct> {
    const colors = this.extractColors(item.name + ' ' + (item.colorName || ''));
    const materials = this.extractMaterials(item.description || item.details?.join(' ') || '');

    const product: Partial<IProduct> = {
      id: this.generateProductId(item.id.toString()),
      name: item.name,
      brand: item.brand?.name || 'Unknown',
      description: item.description || '',
      price: {
        current: this.normalizePrice(item.price?.current || 0),
        original: item.price?.regular ? this.normalizePrice(item.price.regular) : undefined,
        currency: 'USD'
      },
      images: {
        main: item.media?.images?.[0]?.src || '',
        gallery: item.media?.images?.map((img: any) => img.src) || [],
        thumbnail: item.media?.images?.[0]?.src
      },
      sizes: {
        available: item.skus?.map((sku: any) => sku.size).filter(Boolean) || [],
        sizeChart: item.sizeChart
      },
      colors: {
        available: colors,
        colorCodes: item.colorName ? { [item.colorName]: item.colorId } : {}
      },
      materials,
      category: {
        main: item.productCategory?.name || 'Fashion',
        sub: item.classification?.name || 'General',
        tags: item.webCategories || []
      },
      store: {
        name: 'Nordstrom',
        url: item.productPageUrl || `https://www.nordstrom.com/s/${item.id}`,
        productId: item.id.toString()
      },
      availability: {
        inStock: item.isAvailable || false,
        quantity: item.skus?.reduce((sum: number, sku: any) => sum + (sku.available ? 1 : 0), 0)
      },
      ratings: {
        average: item.rating?.average || 0,
        count: item.rating?.count || 0
      },
      sustainability: {
        certifications: item.sustainability?.certifications || [],
        score: item.sustainability?.score
      },
      metadata: {
        scrapedAt: new Date(),
        lastUpdated: new Date(),
        dataQuality: detailed ? 1.0 : 0.8,
        source: 'nordstrom-api'
      }
    };

    return product;
  }
}