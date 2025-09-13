import { Browser, Page } from 'puppeteer';
import { Browser as PlaywrightBrowser, Page as PlaywrightPage } from 'playwright';
import { IProduct } from '../models/Product';

export interface ScrapingConfig {
  store: string;
  baseUrl: string;
  userAgent: string;
  rateLimits: {
    requestsPerMinute: number;
    delayBetweenRequests: number;
  };
  selectors: {
    productList: string;
    productItem: string;
    productName: string;
    productPrice: string;
    productImage: string;
    productLink: string;
    nextButton?: string;
    loadMoreButton?: string;
  };
  detailSelectors: {
    name: string;
    price: string;
    originalPrice?: string;
    description: string;
    images: string;
    sizes: string;
    colors: string;
    availability: string;
    brand?: string;
    materials?: string;
    reviews?: string;
  };
  navigation: {
    searchUrl: string;
    categoryUrls: Record<string, string>;
  };
}

export interface ScrapingOptions {
  headless?: boolean;
  timeout?: number;
  maxRetries?: number;
  proxy?: string;
  screenshots?: boolean;
  usePlaywright?: boolean;
}

export abstract class BaseScraper {
  protected config: ScrapingConfig;
  protected browser: Browser | PlaywrightBrowser | null = null;
  protected lastRequestTime: number = 0;

  constructor(config: ScrapingConfig) {
    this.config = config;
  }

  abstract searchProducts(query: string, options?: ScrapingOptions): Promise<Partial<IProduct>[]>;
  abstract scrapeProduct(url: string, options?: ScrapingOptions): Promise<IProduct | null>;
  abstract getCategories(options?: ScrapingOptions): Promise<string[]>;

  protected async initBrowser(options: ScrapingOptions = {}): Promise<Browser | PlaywrightBrowser> {
    if (this.browser) return this.browser;

    if (options.usePlaywright) {
      const { chromium } = await import('playwright');
      this.browser = await chromium.launch({
        headless: options.headless !== false,
        proxy: options.proxy ? { server: options.proxy } : undefined
      });
    } else {
      const puppeteer = await import('puppeteer');
      this.browser = await puppeteer.launch({
        headless: options.headless !== false,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--no-first-run',
          '--no-zygote',
          '--disable-gpu'
        ]
      });
    }

    return this.browser;
  }

  protected async createPage(options: ScrapingOptions = {}): Promise<Page | PlaywrightPage> {
    const browser = await this.initBrowser(options);
    const page = await browser.newPage();

    // Set user agent
    await page.setUserAgent(this.config.userAgent);

    // Set viewport
    await page.setViewportSize ? 
      await page.setViewportSize({ width: 1920, height: 1080 }) :
      await (page as Page).setViewport({ width: 1920, height: 1080 });

    // Block unnecessary resources for faster scraping
    if ('setRequestInterception' in page) {
      await page.setRequestInterception(true);
      page.on('request', (req) => {
        if (req.resourceType() === 'stylesheet' || req.resourceType() === 'font') {
          req.abort();
        } else {
          req.continue();
        }
      });
    }

    // Set timeout
    if (options.timeout) {
      page.setDefaultTimeout(options.timeout);
    }

    return page;
  }

  protected async rateLimitedRequest<T>(requestFn: () => Promise<T>): Promise<T> {
    const now = Date.now();
    const timeSinceLastRequest = now - this.lastRequestTime;
    const minInterval = this.config.rateLimits.delayBetweenRequests;

    if (timeSinceLastRequest < minInterval) {
      const waitTime = minInterval - timeSinceLastRequest;
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }

    this.lastRequestTime = Date.now();
    return requestFn();
  }

  protected async safeEvaluate<T>(
    page: Page | PlaywrightPage,
    fn: string | (() => T),
    selector?: string
  ): Promise<T | null> {
    try {
      if (selector) {
        await page.waitForSelector(selector, { timeout: 5000 });
      }
      
      if (typeof fn === 'string') {
        return await page.evaluate(fn) as T;
      } else {
        return await page.evaluate(fn) as T;
      }
    } catch (error) {
      console.warn('Safe evaluate failed:', error);
      return null;
    }
  }

  protected async safeClick(page: Page | PlaywrightPage, selector: string): Promise<boolean> {
    try {
      await page.waitForSelector(selector, { timeout: 5000 });
      await page.click(selector);
      return true;
    } catch (error) {
      console.warn('Safe click failed:', error);
      return false;
    }
  }

  protected async safeScroll(page: Page | PlaywrightPage, distance: number = 1000): Promise<void> {
    try {
      await page.evaluate((dist) => {
        window.scrollBy(0, dist);
      }, distance);
      await page.waitForTimeout(1000);
    } catch (error) {
      console.warn('Safe scroll failed:', error);
    }
  }

  protected extractPrice(priceText: string): number {
    const cleanPrice = priceText.replace(/[^\d.,]/g, '');
    const price = parseFloat(cleanPrice.replace(',', '.'));
    return isNaN(price) ? 0 : price;
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

  protected generateProductId(storeProductId: string): string {
    return `${this.config.store.toLowerCase()}_${storeProductId}`;
  }

  async close(): Promise<void> {
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
    }
  }

  protected async takeScreenshot(page: Page | PlaywrightPage, filename: string): Promise<void> {
    try {
      await page.screenshot({ path: `screenshots/${filename}`, fullPage: true });
    } catch (error) {
      console.warn('Screenshot failed:', error);
    }
  }

  protected async handleCaptcha(page: Page | PlaywrightPage): Promise<boolean> {
    // Check for common captcha indicators
    const captchaSelectors = [
      '[src*="captcha"]',
      '[class*="captcha"]',
      '[id*="captcha"]',
      '.g-recaptcha',
      '#cf-challenge-running'
    ];

    for (const selector of captchaSelectors) {
      try {
        const element = await page.$(selector);
        if (element) {
          console.warn('Captcha detected, waiting...');
          await page.waitForTimeout(10000); // Wait 10 seconds
          return true;
        }
      } catch (error) {
        // Continue checking other selectors
      }
    }

    return false;
  }
}