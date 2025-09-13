import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import mongoose from 'mongoose';
import { createServer } from 'http';
import WebSocket from 'ws';
import dotenv from 'dotenv';

// Import services and middleware
import { StoreIntegrationManager } from './integrations/StoreIntegrationManager';
import { ScrapingEngine } from './scrapers/ScrapingEngine';
import { StyleMatchingService } from './matching/StyleMatchingService';
import { PriceTrackingService } from './realtime/PriceTrackingService';
import { NotificationService } from './realtime/NotificationService';
import { PrivacyManager } from './privacy/PrivacyManager';
import { JobScheduler } from './background/JobScheduler';

// Import closet management services
import { ClosetDashboardController } from './ui/ClosetDashboard';
import { ItemManagementController } from './ui/ItemManagement';
import { ClosetOrganizationAI } from './ai/ClosetOrganizationAI';
import { DigitalTwinEngine } from './visualization/DigitalTwinEngine';
import { MaintenanceTracker } from './maintenance/MaintenanceTracker';
import { InventoryManager } from './inventory/InventoryManager';
import { SmartClosetFeatures } from './smart/SmartClosetFeatures';
import { SmartHomeIntegration } from './integrations/SmartHomeIntegration';

// Import routes
import closetRoutes from './routes/closetRoutes';
import itemRoutes from './routes/itemRoutes';
import smartRoutes from './routes/smartRoutes';
import {
  setupMiddleware,
  errorHandler,
  asyncHandler,
  createRateLimitMiddleware,
  AppError,
  NotFoundError,
  logger,
  serviceMonitor
} from './middleware/ErrorHandler';

// Load environment variables
dotenv.config();

class ShoppingServer {
  private app: express.Application;
  private server: any;
  private wsServer: WebSocket.Server;
  private storeManager: StoreIntegrationManager;
  private scrapingEngine: ScrapingEngine;
  private styleMatchingService: StyleMatchingService;
  private priceTrackingService: PriceTrackingService;
  private notificationService: NotificationService;
  private privacyManager: PrivacyManager;
  private jobScheduler: JobScheduler;

  // Closet management services
  private dashboardController: ClosetDashboardController;
  private itemController: ItemManagementController;
  private organizationAI: ClosetOrganizationAI;
  private digitalTwinEngine: DigitalTwinEngine;
  private maintenanceTracker: MaintenanceTracker;
  private inventoryManager: InventoryManager;
  private smartFeatures: SmartClosetFeatures;
  private smartHomeIntegration: SmartHomeIntegration;
  
  constructor() {
    this.app = express();
    this.initializeServices();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  private initializeServices(): void {
    // Original services
    this.storeManager = new StoreIntegrationManager();
    this.scrapingEngine = new ScrapingEngine();
    this.styleMatchingService = new StyleMatchingService();
    this.priceTrackingService = new PriceTrackingService();
    this.notificationService = new NotificationService();
    this.privacyManager = new PrivacyManager();
    this.jobScheduler = new JobScheduler();

    // Closet management services
    this.organizationAI = new ClosetOrganizationAI();
    this.digitalTwinEngine = new DigitalTwinEngine();
    this.maintenanceTracker = new MaintenanceTracker(this.notificationService);
    this.inventoryManager = new InventoryManager();
    this.smartFeatures = new SmartClosetFeatures();
    this.smartHomeIntegration = new SmartHomeIntegration();

    // Controllers
    this.dashboardController = new ClosetDashboardController(
      this.inventoryManager,
      this.maintenanceTracker,
      this.organizationAI
    );
    this.itemController = new ItemManagementController(
      this.inventoryManager,
      this.maintenanceTracker
    );

    // Set services on app for route access
    this.app.set('dashboardController', this.dashboardController);
    this.app.set('itemController', this.itemController);
    this.app.set('organizationAI', this.organizationAI);
    this.app.set('digitalTwinEngine', this.digitalTwinEngine);
    this.app.set('maintenanceTracker', this.maintenanceTracker);
    this.app.set('inventoryManager', this.inventoryManager);
    this.app.set('smartFeatures', this.smartFeatures);
    this.app.set('smartHomeIntegration', this.smartHomeIntegration);
  }

  private setupMiddleware(): void {
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
        },
      },
    }));

    // CORS configuration
    this.app.use(cors({
      origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
    }));

    // Body parsing and compression
    this.app.use(compression());
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // Custom middleware
    setupMiddleware(this.app);
  }

  private setupRoutes(): void {
    // Health check
    this.app.get('/health', (req, res) => {
      const health = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        services: serviceMonitor.getServiceHealth(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        version: process.env.APP_VERSION || '1.0.0'
      };
      
      res.json(health);
    });

    // API Routes
    this.setupSearchRoutes();
    this.setupProductRoutes();
    this.setupPriceTrackingRoutes();
    this.setupPrivacyRoutes();
    this.setupNotificationRoutes();
    this.setupAdminRoutes();

    // Closet management routes
    this.app.use('/api/closets', closetRoutes);
    this.app.use('/api/items', itemRoutes);
    this.app.use('/api/smart', smartRoutes);

    // 404 handler
    this.app.all('*', (req, res, next) => {
      next(new NotFoundError(`Can't find ${req.originalUrl} on this server`));
    });
  }

  private setupSearchRoutes(): void {
    const router = express.Router();

    // Search products across all stores
    router.post('/search', 
      createRateLimitMiddleware('search'),
      asyncHandler(async (req, res) => {
        const { query, filters, stores } = req.body;
        
        const results = await this.storeManager.searchAllStores({
          query,
          category: filters?.category,
          brand: filters?.brand,
          priceMin: filters?.priceMin,
          priceMax: filters?.priceMax,
          colors: filters?.colors,
          sizes: filters?.sizes,
          inStock: filters?.inStockOnly,
          limit: filters?.limit || 20,
          offset: filters?.offset || 0
        });

        res.json({
          status: 'success',
          data: results.aggregated,
          stores: Object.fromEntries(results.results),
          errors: Object.fromEntries(results.errors)
        });
      })
    );

    // Visual search
    router.post('/search/visual',
      createRateLimitMiddleware('visual'),
      asyncHandler(async (req, res) => {
        const { imageUrl, limit = 20 } = req.body;
        
        // This would integrate with visual search
        // For now, return mock response
        res.json({
          status: 'success',
          data: {
            products: [],
            confidence: 0.85,
            visualFeatures: {
              dominantColors: ['#FF6B6B', '#4ECDC4'],
              style: 'casual',
              category: 'dress'
            }
          }
        });
      })
    );

    // Get categories from all stores
    router.get('/categories',
      asyncHandler(async (req, res) => {
        const categories = await this.storeManager.getAllCategories();
        
        res.json({
          status: 'success',
          data: Object.fromEntries(categories)
        });
      })
    );

    // Get brands from all stores
    router.get('/brands',
      asyncHandler(async (req, res) => {
        const brands = await this.storeManager.getAllBrands();
        
        res.json({
          status: 'success',
          data: Object.fromEntries(brands)
        });
      })
    );

    this.app.use('/api/search', router);
  }

  private setupProductRoutes(): void {
    const router = express.Router();

    // Get product details
    router.get('/:productId',
      asyncHandler(async (req, res) => {
        const { productId } = req.params;
        const [storeName, storeProductId] = productId.split('_');
        
        const product = await this.storeManager.getProductFromStore(storeName, storeProductId);
        
        if (!product) {
          throw new NotFoundError('Product not found');
        }

        res.json({
          status: 'success',
          data: product
        });
      })
    );

    // Find similar products
    router.post('/:productId/similar',
      asyncHandler(async (req, res) => {
        const { productId } = req.params;
        const { limit = 20, options } = req.body;
        
        // Get the product first
        const [storeName, storeProductId] = productId.split('_');
        const targetProduct = await this.storeManager.getProductFromStore(storeName, storeProductId);
        
        if (!targetProduct) {
          throw new NotFoundError('Target product not found');
        }

        // Get candidates from other stores
        const allResults = await this.storeManager.searchAllStores({
          query: targetProduct.name,
          category: targetProduct.category.main,
          limit: 100
        });

        const candidates = allResults.aggregated.products.filter(p => p.id !== productId);
        
        const similarProducts = await this.styleMatchingService.findStyleMatches(
          targetProduct,
          candidates,
          options
        );

        res.json({
          status: 'success',
          data: similarProducts.slice(0, limit)
        });
      })
    );

    this.app.use('/api/products', router);
  }

  private setupPriceTrackingRoutes(): void {
    const router = express.Router();

    // Create price alert
    router.post('/alerts',
      createRateLimitMiddleware('alerts'),
      asyncHandler(async (req, res) => {
        const { productId, triggerPrice, condition, threshold, userId } = req.body;
        
        const alertId = await this.priceTrackingService.addPriceAlert({
          productId,
          userId,
          triggerPrice,
          condition,
          threshold,
          isActive: true
        });

        res.status(201).json({
          status: 'success',
          data: { alertId }
        });
      })
    );

    // Get price history
    router.get('/:productId/history',
      asyncHandler(async (req, res) => {
        const { productId } = req.params;
        const { days = 30 } = req.query;
        
        const history = await this.priceTrackingService.getPriceHistory(
          productId,
          Number(days)
        );

        res.json({
          status: 'success',
          data: history
        });
      })
    );

    // Get price analytics
    router.get('/:productId/analytics',
      asyncHandler(async (req, res) => {
        const { productId } = req.params;
        
        const analytics = await this.priceTrackingService.getPriceAnalytics(productId);

        res.json({
          status: 'success',
          data: analytics
        });
      })
    );

    this.app.use('/api/price-tracking', router);
  }

  private setupPrivacyRoutes(): void {
    const router = express.Router();

    // Create anonymous session
    router.post('/anonymous-session',
      asyncHandler(async (req, res) => {
        const { preferences } = req.body;
        
        const sessionId = await this.privacyManager.createAnonymousSession(preferences);

        res.status(201).json({
          status: 'success',
          data: { sessionId }
        });
      })
    );

    // Get privacy settings
    router.get('/settings/:userId',
      asyncHandler(async (req, res) => {
        const { userId } = req.params;
        
        const settings = await this.privacyManager.getPrivacySettings(userId);

        res.json({
          status: 'success',
          data: settings
        });
      })
    );

    // Update privacy settings
    router.put('/settings/:userId',
      asyncHandler(async (req, res) => {
        const { userId } = req.params;
        const settings = req.body;
        
        await this.privacyManager.setPrivacySettings(userId, settings);

        res.json({
          status: 'success',
          message: 'Privacy settings updated'
        });
      })
    );

    // Request data export
    router.post('/export/:userId',
      asyncHandler(async (req, res) => {
        const { userId } = req.params;
        const { dataTypes, format = 'json' } = req.body;
        
        const requestId = await this.privacyManager.requestDataExport(
          userId,
          dataTypes,
          format
        );

        res.status(202).json({
          status: 'success',
          data: { requestId }
        });
      })
    );

    // Delete user data
    router.delete('/data/:userId',
      asyncHandler(async (req, res) => {
        const { userId } = req.params;
        const { dataTypes } = req.body;
        
        const success = await this.privacyManager.deleteUserData(userId, dataTypes);

        res.json({
          status: success ? 'success' : 'error',
          message: success ? 'Data deleted successfully' : 'Failed to delete data'
        });
      })
    );

    this.app.use('/api/privacy', router);
  }

  private setupNotificationRoutes(): void {
    const router = express.Router();

    // Get notification history
    router.get('/:userId',
      asyncHandler(async (req, res) => {
        const { userId } = req.params;
        const { limit = 50, offset = 0 } = req.query;
        
        const notifications = await this.notificationService.getNotificationHistory(
          userId,
          Number(limit),
          Number(offset)
        );

        res.json({
          status: 'success',
          data: notifications
        });
      })
    );

    // Mark notification as read
    router.put('/:notificationId/read',
      asyncHandler(async (req, res) => {
        const { notificationId } = req.params;
        const { userId } = req.body;
        
        const success = await this.notificationService.markAsRead(notificationId, userId);

        res.json({
          status: success ? 'success' : 'error',
          message: success ? 'Notification marked as read' : 'Failed to mark as read'
        });
      })
    );

    // Get unread count
    router.get('/:userId/unread-count',
      asyncHandler(async (req, res) => {
        const { userId } = req.params;
        
        const count = await this.notificationService.getUnreadCount(userId);

        res.json({
          status: 'success',
          data: { count }
        });
      })
    );

    this.app.use('/api/notifications', router);
  }

  private setupAdminRoutes(): void {
    const router = express.Router();

    // Get system stats
    router.get('/stats',
      asyncHandler(async (req, res) => {
        const queueStats = await this.jobScheduler.getQueueStats();
        const serviceHealth = serviceMonitor.getServiceHealth();
        
        res.json({
          status: 'success',
          data: {
            queues: queueStats,
            services: serviceHealth,
            memory: process.memoryUsage(),
            uptime: process.uptime()
          }
        });
      })
    );

    // Control background jobs
    router.post('/jobs/:jobName/:action',
      asyncHandler(async (req, res) => {
        const { jobName, action } = req.params;
        
        let success = false;
        if (action === 'pause') {
          success = await this.jobScheduler.pauseJob(jobName);
        } else if (action === 'resume') {
          success = await this.jobScheduler.resumeJob(jobName);
        }

        res.json({
          status: success ? 'success' : 'error',
          message: `Job ${jobName} ${action} ${success ? 'successful' : 'failed'}`
        });
      })
    );

    this.app.use('/api/admin', router);
  }

  private setupErrorHandling(): void {
    this.app.use(errorHandler);
  }

  private setupWebSocketServer(): void {
    this.wsServer = new WebSocket.Server({ 
      server: this.server,
      path: '/ws'
    });

    this.wsServer.on('connection', (ws, request) => {
      const url = new URL(request.url || '', `http://${request.headers.host}`);
      const userId = url.searchParams.get('userId');

      if (userId) {
        // Add connection to notification service
        this.notificationService.addWebSocketConnection(userId, ws);
        
        // Add connection to price tracking service
        this.priceTrackingService.addWebSocketConnection(userId, ws);
        
        logger.info(`WebSocket connected: ${userId}`);
      } else {
        ws.close(1008, 'User ID required');
      }
    });
  }

  private async connectDatabase(): Promise<void> {
    try {
      const mongoUrl = process.env.MONGODB_URL || 'mongodb://localhost:27017/stylesync-shopping';
      await mongoose.connect(mongoUrl);
      logger.info('Connected to MongoDB');
    } catch (error) {
      logger.error('MongoDB connection failed:', error);
      process.exit(1);
    }
  }

  async start(): Promise<void> {
    try {
      // Connect to database
      await this.connectDatabase();

      // Start HTTP server
      const port = process.env.PORT || 3000;
      this.server = createServer(this.app);
      
      // Setup WebSocket server
      this.setupWebSocketServer();

      // Start background services
      await this.priceTrackingService.startTracking(30); // 30 minute intervals

      this.server.listen(port, () => {
        logger.info(`Shopping service started on port ${port}`);
        logger.info(`WebSocket server available at ws://localhost:${port}/ws`);
      });

      // Graceful shutdown handling
      process.on('SIGTERM', this.shutdown.bind(this));
      process.on('SIGINT', this.shutdown.bind(this));

    } catch (error) {
      logger.error('Failed to start server:', error);
      process.exit(1);
    }
  }

  private async shutdown(): Promise<void> {
    logger.info('Shutting down server...');

    try {
      // Close WebSocket server
      this.wsServer.close();

      // Shutdown services
      await this.priceTrackingService.shutdown();
      await this.notificationService.shutdown();
      await this.privacyManager.shutdown();
      await this.scrapingEngine.shutdown();
      await this.jobScheduler.shutdown();

      // Close database connection
      await mongoose.connection.close();

      // Close HTTP server
      this.server.close(() => {
        logger.info('Server shut down complete');
        process.exit(0);
      });

    } catch (error) {
      logger.error('Error during shutdown:', error);
      process.exit(1);
    }
  }
}

// Start the server
if (require.main === module) {
  const server = new ShoppingServer();
  server.start();
}

export default ShoppingServer;