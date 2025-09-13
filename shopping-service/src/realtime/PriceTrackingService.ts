import { EventEmitter } from 'events';
import { IProduct, Product } from '../models/Product';
import { IPriceHistory, PriceHistory } from '../models/PriceHistory';
import { StoreIntegrationManager } from '../integrations/StoreIntegrationManager';
import { ScrapingEngine } from '../scrapers/ScrapingEngine';
import WebSocket from 'ws';
import { createClient, RedisClientType } from 'redis';

export interface PriceAlert {
  id: string;
  productId: string;
  userId?: string;
  triggerPrice: number;
  condition: 'below' | 'above' | 'change_percent';
  threshold?: number; // for percentage changes
  isActive: boolean;
  createdAt: Date;
  triggeredAt?: Date;
}

export interface PriceUpdate {
  productId: string;
  store: string;
  currentPrice: number;
  previousPrice: number;
  priceChange: number;
  percentageChange: number;
  timestamp: Date;
  onSale: boolean;
  salePercentage?: number;
  stockStatus: 'in_stock' | 'out_of_stock' | 'low_stock';
}

export interface NotificationPayload {
  type: 'price_drop' | 'price_increase' | 'back_in_stock' | 'sale_alert' | 'new_arrival';
  productId: string;
  product: IProduct;
  priceUpdate?: PriceUpdate;
  message: string;
  userId?: string;
  priority: 'low' | 'medium' | 'high';
}

export class PriceTrackingService extends EventEmitter {
  private storeManager: StoreIntegrationManager;
  private scrapingEngine: ScrapingEngine;
  private redisClient: RedisClientType;
  private wsConnections: Map<string, WebSocket> = new Map();
  private activeAlerts: Map<string, PriceAlert> = new Map();
  private trackingInterval: NodeJS.Timeout | null = null;
  private isTracking = false;

  constructor() {
    super();
    this.storeManager = new StoreIntegrationManager();
    this.scrapingEngine = new ScrapingEngine();
    this.redisClient = createClient({
      url: process.env.REDIS_URL || 'redis://localhost:6379'
    });
    
    this.initialize();
  }

  private async initialize() {
    try {
      await this.redisClient.connect();
      await this.loadActiveAlerts();
      console.log('Price tracking service initialized');
    } catch (error) {
      console.error('Failed to initialize price tracking service:', error);
    }
  }

  async startTracking(intervalMinutes: number = 30): Promise<void> {
    if (this.isTracking) {
      console.log('Price tracking already running');
      return;
    }

    this.isTracking = true;
    console.log(`Starting price tracking with ${intervalMinutes}min intervals`);

    // Initial scan
    await this.performPriceUpdate();

    // Set up periodic updates
    this.trackingInterval = setInterval(async () => {
      try {
        await this.performPriceUpdate();
      } catch (error) {
        console.error('Price update failed:', error);
      }
    }, intervalMinutes * 60 * 1000);
  }

  async stopTracking(): Promise<void> {
    if (this.trackingInterval) {
      clearInterval(this.trackingInterval);
      this.trackingInterval = null;
    }
    this.isTracking = false;
    console.log('Price tracking stopped');
  }

  async addPriceAlert(alert: Omit<PriceAlert, 'id' | 'createdAt'>): Promise<string> {
    const alertId = this.generateAlertId();
    const fullAlert: PriceAlert = {
      ...alert,
      id: alertId,
      createdAt: new Date()
    };

    this.activeAlerts.set(alertId, fullAlert);
    
    // Store in Redis for persistence
    await this.redisClient.hSet('price_alerts', alertId, JSON.stringify(fullAlert));

    console.log(`Price alert created: ${alertId} for product ${alert.productId}`);
    return alertId;
  }

  async removePriceAlert(alertId: string): Promise<boolean> {
    const removed = this.activeAlerts.delete(alertId);
    if (removed) {
      await this.redisClient.hDel('price_alerts', alertId);
      console.log(`Price alert removed: ${alertId}`);
    }
    return removed;
  }

  async getPriceHistory(
    productId: string,
    days: number = 30
  ): Promise<IPriceHistory | null> {
    try {
      const history = await PriceHistory.findOne({ productId });
      if (!history) return null;

      // Filter price points to last N days
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - days);

      const filteredPoints = history.pricePoints.filter(
        point => point.timestamp >= cutoffDate
      );

      return {
        ...history.toObject(),
        pricePoints: filteredPoints
      };
    } catch (error) {
      console.error(`Failed to get price history for ${productId}:`, error);
      return null;
    }
  }

  async getPriceAnalytics(productId: string): Promise<{
    currentPrice: number;
    averagePrice: number;
    lowestPrice: number;
    highestPrice: number;
    priceVolatility: number;
    trend: 'increasing' | 'decreasing' | 'stable';
    onSale: boolean;
    salePercentage?: number;
    predictedNextPrice?: number;
  } | null> {
    try {
      const product = await Product.findOne({ id: productId });
      const history = await PriceHistory.findOne({ productId });

      if (!product || !history) return null;

      const currentPrice = product.price.current;
      const originalPrice = product.price.original;
      const onSale = originalPrice ? currentPrice < originalPrice : false;
      const salePercentage = onSale && originalPrice ? 
        ((originalPrice - currentPrice) / originalPrice) * 100 : undefined;

      // Predict next price using simple trend analysis
      const predictedNextPrice = this.predictNextPrice(history.pricePoints);

      return {
        currentPrice,
        averagePrice: history.analytics.averagePrice,
        lowestPrice: history.analytics.lowestPrice,
        highestPrice: history.analytics.highestPrice,
        priceVolatility: history.analytics.priceVolatility,
        trend: history.analytics.trend,
        onSale,
        salePercentage,
        predictedNextPrice
      };
    } catch (error) {
      console.error(`Failed to get price analytics for ${productId}:`, error);
      return null;
    }
  }

  addWebSocketConnection(userId: string, ws: WebSocket): void {
    this.wsConnections.set(userId, ws);
    
    ws.on('close', () => {
      this.wsConnections.delete(userId);
    });

    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        this.handleWebSocketMessage(userId, message);
      } catch (error) {
        console.error('Invalid WebSocket message:', error);
      }
    });
  }

  private async performPriceUpdate(): Promise<void> {
    console.log('Starting price update cycle...');
    
    // Get all products that need price updates
    const productsToUpdate = await this.getProductsForUpdate();
    
    if (productsToUpdate.length === 0) {
      console.log('No products to update');
      return;
    }

    console.log(`Updating prices for ${productsToUpdate.length} products`);

    const updatePromises = productsToUpdate.map(product => 
      this.updateProductPrice(product)
    );

    const results = await Promise.allSettled(updatePromises);
    
    const successful = results.filter(r => r.status === 'fulfilled').length;
    const failed = results.length - successful;
    
    console.log(`Price update completed: ${successful} successful, ${failed} failed`);
  }

  private async getProductsForUpdate(): Promise<IProduct[]> {
    try {
      // Get products that haven't been updated in the last hour
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
      
      const products = await Product.find({
        'metadata.lastUpdated': { $lt: oneHourAgo },
        'availability.inStock': true
      }).limit(100);

      return products;
    } catch (error) {
      console.error('Failed to get products for update:', error);
      return [];
    }
  }

  private async updateProductPrice(product: IProduct): Promise<void> {
    try {
      const storeName = product.store.name.toLowerCase();
      let updatedProduct: IProduct | null = null;

      // Try API first, then scraping
      try {
        updatedProduct = await this.storeManager.getProductFromStore(
          storeName,
          product.store.productId
        );
      } catch (error) {
        console.log(`API failed for ${product.id}, trying scraper...`);
        
        updatedProduct = await this.scrapingEngine.scrapeProduct(
          storeName,
          product.store.url
        );
      }

      if (!updatedProduct) {
        console.warn(`Could not update product ${product.id}`);
        return;
      }

      const previousPrice = product.price.current;
      const currentPrice = updatedProduct.price.current;

      // Update product in database
      await Product.updateOne(
        { id: product.id },
        {
          $set: {
            price: updatedProduct.price,
            availability: updatedProduct.availability,
            'metadata.lastUpdated': new Date()
          }
        }
      );

      // Record price history
      await this.recordPriceChange(product.id, currentPrice, previousPrice, product.store.name);

      // Create price update object
      const priceUpdate: PriceUpdate = {
        productId: product.id,
        store: product.store.name,
        currentPrice,
        previousPrice,
        priceChange: currentPrice - previousPrice,
        percentageChange: previousPrice > 0 ? ((currentPrice - previousPrice) / previousPrice) * 100 : 0,
        timestamp: new Date(),
        onSale: updatedProduct.price.original ? currentPrice < updatedProduct.price.original : false,
        salePercentage: updatedProduct.price.original && currentPrice < updatedProduct.price.original ?
          ((updatedProduct.price.original - currentPrice) / updatedProduct.price.original) * 100 : undefined,
        stockStatus: updatedProduct.availability.inStock ? 'in_stock' : 'out_of_stock'
      };

      // Check for triggered alerts
      await this.checkTriggeredAlerts(product, priceUpdate);

      // Emit price update event
      this.emit('priceUpdate', priceUpdate);

      console.log(`Updated price for ${product.name}: $${previousPrice} → $${currentPrice}`);

    } catch (error) {
      console.error(`Failed to update price for ${product.id}:`, error);
    }
  }

  private async recordPriceChange(
    productId: string,
    currentPrice: number,
    previousPrice: number,
    store: string
  ): Promise<void> {
    try {
      const pricePoint = {
        price: currentPrice,
        timestamp: new Date(),
        onSale: false, // Will be updated based on original price comparison
        salePercentage: undefined
      };

      let history = await PriceHistory.findOne({ productId, store });

      if (!history) {
        // Create new price history
        history = new PriceHistory({
          productId,
          store,
          pricePoints: [pricePoint],
          analytics: {
            averagePrice: currentPrice,
            lowestPrice: currentPrice,
            highestPrice: currentPrice,
            priceVolatility: 0,
            trend: 'stable' as const
          }
        });
      } else {
        // Update existing history
        history.pricePoints.push(pricePoint);
        
        // Keep only last 90 days of data
        const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
        history.pricePoints = history.pricePoints.filter(p => p.timestamp >= ninetyDaysAgo);
        
        // Recalculate analytics
        history.analytics = this.calculatePriceAnalytics(history.pricePoints);
      }

      await history.save();
    } catch (error) {
      console.error(`Failed to record price change for ${productId}:`, error);
    }
  }

  private calculatePriceAnalytics(pricePoints: Array<{ price: number; timestamp: Date }>): {
    averagePrice: number;
    lowestPrice: number;
    highestPrice: number;
    priceVolatility: number;
    trend: 'increasing' | 'decreasing' | 'stable';
  } {
    if (pricePoints.length === 0) {
      return {
        averagePrice: 0,
        lowestPrice: 0,
        highestPrice: 0,
        priceVolatility: 0,
        trend: 'stable'
      };
    }

    const prices = pricePoints.map(p => p.price);
    const averagePrice = prices.reduce((sum, price) => sum + price, 0) / prices.length;
    const lowestPrice = Math.min(...prices);
    const highestPrice = Math.max(...prices);

    // Calculate volatility (standard deviation)
    const variance = prices.reduce((sum, price) => sum + Math.pow(price - averagePrice, 2), 0) / prices.length;
    const priceVolatility = Math.sqrt(variance) / averagePrice;

    // Determine trend using linear regression
    const trend = this.calculatePriceTrend(pricePoints);

    return {
      averagePrice,
      lowestPrice,
      highestPrice,
      priceVolatility,
      trend
    };
  }

  private calculatePriceTrend(pricePoints: Array<{ price: number; timestamp: Date }>): 'increasing' | 'decreasing' | 'stable' {
    if (pricePoints.length < 3) return 'stable';

    // Simple linear regression
    const n = pricePoints.length;
    let sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;

    pricePoints.forEach((point, index) => {
      sumX += index;
      sumY += point.price;
      sumXY += index * point.price;
      sumXX += index * index;
    });

    const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    const threshold = 0.1; // Minimum slope to consider trend significant

    if (slope > threshold) return 'increasing';
    if (slope < -threshold) return 'decreasing';
    return 'stable';
  }

  private async checkTriggeredAlerts(product: IProduct, priceUpdate: PriceUpdate): Promise<void> {
    const productAlerts = Array.from(this.activeAlerts.values())
      .filter(alert => alert.productId === product.id && alert.isActive);

    for (const alert of productAlerts) {
      let triggered = false;
      let message = '';

      switch (alert.condition) {
        case 'below':
          triggered = priceUpdate.currentPrice <= alert.triggerPrice;
          message = `Price dropped to $${priceUpdate.currentPrice} (target: $${alert.triggerPrice})`;
          break;
        case 'above':
          triggered = priceUpdate.currentPrice >= alert.triggerPrice;
          message = `Price increased to $${priceUpdate.currentPrice} (target: $${alert.triggerPrice})`;
          break;
        case 'change_percent':
          triggered = Math.abs(priceUpdate.percentageChange) >= (alert.threshold || 10);
          message = `Price changed by ${priceUpdate.percentageChange.toFixed(1)}% to $${priceUpdate.currentPrice}`;
          break;
      }

      if (triggered) {
        await this.triggerAlert(alert, product, priceUpdate, message);
      }
    }
  }

  private async triggerAlert(
    alert: PriceAlert,
    product: IProduct,
    priceUpdate: PriceUpdate,
    message: string
  ): Promise<void> {
    try {
      // Mark alert as triggered
      alert.triggeredAt = new Date();
      alert.isActive = false;
      await this.redisClient.hSet('price_alerts', alert.id, JSON.stringify(alert));

      // Create notification
      const notification: NotificationPayload = {
        type: priceUpdate.priceChange < 0 ? 'price_drop' : 'price_increase',
        productId: product.id,
        product,
        priceUpdate,
        message,
        userId: alert.userId,
        priority: 'high'
      };

      // Send notification
      await this.sendNotification(notification);

      console.log(`Alert triggered: ${alert.id} - ${message}`);
    } catch (error) {
      console.error(`Failed to trigger alert ${alert.id}:`, error);
    }
  }

  private async sendNotification(notification: NotificationPayload): Promise<void> {
    // Send via WebSocket if user is connected
    if (notification.userId) {
      const ws = this.wsConnections.get(notification.userId);
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
          type: 'notification',
          payload: notification
        }));
      }
    }

    // Store notification for later retrieval
    await this.redisClient.lPush(
      `notifications:${notification.userId || 'global'}`,
      JSON.stringify(notification)
    );

    // Emit event for other services to handle
    this.emit('notification', notification);
  }

  private predictNextPrice(pricePoints: Array<{ price: number; timestamp: Date }>): number | undefined {
    if (pricePoints.length < 5) return undefined;

    // Simple moving average prediction
    const recentPrices = pricePoints.slice(-5).map(p => p.price);
    const average = recentPrices.reduce((sum, price) => sum + price, 0) / recentPrices.length;
    
    return Math.round(average * 100) / 100;
  }

  private async loadActiveAlerts(): Promise<void> {
    try {
      const alerts = await this.redisClient.hGetAll('price_alerts');
      
      for (const [alertId, alertData] of Object.entries(alerts)) {
        try {
          const alert: PriceAlert = JSON.parse(alertData);
          if (alert.isActive) {
            this.activeAlerts.set(alertId, alert);
          }
        } catch (error) {
          console.error(`Failed to parse alert ${alertId}:`, error);
        }
      }

      console.log(`Loaded ${this.activeAlerts.size} active price alerts`);
    } catch (error) {
      console.error('Failed to load active alerts:', error);
    }
  }

  private handleWebSocketMessage(userId: string, message: any): void {
    // Handle client messages like subscribing to specific product updates
    if (message.type === 'subscribe' && message.productId) {
      // Add user to product-specific updates
      console.log(`User ${userId} subscribed to updates for product ${message.productId}`);
    }
  }

  private generateAlertId(): string {
    return `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  async shutdown(): Promise<void> {
    await this.stopTracking();
    await this.scrapingEngine.shutdown();
    await this.redisClient.disconnect();
    
    for (const ws of this.wsConnections.values()) {
      ws.close();
    }
    
    console.log('Price tracking service shut down');
  }
}