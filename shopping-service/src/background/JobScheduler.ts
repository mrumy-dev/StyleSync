import Queue from 'bull';
import cron from 'node-cron';
import { PriceTrackingService } from '../realtime/PriceTrackingService';
import { StoreIntegrationManager } from '../integrations/StoreIntegrationManager';
import { ScrapingEngine } from '../scrapers/ScrapingEngine';
import { Product } from '../models/Product';
import { VisualSimilarityEngine } from '../matching/VisualSimilarityEngine';

export interface JobConfig {
  name: string;
  schedule: string; // cron expression
  enabled: boolean;
  maxRetries: number;
  timeout: number;
  priority: 'low' | 'normal' | 'high';
}

export class JobScheduler {
  private priceUpdateQueue: Queue.Queue;
  private dataCleanupQueue: Queue.Queue;
  private recommendationQueue: Queue.Queue;
  private imageProcessingQueue: Queue.Queue;
  private priceTrackingService: PriceTrackingService;
  private storeManager: StoreIntegrationManager;
  private scrapingEngine: ScrapingEngine;
  private visualEngine: VisualSimilarityEngine;
  private scheduledJobs: Map<string, cron.ScheduledTask> = new Map();

  constructor() {
    // Initialize Bull queues with Redis
    const redisConfig = {
      redis: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        password: process.env.REDIS_PASSWORD
      }
    };

    this.priceUpdateQueue = new Queue('price updates', redisConfig);
    this.dataCleanupQueue = new Queue('data cleanup', redisConfig);
    this.recommendationQueue = new Queue('recommendations', redisConfig);
    this.imageProcessingQueue = new Queue('image processing', redisConfig);

    // Initialize services
    this.priceTrackingService = new PriceTrackingService();
    this.storeManager = new StoreIntegrationManager();
    this.scrapingEngine = new ScrapingEngine();
    this.visualEngine = new VisualSimilarityEngine();

    this.setupQueueProcessors();
    this.scheduleJobs();
  }

  private setupQueueProcessors(): void {
    // Price update queue processor
    this.priceUpdateQueue.process('update-product-prices', 10, async (job) => {
      const { productIds, stores } = job.data;
      console.log(`Processing price updates for ${productIds.length} products`);

      const results = await Promise.allSettled(
        productIds.map((productId: string) => this.updateProductPrice(productId, stores))
      );

      const successful = results.filter(r => r.status === 'fulfilled').length;
      const failed = results.length - successful;

      return { successful, failed, total: results.length };
    });

    // Data cleanup queue processor
    this.dataCleanupQueue.process('cleanup-expired-data', 5, async (job) => {
      const { dataType, olderThanDays } = job.data;
      console.log(`Cleaning up ${dataType} older than ${olderThanDays} days`);

      return this.cleanupExpiredData(dataType, olderThanDays);
    });

    // Recommendation queue processor
    this.recommendationQueue.process('generate-recommendations', 3, async (job) => {
      const { userId, limit } = job.data;
      console.log(`Generating recommendations for user ${userId}`);

      return this.generateUserRecommendations(userId, limit);
    });

    // Image processing queue processor
    this.imageProcessingQueue.process('extract-visual-features', 5, async (job) => {
      const { productId } = job.data;
      console.log(`Extracting visual features for product ${productId}`);

      return this.extractProductVisualFeatures(productId);
    });

    // Error handling
    [this.priceUpdateQueue, this.dataCleanupQueue, this.recommendationQueue, this.imageProcessingQueue]
      .forEach(queue => {
        queue.on('failed', (job, err) => {
          console.error(`Job ${job.id} failed in queue ${queue.name}:`, err);
        });

        queue.on('completed', (job, result) => {
          console.log(`Job ${job.id} completed in queue ${queue.name}:`, result);
        });
      });
  }

  private scheduleJobs(): void {
    const jobs: JobConfig[] = [
      {
        name: 'price-update-frequent',
        schedule: '*/30 * * * *', // Every 30 minutes
        enabled: true,
        maxRetries: 3,
        timeout: 600000, // 10 minutes
        priority: 'high'
      },
      {
        name: 'price-update-comprehensive',
        schedule: '0 */4 * * *', // Every 4 hours
        enabled: true,
        maxRetries: 2,
        timeout: 1800000, // 30 minutes
        priority: 'normal'
      },
      {
        name: 'data-cleanup',
        schedule: '0 2 * * *', // Daily at 2 AM
        enabled: true,
        maxRetries: 1,
        timeout: 3600000, // 1 hour
        priority: 'low'
      },
      {
        name: 'generate-recommendations',
        schedule: '0 6 * * *', // Daily at 6 AM
        enabled: true,
        maxRetries: 2,
        timeout: 1800000, // 30 minutes
        priority: 'normal'
      },
      {
        name: 'process-new-products',
        schedule: '0 */2 * * *', // Every 2 hours
        enabled: true,
        maxRetries: 3,
        timeout: 900000, // 15 minutes
        priority: 'normal'
      },
      {
        name: 'update-visual-features',
        schedule: '0 1 * * *', // Daily at 1 AM
        enabled: true,
        maxRetries: 2,
        timeout: 7200000, // 2 hours
        priority: 'low'
      }
    ];

    jobs.forEach(jobConfig => {
      if (jobConfig.enabled) {
        const task = cron.schedule(jobConfig.schedule, () => {
          this.executeJob(jobConfig);
        }, { scheduled: false });

        this.scheduledJobs.set(jobConfig.name, task);
        task.start();
        console.log(`Scheduled job: ${jobConfig.name} with schedule: ${jobConfig.schedule}`);
      }
    });
  }

  private async executeJob(config: JobConfig): Promise<void> {
    try {
      console.log(`Executing job: ${config.name}`);

      switch (config.name) {
        case 'price-update-frequent':
          await this.scheduleFrequentPriceUpdates();
          break;
        case 'price-update-comprehensive':
          await this.scheduleComprehensivePriceUpdates();
          break;
        case 'data-cleanup':
          await this.scheduleDataCleanup();
          break;
        case 'generate-recommendations':
          await this.scheduleRecommendationGeneration();
          break;
        case 'process-new-products':
          await this.scheduleNewProductProcessing();
          break;
        case 'update-visual-features':
          await this.scheduleVisualFeatureUpdates();
          break;
        default:
          console.warn(`Unknown job: ${config.name}`);
      }
    } catch (error) {
      console.error(`Job ${config.name} failed:`, error);
    }
  }

  private async scheduleFrequentPriceUpdates(): Promise<void> {
    // Get products that need frequent updates (popular, on sale, etc.)
    const products = await Product.find({
      $or: [
        { 'metadata.popularity': { $gte: 0.8 } },
        { 'price.original': { $exists: true } }, // On sale items
        { 'availability.quantity': { $lte: 10 } } // Low stock items
      ]
    }).limit(500);

    const productIds = products.map(p => p.id);
    const stores = ['zalando', 'asos', 'nordstrom'];

    if (productIds.length > 0) {
      await this.priceUpdateQueue.add('update-product-prices', {
        productIds,
        stores
      }, {
        priority: 100,
        attempts: 3,
        backoff: 'exponential'
      });
    }
  }

  private async scheduleComprehensivePriceUpdates(): Promise<void> {
    // Get all products that haven't been updated in the last 6 hours
    const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);
    const products = await Product.find({
      'metadata.lastUpdated': { $lt: sixHoursAgo }
    }).limit(2000);

    const productIds = products.map(p => p.id);
    const stores = ['zalando', 'asos', 'nordstrom', 'shein', 'zara'];

    // Split into smaller batches
    const batchSize = 100;
    for (let i = 0; i < productIds.length; i += batchSize) {
      const batch = productIds.slice(i, i + batchSize);
      
      await this.priceUpdateQueue.add('update-product-prices', {
        productIds: batch,
        stores
      }, {
        priority: 50,
        attempts: 2,
        delay: i * 1000 // Stagger batch processing
      });
    }
  }

  private async scheduleDataCleanup(): Promise<void> {
    const cleanupTasks = [
      { dataType: 'expired_sessions', olderThanDays: 1 },
      { dataType: 'old_search_logs', olderThanDays: 30 },
      { dataType: 'completed_exports', olderThanDays: 7 },
      { dataType: 'old_price_history', olderThanDays: 90 },
      { dataType: 'failed_jobs', olderThanDays: 7 }
    ];

    for (const task of cleanupTasks) {
      await this.dataCleanupQueue.add('cleanup-expired-data', task, {
        priority: 10,
        attempts: 1
      });
    }
  }

  private async scheduleRecommendationGeneration(): Promise<void> {
    // Get active users who need recommendation updates
    const activeUsers = await this.getActiveUsers();

    for (const userId of activeUsers) {
      await this.recommendationQueue.add('generate-recommendations', {
        userId,
        limit: 50
      }, {
        priority: 30,
        attempts: 2,
        delay: Math.random() * 10000 // Random delay to spread load
      });
    }
  }

  private async scheduleNewProductProcessing(): Promise<void> {
    // Get products added in the last 2 hours that need processing
    const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000);
    const newProducts = await Product.find({
      'metadata.scrapedAt': { $gte: twoHoursAgo },
      'metadata.visualFeaturesExtracted': { $ne: true }
    }).limit(200);

    for (const product of newProducts) {
      await this.imageProcessingQueue.add('extract-visual-features', {
        productId: product.id
      }, {
        priority: 40,
        attempts: 3
      });
    }
  }

  private async scheduleVisualFeatureUpdates(): Promise<void> {
    // Get products that need visual feature updates
    const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const products = await Product.find({
      $or: [
        { 'metadata.visualFeaturesExtracted': { $ne: true } },
        { 'metadata.visualFeaturesUpdatedAt': { $lt: oneWeekAgo } }
      ]
    }).limit(500);

    for (const product of products) {
      await this.imageProcessingQueue.add('extract-visual-features', {
        productId: product.id
      }, {
        priority: 20,
        attempts: 2,
        delay: Math.random() * 60000 // Random delay up to 1 minute
      });
    }
  }

  // Job implementation methods
  private async updateProductPrice(productId: string, stores: string[]): Promise<void> {
    const product = await Product.findOne({ id: productId });
    if (!product) return;

    try {
      // Try API first, then scraping
      let updatedProduct = null;
      
      for (const store of stores) {
        if (product.store.name.toLowerCase() === store) {
          try {
            updatedProduct = await this.storeManager.getProductFromStore(
              store,
              product.store.productId
            );
            break;
          } catch (error) {
            console.log(`API failed for ${productId}, trying scraper...`);
            updatedProduct = await this.scrapingEngine.scrapeProduct(
              store,
              product.store.url
            );
            break;
          }
        }
      }

      if (updatedProduct) {
        await Product.updateOne(
          { id: productId },
          {
            $set: {
              price: updatedProduct.price,
              availability: updatedProduct.availability,
              'metadata.lastUpdated': new Date()
            }
          }
        );
      }
    } catch (error) {
      console.error(`Failed to update price for ${productId}:`, error);
      throw error;
    }
  }

  private async cleanupExpiredData(dataType: string, olderThanDays: number): Promise<number> {
    const cutoffDate = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000);
    let deletedCount = 0;

    switch (dataType) {
      case 'old_price_history':
        // Remove old price history points while keeping recent ones
        deletedCount = await this.cleanupOldPriceHistory(cutoffDate);
        break;
      case 'expired_sessions':
        // Cleanup handled by PrivacyManager
        deletedCount = 0;
        break;
      case 'failed_jobs':
        deletedCount = await this.cleanupFailedJobs(cutoffDate);
        break;
      default:
        console.warn(`Unknown data type for cleanup: ${dataType}`);
    }

    return deletedCount;
  }

  private async generateUserRecommendations(userId: string, limit: number): Promise<number> {
    try {
      // This would integrate with your recommendation engine
      // For now, just log the action
      console.log(`Generated ${limit} recommendations for user ${userId}`);
      return limit;
    } catch (error) {
      console.error(`Failed to generate recommendations for ${userId}:`, error);
      throw error;
    }
  }

  private async extractProductVisualFeatures(productId: string): Promise<boolean> {
    try {
      const product = await Product.findOne({ id: productId });
      if (!product || !product.images.main) {
        return false;
      }

      const features = await this.visualEngine.extractVisualFeatures(product);
      
      await Product.updateOne(
        { id: productId },
        {
          $set: {
            'metadata.visualFeatures': features,
            'metadata.visualFeaturesExtracted': true,
            'metadata.visualFeaturesUpdatedAt': new Date()
          }
        }
      );

      return true;
    } catch (error) {
      console.error(`Failed to extract visual features for ${productId}:`, error);
      throw error;
    }
  }

  // Helper methods
  private async getActiveUsers(): Promise<string[]> {
    // Get users who have been active in the last 7 days
    // This would query your user activity logs
    return ['user1', 'user2']; // Mock implementation
  }

  private async cleanupOldPriceHistory(cutoffDate: Date): Promise<number> {
    // Remove old price history points beyond the cutoff
    const result = await Product.updateMany(
      {},
      {
        $pull: {
          'priceHistory.pricePoints': {
            timestamp: { $lt: cutoffDate }
          }
        }
      }
    );

    return result.modifiedCount;
  }

  private async cleanupFailedJobs(cutoffDate: Date): Promise<number> {
    // Clean up failed jobs from Bull queues
    let cleanedCount = 0;
    
    const queues = [
      this.priceUpdateQueue,
      this.dataCleanupQueue,
      this.recommendationQueue,
      this.imageProcessingQueue
    ];

    for (const queue of queues) {
      const failedJobs = await queue.getFailed();
      
      for (const job of failedJobs) {
        if (job.timestamp < cutoffDate.getTime()) {
          await job.remove();
          cleanedCount++;
        }
      }
    }

    return cleanedCount;
  }

  // Control methods
  async pauseJob(jobName: string): Promise<boolean> {
    const task = this.scheduledJobs.get(jobName);
    if (task) {
      task.stop();
      console.log(`Paused job: ${jobName}`);
      return true;
    }
    return false;
  }

  async resumeJob(jobName: string): Promise<boolean> {
    const task = this.scheduledJobs.get(jobName);
    if (task) {
      task.start();
      console.log(`Resumed job: ${jobName}`);
      return true;
    }
    return false;
  }

  async getQueueStats(): Promise<any> {
    const queues = {
      priceUpdate: this.priceUpdateQueue,
      dataCleanup: this.dataCleanupQueue,
      recommendation: this.recommendationQueue,
      imageProcessing: this.imageProcessingQueue
    };

    const stats: any = {};

    for (const [name, queue] of Object.entries(queues)) {
      stats[name] = {
        waiting: await queue.getWaiting(),
        active: await queue.getActive(),
        completed: await queue.getCompleted(),
        failed: await queue.getFailed()
      };
    }

    return stats;
  }

  async shutdown(): Promise<void> {
    console.log('Shutting down job scheduler...');

    // Stop all scheduled jobs
    for (const [name, task] of this.scheduledJobs) {
      task.stop();
      console.log(`Stopped job: ${name}`);
    }

    // Close all queues
    await Promise.all([
      this.priceUpdateQueue.close(),
      this.dataCleanupQueue.close(),
      this.recommendationQueue.close(),
      this.imageProcessingQueue.close()
    ]);

    // Shutdown services
    await this.priceTrackingService.shutdown();
    await this.scrapingEngine.shutdown();

    console.log('Job scheduler shut down complete');
  }
}