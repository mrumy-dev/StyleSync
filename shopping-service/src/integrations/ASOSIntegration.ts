import axios from 'axios';
import { BaseStoreIntegration, StoreConfig, SearchFilters, ProductSearchResult } from './BaseStoreIntegration';
import { IProduct } from '../models/Product';

export class ASOSIntegration extends BaseStoreIntegration {
  constructor() {
    const config: StoreConfig = {
      name: 'ASOS',
      baseUrl: 'https://api.asos.com',
      rateLimits: {
        requestsPerMinute: 120,
        requestsPerHour: 2000
      },
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'StyleSync-Shopping-Service/1.0',
        'ASOS-C': 'usd', // Currency
        'ASOS-L': 'en-US' // Language
      },
      endpoints: {
        products: '/v4/products/search',
        product: '/v4/products/{id}',
        categories: '/v4/categories'
      }
    };
    super(config);
  }

  async searchProducts(filters: SearchFilters): Promise<ProductSearchResult> {
    return this.rateLimitedRequest(async () => {
      const params = new URLSearchParams();
      
      if (filters.query) params.append('q', filters.query);
      if (filters.category) params.append('categoryId', filters.category);
      if (filters.brand) params.append('brand', filters.brand);
      if (filters.priceMin) params.append('priceLow', filters.priceMin.toString());
      if (filters.priceMax) params.append('priceHigh', filters.priceMax.toString());
      if (filters.colors?.length) params.append('attribute_1047', filters.colors.join('|'));
      if (filters.sizes?.length) params.append('attribute_1047', filters.sizes.join('|'));
      if (filters.limit) params.append('limit', filters.limit.toString());
      if (filters.offset) params.append('offset', filters.offset.toString());
      if (filters.inStock) params.append('store', 'COM');

      const response = await axios.get(`${this.config.baseUrl}${this.config.endpoints.products}`, {
        params,
        headers: this.config.headers
      });

      const products = response.data.products.map((item: any) => this.transformASOSProduct(item));
      
      return {
        products,
        totalCount: response.data.itemCount || 0,
        hasMore: response.data.itemCount > (filters.offset || 0) + products.length,
        filters: {
          categories: response.data.facets?.category?.facetValues?.map((f: any) => f.name) || [],
          brands: response.data.facets?.brand?.facetValues?.map((f: any) => f.name) || [],
          priceRange: {
            min: response.data.facets?.price?.range?.min || 0,
            max: response.data.facets?.price?.range?.max || 1000
          },
          colors: response.data.facets?.colour?.facetValues?.map((f: any) => f.name) || [],
          sizes: response.data.facets?.size?.facetValues?.map((f: any) => f.name) || []
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
        
        return this.transformASOSProduct(response.data, true);
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
      
      return response.data.navigation.map((cat: any) => cat.alias);
    });
  }

  async getBrands(): Promise<string[]> {
    return this.rateLimitedRequest(async () => {
      const response = await axios.get(`${this.config.baseUrl}/v4/brands`, {
        headers: this.config.headers
      });
      
      return response.data.brands.map((brand: any) => brand.name);
    });
  }

  private transformASOSProduct(item: any, detailed: boolean = false): Partial<IProduct> {
    const colors = this.extractColors(item.name + ' ' + (item.colour || ''));
    const materials = this.extractMaterials(item.description || '');

    const product: Partial<IProduct> = {
      id: this.generateProductId(item.id.toString()),
      name: item.name,
      brand: item.brandName || 'ASOS',
      description: item.description || '',
      price: {
        current: this.normalizePrice(item.price?.current?.value || 0),
        original: item.price?.previous ? this.normalizePrice(item.price.previous.value) : undefined,
        currency: item.price?.currency || 'USD'
      },
      images: {
        main: item.imageUrl || '',
        gallery: item.additionalImageUrls || [],
        thumbnail: item.imageUrl
      },
      sizes: {
        available: item.variants?.map((v: any) => v.size) || [],
        sizeChart: item.sizeGuide
      },
      colors: {
        available: colors,
        colorCodes: item.colour ? { [item.colour]: item.colourWayId } : {}
      },
      materials,
      category: {
        main: item.productType?.name || 'Fashion',
        sub: item.gender || 'Unisex',
        tags: item.webCategories?.map((cat: any) => cat.name) || []
      },
      store: {
        name: 'ASOS',
        url: item.url || `https://www.asos.com/prd/${item.id}`,
        productId: item.id.toString()
      },
      availability: {
        inStock: item.isInStock || false,
        quantity: item.variants?.reduce((sum: number, variant: any) => sum + (variant.isInStock ? 1 : 0), 0)
      },
      ratings: {
        average: item.rating || 0,
        count: item.reviewCount || 0
      },
      sustainability: {
        certifications: item.eco ? ['Eco-Edit'] : [],
        score: item.ecoScore
      },
      metadata: {
        scrapedAt: new Date(),
        lastUpdated: new Date(),
        dataQuality: detailed ? 1.0 : 0.8,
        source: 'asos-api'
      }
    };

    return product;
  }
}