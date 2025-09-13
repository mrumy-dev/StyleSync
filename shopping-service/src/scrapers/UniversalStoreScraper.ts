import puppeteer, { Browser, Page, PuppeteerLaunchOptions } from 'puppeteer';
import { chromium } from 'playwright';
import axios from 'axios';
import * as cheerio from 'cheerio';
import { logger } from '../middleware/ErrorHandler';

export interface ScrapingConfig {
  url: string;
  useJavaScript?: boolean;
  waitForSelector?: string;
  waitTime?: number;
  screenshot?: boolean;
  cookies?: Array<{name: string, value: string, domain?: string}>;
  headers?: Record<string, string>;
  proxyConfig?: {
    server: string;
    username?: string;
    password?: string;
  };
  userAgent?: string;
  viewport?: {
    width: number;
    height: number;
  };
  blockResources?: string[];
  captchaSolver?: boolean;
}

export interface ScrapedData {
  html: string;
  screenshot?: Buffer;
  status: number;
  finalUrl: string;
  cookies: Array<{name: string, value: string, domain: string}>;
  performance: {
    loadTime: number;
    domContentLoaded: number;
    networkIdle: number;
  };
}

export class UniversalStoreScraper {
  private browser: Browser | null = null;
  private userAgents: string[] = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15'
  ];

  private proxies: string[] = [];
  private currentProxyIndex = 0;
  private rateLimitDelay = 1000;
  private maxRetries = 3;

  constructor() {
    this.loadProxyList();
  }

  private loadProxyList(): void {
    // In production, load from environment or config
    this.proxies = [
      'http://proxy1.example.com:8080',
      'http://proxy2.example.com:8080',
      'http://proxy3.example.com:8080'
    ];
  }

  private getRandomUserAgent(): string {
    return this.userAgents[Math.floor(Math.random() * this.userAgents.length)];
  }

  private getNextProxy(): string | null {
    if (this.proxies.length === 0) return null;

    const proxy = this.proxies[this.currentProxyIndex];
    this.currentProxyIndex = (this.currentProxyIndex + 1) % this.proxies.length;
    return proxy;
  }

  private async initBrowser(config: ScrapingConfig): Promise<Browser> {
    const launchOptions: PuppeteerLaunchOptions = {
      headless: 'new',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--no-first-run',
        '--disable-default-apps',
        '--disable-background-timer-throttling',
        '--disable-renderer-backgrounding',
        '--disable-backgrounding-occluded-windows',
        '--disable-features=TranslateUI',
        '--disable-ipc-flooding-protection',
        '--window-size=1920,1080'
      ]
    };

    // Add proxy if configured
    if (config.proxyConfig) {
      launchOptions.args?.push(`--proxy-server=${config.proxyConfig.server}`);
    } else {
      // Use rotating proxy
      const proxy = this.getNextProxy();
      if (proxy) {
        launchOptions.args?.push(`--proxy-server=${proxy}`);
      }
    }

    return await puppeteer.launch(launchOptions);
  }

  private async setupPage(page: Page, config: ScrapingConfig): Promise<void> {
    // Set user agent
    const userAgent = config.userAgent || this.getRandomUserAgent();
    await page.setUserAgent(userAgent);

    // Set viewport
    const viewport = config.viewport || { width: 1920, height: 1080 };
    await page.setViewport(viewport);

    // Set cookies
    if (config.cookies && config.cookies.length > 0) {
      await page.setCookie(...config.cookies.map(cookie => ({
        ...cookie,
        domain: cookie.domain || new URL(config.url).hostname
      })));
    }

    // Set extra headers
    if (config.headers) {
      await page.setExtraHTTPHeaders(config.headers);
    }

    // Block resources to speed up loading
    if (config.blockResources && config.blockResources.length > 0) {
      await page.setRequestInterception(true);
      page.on('request', (request) => {
        const resourceType = request.resourceType();
        if (config.blockResources!.includes(resourceType)) {
          request.abort();
        } else {
          request.continue();
        }
      });
    }

    // Handle dialogs
    page.on('dialog', async (dialog) => {
      await dialog.dismiss();
    });

    // Enhanced stealth techniques
    await page.evaluateOnNewDocument(() => {
      // Override webdriver property
      Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined,
      });

      // Override plugins
      Object.defineProperty(navigator, 'plugins', {
        get: () => [1, 2, 3, 4, 5],
      });

      // Override languages
      Object.defineProperty(navigator, 'languages', {
        get: () => ['en-US', 'en'],
      });

      // Override chrome property
      (window as any).chrome = {
        runtime: {},
      };

      // Override permissions
      const originalQuery = window.navigator.permissions.query;
      window.navigator.permissions.query = (parameters) => (
        parameters.name === 'notifications' ?
          Promise.resolve({ state: Notification.permission }) :
          originalQuery(parameters)
      );
    });
  }

  private async solveCaptcha(page: Page): Promise<boolean> {
    try {
      // Check for common CAPTCHA indicators
      const captchaSelectors = [
        '.g-recaptcha',
        '#captcha',
        '.captcha',
        '[data-sitekey]',
        '.cf-browser-verification',
        '#challenge-form'
      ];

      let captchaFound = false;
      for (const selector of captchaSelectors) {
        const element = await page.$(selector);
        if (element) {
          captchaFound = true;
          logger.warn(`CAPTCHA detected: ${selector}`);
          break;
        }
      }

      if (!captchaFound) return true;

      // Wait for human intervention or automatic solving
      // In production, integrate with CAPTCHA solving services
      logger.warn('CAPTCHA detected - waiting for resolution');

      // Wait up to 30 seconds for CAPTCHA resolution
      try {
        await page.waitForFunction(() => {
          return !document.querySelector('.g-recaptcha, #captcha, .captcha, [data-sitekey], .cf-browser-verification, #challenge-form');
        }, { timeout: 30000 });

        return true;
      } catch (error) {
        logger.error('CAPTCHA resolution timeout');
        return false;
      }

    } catch (error) {
      logger.error('CAPTCHA solving error:', error);
      return false;
    }
  }

  private async handleCloudflare(page: Page): Promise<boolean> {
    try {
      // Check for Cloudflare challenge
      const cfChallenge = await page.$('.cf-browser-verification, .cf-checking-browser, #challenge-form');

      if (cfChallenge) {
        logger.info('Cloudflare challenge detected - waiting for resolution');

        // Wait for challenge to complete
        await page.waitForFunction(() => {
          return !document.querySelector('.cf-browser-verification, .cf-checking-browser, #challenge-form');
        }, { timeout: 15000 });

        return true;
      }

      return true;
    } catch (error) {
      logger.error('Cloudflare handling error:', error);
      return false;
    }
  }

  async scrape(config: ScrapingConfig): Promise<ScrapedData> {
    let page: Page | null = null;
    const startTime = Date.now();

    try {
      // Rate limiting
      await new Promise(resolve => setTimeout(resolve, this.rateLimitDelay));

      if (config.useJavaScript !== false) {
        // Use Puppeteer for JavaScript rendering
        if (!this.browser) {
          this.browser = await this.initBrowser(config);
        }

        page = await this.browser.newPage();
        await this.setupPage(page, config);

        // Navigate with retry logic
        let response = null;
        for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
          try {
            response = await page.goto(config.url, {
              waitUntil: 'domcontentloaded',
              timeout: 30000
            });
            break;
          } catch (error) {
            if (attempt === this.maxRetries) throw error;
            logger.warn(`Navigation attempt ${attempt} failed, retrying...`);
            await new Promise(resolve => setTimeout(resolve, 2000 * attempt));
          }
        }

        if (!response) {
          throw new Error('Failed to navigate to page');
        }

        // Handle Cloudflare
        await this.handleCloudflare(page);

        // Handle CAPTCHA if enabled
        if (config.captchaSolver) {
          const captchaSolved = await this.solveCaptcha(page);
          if (!captchaSolved) {
            throw new Error('CAPTCHA resolution failed');
          }
        }

        // Wait for specific selector if provided
        if (config.waitForSelector) {
          try {
            await page.waitForSelector(config.waitForSelector, { timeout: 10000 });
          } catch (error) {
            logger.warn(`Wait for selector failed: ${config.waitForSelector}`);
          }
        }

        // Additional wait time
        if (config.waitTime) {
          await page.waitForTimeout(config.waitTime);
        }

        // Wait for network idle
        await page.waitForLoadState?.('networkidle') ||
              page.waitForFunction(() => document.readyState === 'complete');

        const html = await page.content();
        const finalUrl = page.url();
        const cookies = await page.cookies();

        let screenshot: Buffer | undefined;
        if (config.screenshot) {
          screenshot = await page.screenshot({
            fullPage: true,
            type: 'png'
          });
        }

        const loadTime = Date.now() - startTime;

        return {
          html,
          screenshot,
          status: response.status(),
          finalUrl,
          cookies: cookies.map(c => ({
            name: c.name,
            value: c.value,
            domain: c.domain
          })),
          performance: {
            loadTime,
            domContentLoaded: loadTime,
            networkIdle: loadTime
          }
        };

      } else {
        // Simple HTTP request for static content
        const headers = {
          'User-Agent': config.userAgent || this.getRandomUserAgent(),
          ...config.headers
        };

        const response = await axios.get(config.url, {
          headers,
          timeout: 30000,
          maxRedirects: 5
        });

        const loadTime = Date.now() - startTime;

        return {
          html: response.data,
          status: response.status,
          finalUrl: response.request.responseURL || config.url,
          cookies: [],
          performance: {
            loadTime,
            domContentLoaded: loadTime,
            networkIdle: loadTime
          }
        };
      }

    } catch (error) {
      logger.error('Scraping failed:', error);
      throw error;
    } finally {
      if (page) {
        await page.close();
      }
    }
  }

  async scrapeMultiple(configs: ScrapingConfig[]): Promise<ScrapedData[]> {
    const results: ScrapedData[] = [];

    for (const config of configs) {
      try {
        const result = await this.scrape(config);
        results.push(result);

        // Add delay between requests
        await new Promise(resolve => setTimeout(resolve, this.rateLimitDelay));
      } catch (error) {
        logger.error(`Failed to scrape ${config.url}:`, error);
        // Continue with other URLs
      }
    }

    return results;
  }

  async extractStructuredData(html: string): Promise<any> {
    const $ = cheerio.load(html);
    const structuredData: any = {};

    // Extract JSON-LD structured data
    $('script[type="application/ld+json"]').each((_, element) => {
      try {
        const jsonLd = JSON.parse($(element).html() || '');
        if (!structuredData.jsonLd) structuredData.jsonLd = [];
        structuredData.jsonLd.push(jsonLd);
      } catch (error) {
        // Ignore malformed JSON-LD
      }
    });

    // Extract Open Graph data
    const openGraph: Record<string, string> = {};
    $('meta[property^="og:"]').each((_, element) => {
      const property = $(element).attr('property');
      const content = $(element).attr('content');
      if (property && content) {
        openGraph[property] = content;
      }
    });
    if (Object.keys(openGraph).length > 0) {
      structuredData.openGraph = openGraph;
    }

    // Extract Twitter Card data
    const twitterCard: Record<string, string> = {};
    $('meta[name^="twitter:"]').each((_, element) => {
      const name = $(element).attr('name');
      const content = $(element).attr('content');
      if (name && content) {
        twitterCard[name] = content;
      }
    });
    if (Object.keys(twitterCard).length > 0) {
      structuredData.twitterCard = twitterCard;
    }

    return structuredData;
  }

  setRateLimit(delay: number): void {
    this.rateLimitDelay = delay;
  }

  setMaxRetries(retries: number): void {
    this.maxRetries = retries;
  }

  async shutdown(): Promise<void> {
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
    }
  }
}