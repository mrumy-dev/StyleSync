import { BaseScraper, ScrapingConfig, ScrapingOptions } from './BaseScraper';
import { IProduct } from '../models/Product';
import { Page } from 'puppeteer';
import { Page as PlaywrightPage } from 'playwright';

export class SHEINScraper extends BaseScraper {
  constructor() {
    const config: ScrapingConfig = {
      store: 'SHEIN',
      baseUrl: 'https://us.shein.com',
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      rateLimits: {
        requestsPerMinute: 30,
        delayBetweenRequests: 2000
      },
      selectors: {
        productList: '.goods-list-v2',
        productItem: '.product-list-item',
        productName: '.goods-title-link',
        productPrice: '.price-sale',
        productImage: '.crop-image-container img',
        productLink: '.goods-title-link'
      },
      detailSelectors: {
        name: 'h1.product-intro__head-name',
        price: '.price-sale',
        originalPrice: '.price-del',
        description: '.product-intro__description-table',
        images: '.product-intro__main-image img',
        sizes: '.size-list .size-list__item',
        colors: '.color-list .color-list__item',
        availability: '.stock-text',
        materials: '.product-intro__description-table tr:contains("Material")',
        reviews: '.rate-review'
      },
      navigation: {
        searchUrl: '/search',
        categoryUrls: {
          'women': '/women',
          'men': '/men',
          'kids': '/kids',
          'home': '/home',
          'curve': '/curve'
        }
      }
    };
    super(config);
  }

  async searchProducts(query: string, options: ScrapingOptions = {}): Promise<Partial<IProduct>[]> {
    return this.rateLimitedRequest(async () => {
      const page = await this.createPage(options);
      const products: Partial<IProduct>[] = [];

      try {
        const searchUrl = `${this.config.baseUrl}${this.config.navigation.searchUrl}?q=${encodeURIComponent(query)}`;
        await page.goto(searchUrl, { waitUntil: 'networkidle2' });

        // Handle potential captcha
        await this.handleCaptcha(page);

        // Wait for products to load
        await page.waitForSelector(this.config.selectors.productList, { timeout: 10000 });

        // Scroll to load more products
        for (let i = 0; i < 3; i++) {
          await this.safeScroll(page);
          await page.waitForTimeout(2000);
        }

        // Extract product information
        const productElements = await page.$$(this.config.selectors.productItem);

        for (const element of productElements.slice(0, 50)) { // Limit to 50 products
          try {
            const productData = await element.evaluate((el, selectors) => {
              const nameEl = el.querySelector(selectors.productName);
              const priceEl = el.querySelector(selectors.productPrice);
              const imageEl = el.querySelector(selectors.productImage);
              const linkEl = el.querySelector(selectors.productLink);

              return {
                name: nameEl?.textContent?.trim() || '',
                price: priceEl?.textContent?.trim() || '0',
                image: imageEl?.getAttribute('src') || imageEl?.getAttribute('data-src') || '',
                link: linkEl?.getAttribute('href') || ''
              };
            }, this.config.selectors);

            if (productData.name && productData.price) {
              const product: Partial<IProduct> = {
                id: this.generateProductId(this.extractProductIdFromUrl(productData.link)),
                name: productData.name,
                brand: 'SHEIN',
                description: '',
                price: {
                  current: this.extractPrice(productData.price),
                  currency: 'USD'
                },
                images: {
                  main: productData.image.startsWith('//') ? `https:${productData.image}` : productData.image,
                  gallery: [],
                  thumbnail: productData.image
                },
                category: {
                  main: 'Fashion',
                  sub: 'Women',
                  tags: []
                },
                store: {
                  name: 'SHEIN',
                  url: productData.link.startsWith('http') ? productData.link : `${this.config.baseUrl}${productData.link}`,
                  productId: this.extractProductIdFromUrl(productData.link)
                },
                availability: {
                  inStock: true
                },
                metadata: {
                  scrapedAt: new Date(),
                  lastUpdated: new Date(),
                  dataQuality: 0.7,
                  source: 'shein-scraper'
                }
              };

              products.push(product);
            }
          } catch (error) {
            console.warn('Error extracting product:', error);
          }
        }

        if (options.screenshots) {
          await this.takeScreenshot(page, `shein-search-${Date.now()}.png`);
        }

      } finally {
        await page.close();
      }

      return products;
    });
  }

  async scrapeProduct(url: string, options: ScrapingOptions = {}): Promise<IProduct | null> {
    return this.rateLimitedRequest(async () => {
      const page = await this.createPage(options);

      try {
        await page.goto(url, { waitUntil: 'networkidle2' });

        // Handle potential captcha
        await this.handleCaptcha(page);

        // Wait for product details to load
        await page.waitForSelector(this.config.detailSelectors.name, { timeout: 10000 });

        const productData = await page.evaluate((selectors) => {
          const getValue = (selector: string) => {
            const el = document.querySelector(selector);
            return el?.textContent?.trim() || '';
          };

          const getImageSrcs = (selector: string) => {
            const images = Array.from(document.querySelectorAll(selector));
            return images.map(img => img.getAttribute('src') || img.getAttribute('data-src') || '').filter(Boolean);
          };

          const getListItems = (selector: string) => {
            const items = Array.from(document.querySelectorAll(selector));
            return items.map(item => item.textContent?.trim() || '').filter(Boolean);
          };

          return {
            name: getValue(selectors.name),
            price: getValue(selectors.price),
            originalPrice: getValue(selectors.originalPrice),
            description: getValue(selectors.description),
            images: getImageSrcs(selectors.images),
            sizes: getListItems(selectors.sizes),
            colors: getListItems(selectors.colors),
            availability: getValue(selectors.availability),
            materials: getValue(selectors.materials)
          };
        }, this.config.detailSelectors);

        if (!productData.name) {
          return null;
        }

        const colors = this.extractColors(productData.name + ' ' + productData.colors.join(' '));
        const materials = this.extractMaterials(productData.description + ' ' + productData.materials);
        const productId = this.extractProductIdFromUrl(url);

        const product: IProduct = {
          id: this.generateProductId(productId),
          name: productData.name,
          brand: 'SHEIN',
          description: productData.description,
          price: {
            current: this.extractPrice(productData.price),
            original: productData.originalPrice ? this.extractPrice(productData.originalPrice) : undefined,
            currency: 'USD'
          },
          images: {
            main: productData.images[0] || '',
            gallery: productData.images,
            thumbnail: productData.images[0]
          },
          sizes: {
            available: productData.sizes,
            sizeChart: undefined
          },
          colors: {
            available: colors,
            colorCodes: {}
          },
          materials,
          category: {
            main: 'Fashion',
            sub: 'Women',
            tags: []
          },
          store: {
            name: 'SHEIN',
            url: url,
            productId: productId
          },
          availability: {
            inStock: !productData.availability.toLowerCase().includes('out of stock'),
            quantity: undefined
          },
          ratings: {
            average: 0,
            count: 0
          },
          sustainability: {
            certifications: [],
            score: 2 // SHEIN typically has lower sustainability scores
          },
          metadata: {
            scrapedAt: new Date(),
            lastUpdated: new Date(),
            dataQuality: 0.9,
            source: 'shein-scraper'
          }
        } as IProduct;

        if (options.screenshots) {
          await this.takeScreenshot(page, `shein-product-${productId}-${Date.now()}.png`);
        }

        return product;

      } finally {
        await page.close();
      }
    });
  }

  async getCategories(options: ScrapingOptions = {}): Promise<string[]> {
    return this.rateLimitedRequest(async () => {
      const page = await this.createPage(options);

      try {
        await page.goto(this.config.baseUrl, { waitUntil: 'networkidle2' });

        const categories = await page.evaluate(() => {
          const categoryElements = Array.from(document.querySelectorAll('.nav-item a, .category-link'));
          return categoryElements
            .map(el => el.textContent?.trim())
            .filter(Boolean)
            .slice(0, 20); // Limit to 20 categories
        });

        return categories as string[];

      } finally {
        await page.close();
      }
    });
  }

  private extractProductIdFromUrl(url: string): string {
    const match = url.match(/\/([^\/]+)-p-(\d+)/);
    return match ? match[2] : url.split('/').pop() || '';
  }
}