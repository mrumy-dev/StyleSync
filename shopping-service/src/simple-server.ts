import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { UniversalStoreScraper } from './scrapers/UniversalStoreScraper';
import { AdvancedDataExtractor } from './extraction/AdvancedDataExtractor';
import { PriceIntelligenceEngine } from './intelligence/PriceIntelligenceEngine';
import { AnonymousShoppingService } from './privacy/AnonymousShoppingService';

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '10mb' }));

// Initialize services
const scraper = new UniversalStoreScraper();
const dataExtractor = new AdvancedDataExtractor();
const priceEngine = new PriceIntelligenceEngine();
const privacyService = new AnonymousShoppingService();

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    services: {
      scraper: 'active',
      dataExtractor: 'active',
      priceEngine: 'active',
      privacyService: 'active'
    }
  });
});

// Enhanced scraping endpoint
app.post('/api/scrape', async (req, res) => {
  try {
    const { url, useJavaScript = true, screenshot = false } = req.body;

    if (!url) {
      return res.status(400).json({ error: 'URL is required' });
    }

    const scrapedData = await scraper.scrape({
      url,
      useJavaScript,
      screenshot,
      waitTime: 2000,
      blockResources: ['image', 'stylesheet', 'font']
    });

    const extractedData = await dataExtractor.extractProduct(scrapedData.html, url);

    res.json({
      success: true,
      data: {
        scraped: scrapedData,
        extracted: extractedData
      }
    });

  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Scraping failed'
    });
  }
});

// Price intelligence endpoint
app.post('/api/price-analysis', async (req, res) => {
  try {
    const { product, competitors = [], history = [] } = req.body;

    if (!product) {
      return res.status(400).json({ error: 'Product data is required' });
    }

    const [dealScore, competitorAnalysis] = await Promise.all([
      priceEngine.calculateDealScore(product, history, competitors),
      competitors.length > 0
        ? priceEngine.analyzeCompetitors(product.id, competitors)
        : Promise.resolve(null)
    ]);

    res.json({
      success: true,
      data: {
        dealScore,
        competitorAnalysis
      }
    });

  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Price analysis failed'
    });
  }
});

// Anonymous shopping endpoint
app.post('/api/anonymous-session', async (req, res) => {
  try {
    const { preferences, options } = req.body;

    const session = await privacyService.createAnonymousSession(
      preferences || {
        allowTracking: false,
        allowPersonalization: false,
        allowEmailMarketing: false,
        allowRetargeting: false,
        shareDataWithPartners: false,
        useRealIdentity: false
      },
      options
    );

    res.json({
      success: true,
      data: session
    });

  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Session creation failed'
    });
  }
});

// Privacy metrics endpoint
app.get('/api/privacy-metrics/:sessionId', async (req, res) => {
  try {
    const { sessionId } = req.params;
    const metrics = await privacyService.trackPrivacyMetrics(sessionId);

    res.json({
      success: true,
      data: metrics
    });

  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Metrics tracking failed'
    });
  }
});

// Secure checkout endpoint
app.post('/api/secure-checkout', async (req, res) => {
  try {
    const { sessionId, orderDetails, options } = req.body;

    const checkout = await privacyService.createSecureCheckout(
      sessionId,
      orderDetails,
      options
    );

    res.json({
      success: true,
      data: checkout
    });

  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Secure checkout failed'
    });
  }
});

// Universal search endpoint with multiple stores
app.post('/api/universal-search', async (req, res) => {
  try {
    const { query, stores = [], options = {} } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'Search query is required' });
    }

    // Default stores if none specified
    const defaultStores = [
      'https://www.zara.com',
      'https://www.asos.com',
      'https://www.h&m.com'
    ];

    const searchUrls = stores.length > 0 ? stores : defaultStores;

    // Perform parallel scraping
    const searchConfigs = searchUrls.map(store => ({
      url: `${store}/search?q=${encodeURIComponent(query)}`,
      useJavaScript: true,
      waitTime: 3000,
      blockResources: ['image', 'font']
    }));

    const results = await scraper.scrapeMultiple(searchConfigs);

    // Extract product data from results
    const extractedResults = await Promise.all(
      results.map(async (result, index) => {
        try {
          const extracted = await dataExtractor.extractProduct(result.html, searchUrls[index]);
          return {
            store: searchUrls[index],
            ...extracted
          };
        } catch (error) {
          return {
            store: searchUrls[index],
            error: 'Extraction failed'
          };
        }
      })
    );

    res.json({
      success: true,
      data: {
        query,
        results: extractedResults,
        totalStores: searchUrls.length
      }
    });

  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message || 'Universal search failed'
    });
  }
});

// Start server
app.listen(port, () => {
  console.log(`🚀 StyleSync Enhanced Shopping Service running on port ${port}`);
  console.log(`📊 Health check: http://localhost:${port}/health`);
  console.log(`🔍 Universal scraper: POST http://localhost:${port}/api/scrape`);
  console.log(`💰 Price intelligence: POST http://localhost:${port}/api/price-analysis`);
  console.log(`🔒 Anonymous shopping: POST http://localhost:${port}/api/anonymous-session`);
  console.log(`🔍 Universal search: POST http://localhost:${port}/api/universal-search`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🔄 Shutting down gracefully...');
  await scraper.shutdown();
  process.exit(0);
});

export default app;