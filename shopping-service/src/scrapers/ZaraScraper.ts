import { BaseScraper, ScrapingConfig, ScrapingOptions } from './BaseScraper';
import { IProduct } from '../models/Product';
import { Page } from 'puppeteer';
import { Page as PlaywrightPage } from 'playwright';

export class ZaraScraper extends BaseScraper {
  constructor() {
    const config: ScrapingConfig = {
      store: 'Zara',
      baseUrl: 'https://www.zara.com',
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      rateLimits: {
        requestsPerMinute: 20,
        delayBetweenRequests: 3000
      },
      selectors: {
        productList: '.product-grid',
        productItem: '.product-item',
        productName: '.product-item-name-link',
        productPrice: '.price._product-price',
        productImage: '.product-item-image img',
        productLink: '.product-item-link'
      },
      detailSelectors: {
        name: 'h1.product-detail-info__header-name',
        price: '.price-current._product-price',
        originalPrice: '.price-old',
        description: '.product-detail-description__text',
        images: '.product-detail-images__item img',
        sizes: '.product-detail-size-selector__size',
        colors: '.product-detail-color-selector__item',
        availability: '.product-detail-availability',
        materials: '.product-detail-care-info'
      },
      navigation: {
        searchUrl: '/search',
        categoryUrls: {
          'woman': '/woman',
          'man': '/man',
          'kids': '/kids',
          'home': '/home',
          'beauty': '/beauty'
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
        const searchUrl = `${this.config.baseUrl}${this.config.navigation.searchUrl}?searchTerm=${encodeURIComponent(query)}`;
        await page.goto(searchUrl, { waitUntil: 'networkidle2' });

        // Handle cookie consent
        await this.handleCookieConsent(page);

        // Wait for products to load
        await page.waitForSelector(this.config.selectors.productList, { timeout: 10000 });

        // Scroll to load more products
        for (let i = 0; i < 3; i++) {
          await this.safeScroll(page);
          await page.waitForTimeout(2000);
        }

        // Extract product information
        const productElements = await page.$$(this.config.selectors.productItem);

        for (const element of productElements.slice(0, 40)) { // Limit to 40 products
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
                brand: 'Zara',
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
                  sub: 'Apparel',
                  tags: []
                },
                store: {
                  name: 'Zara',
                  url: productData.link.startsWith('http') ? productData.link : `${this.config.baseUrl}${productData.link}`,
                  productId: this.extractProductIdFromUrl(productData.link)
                },
                availability: {
                  inStock: true
                },
                sustainability: {
                  certifications: ['Join Life'], // Zara's sustainability program
                  score: 6
                },
                metadata: {
                  scrapedAt: new Date(),
                  lastUpdated: new Date(),
                  dataQuality: 0.8,
                  source: 'zara-scraper'
                }
              };

              products.push(product);
            }
          } catch (error) {
            console.warn('Error extracting product:', error);
          }
        }

        if (options.screenshots) {
          await this.takeScreenshot(page, `zara-search-${Date.now()}.png`);
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

        // Handle cookie consent
        await this.handleCookieConsent(page);

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
          brand: 'Zara',
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
            sub: 'Apparel',
            tags: []
          },
          store: {
            name: 'Zara',
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
            certifications: ['Join Life'],
            score: 6
          },
          metadata: {
            scrapedAt: new Date(),
            lastUpdated: new Date(),
            dataQuality: 0.9,
            source: 'zara-scraper'
          }
        } as IProduct;

        if (options.screenshots) {
          await this.takeScreenshot(page, `zara-product-${productId}-${Date.now()}.png`);
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

        // Handle cookie consent
        await this.handleCookieConsent(page);

        const categories = await page.evaluate(() => {
          const categoryElements = Array.from(document.querySelectorAll('.layout-header-nav__item a, .category-nav-item'));
          return categoryElements
            .map(el => el.textContent?.trim())
            .filter(Boolean)
            .slice(0, 15); // Limit to 15 categories
        });

        return categories as string[];

      } finally {
        await page.close();
      }
    });
  }

  private async handleCookieConsent(page: Page | PlaywrightPage): Promise<void> {
    try {
      // Common cookie consent selectors for Zara
      const cookieSelectors = [
        '[data-qa-action="accept-cookies"]',
        '.cookie-consent__accept',
        '#onetrust-accept-btn-handler',
        '[aria-label*="Accept"]'
      ];

      for (const selector of cookieSelectors) {
        const element = await page.$(selector);
        if (element) {
          await element.click();
          await page.waitForTimeout(1000);
          break;
        }
      }
    } catch (error) {
      // Cookie consent handling is optional
      console.warn('Cookie consent handling failed:', error);
    }
  }

  private extractProductIdFromUrl(url: string): string {
    const match = url.match(/\/([^\/]+)\.html\?.*p=(\d+)/);
    if (match) return match[2];
    
    const match2 = url.match(/\/p(\d+)/);
    if (match2) return match2[1];
    
    return url.split('/').pop()?.split('.')[0] || '';
  }
}