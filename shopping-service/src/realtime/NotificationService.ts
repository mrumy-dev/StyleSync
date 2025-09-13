import { EventEmitter } from 'events';
import WebSocket from 'ws';
import { createClient, RedisClientType } from 'redis';
import { IProduct } from '../models/Product';

export interface Notification {
  id: string;
  userId?: string;
  type: 'price_drop' | 'price_increase' | 'back_in_stock' | 'sale_alert' | 'new_arrival' | 'coupon_alert';
  title: string;
  message: string;
  data: {
    productId?: string;
    product?: IProduct;
    priceChange?: {
      oldPrice: number;
      newPrice: number;
      percentage: number;
    };
    couponCode?: string;
    expiresAt?: Date;
  };
  priority: 'low' | 'medium' | 'high';
  channels: ('websocket' | 'push' | 'email' | 'sms')[];
  createdAt: Date;
  sentAt?: Date;
  readAt?: Date;
  status: 'pending' | 'sent' | 'delivered' | 'read' | 'failed';
}

export interface UserPreferences {
  userId: string;
  enabledChannels: ('websocket' | 'push' | 'email' | 'sms')[];
  priceDropThreshold: number; // Minimum percentage drop to notify
  notificationHours: {
    start: number; // 0-23
    end: number; // 0-23
  };
  timezone: string;
  categories: string[]; // Categories user wants notifications for
  maxNotificationsPerDay: number;
}

export class NotificationService extends EventEmitter {
  private redisClient: RedisClientType;
  private wsServer: WebSocket.Server;
  private activeConnections: Map<string, WebSocket> = new Map();
  private userPreferences: Map<string, UserPreferences> = new Map();
  private notificationQueue: Notification[] = [];
  private processingInterval: NodeJS.Timeout | null = null;

  constructor(port: number = 8080) {
    super();
    
    this.redisClient = createClient({
      url: process.env.REDIS_URL || 'redis://localhost:6379'
    });

    this.wsServer = new WebSocket.Server({ port });
    this.initialize();
  }

  private async initialize(): Promise<void> {
    try {
      await this.redisClient.connect();
      await this.loadUserPreferences();
      this.setupWebSocketServer();
      this.startNotificationProcessor();
      
      console.log('Notification service initialized');
    } catch (error) {
      console.error('Failed to initialize notification service:', error);
    }
  }

  private setupWebSocketServer(): void {
    this.wsServer.on('connection', (ws, request) => {
      const url = new URL(request.url || '', `http://${request.headers.host}`);
      const userId = url.searchParams.get('userId');
      
      if (!userId) {
        ws.close(1008, 'User ID required');
        return;
      }

      this.activeConnections.set(userId, ws);
      console.log(`User ${userId} connected via WebSocket`);

      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString());
          this.handleWebSocketMessage(userId, message);
        } catch (error) {
          console.error('Invalid WebSocket message:', error);
        }
      });

      ws.on('close', () => {
        this.activeConnections.delete(userId);
        console.log(`User ${userId} disconnected`);
      });

      // Send any pending notifications
      this.sendPendingNotifications(userId);
    });
  }

  async sendNotification(notification: Omit<Notification, 'id' | 'createdAt' | 'status'>): Promise<string> {
    const fullNotification: Notification = {
      ...notification,
      id: this.generateNotificationId(),
      createdAt: new Date(),
      status: 'pending'
    };

    // Store notification
    await this.storeNotification(fullNotification);
    
    // Add to processing queue
    this.notificationQueue.push(fullNotification);
    
    console.log(`Notification queued: ${fullNotification.id} for user ${fullNotification.userId}`);
    return fullNotification.id;
  }

  async sendBulkNotification(
    userIds: string[],
    notification: Omit<Notification, 'id' | 'createdAt' | 'status' | 'userId'>
  ): Promise<string[]> {
    const notificationIds: string[] = [];

    for (const userId of userIds) {
      const preferences = this.userPreferences.get(userId);
      if (!preferences || !this.shouldSendNotification(userId, notification)) {
        continue;
      }

      const id = await this.sendNotification({
        ...notification,
        userId,
        channels: preferences.enabledChannels
      });
      
      notificationIds.push(id);
    }

    return notificationIds;
  }

  async createPriceDropAlert(
    userId: string,
    product: IProduct,
    oldPrice: number,
    newPrice: number
  ): Promise<string> {
    const percentage = ((oldPrice - newPrice) / oldPrice) * 100;
    
    return this.sendNotification({
      userId,
      type: 'price_drop',
      title: `Price Drop: ${product.name}`,
      message: `The price dropped by ${percentage.toFixed(1)}% to $${newPrice}`,
      data: {
        productId: product.id,
        product,
        priceChange: {
          oldPrice,
          newPrice,
          percentage
        }
      },
      priority: percentage > 20 ? 'high' : 'medium',
      channels: ['websocket', 'push']
    });
  }

  async createStockAlert(userId: string, product: IProduct): Promise<string> {
    return this.sendNotification({
      userId,
      type: 'back_in_stock',
      title: `Back in Stock: ${product.name}`,
      message: `${product.name} is now available again!`,
      data: {
        productId: product.id,
        product
      },
      priority: 'high',
      channels: ['websocket', 'push']
    });
  }

  async createSaleAlert(
    userId: string,
    product: IProduct,
    salePercentage: number,
    couponCode?: string
  ): Promise<string> {
    return this.sendNotification({
      userId,
      type: 'sale_alert',
      title: `Sale Alert: ${salePercentage}% Off`,
      message: `${product.name} is ${salePercentage}% off${couponCode ? ` with code ${couponCode}` : ''}!`,
      data: {
        productId: product.id,
        product,
        couponCode,
        expiresAt: couponCode ? new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) : undefined
      },
      priority: salePercentage > 30 ? 'high' : 'medium',
      channels: ['websocket', 'push', 'email']
    });
  }

  async createNewArrivalAlert(userId: string, products: IProduct[]): Promise<string> {
    const brandCounts = new Map<string, number>();
    products.forEach(p => {
      brandCounts.set(p.brand, (brandCounts.get(p.brand) || 0) + 1);
    });

    const topBrands = Array.from(brandCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([brand]) => brand);

    return this.sendNotification({
      userId,
      type: 'new_arrival',
      title: `New Arrivals from ${topBrands.join(', ')}`,
      message: `${products.length} new items matching your style preferences`,
      data: {
        product: products[0] // Featured product
      },
      priority: 'low',
      channels: ['websocket', 'email']
    });
  }

  async setUserPreferences(userId: string, preferences: Partial<UserPreferences>): Promise<void> {
    const existing = this.userPreferences.get(userId) || {
      userId,
      enabledChannels: ['websocket', 'push'],
      priceDropThreshold: 10,
      notificationHours: { start: 8, end: 22 },
      timezone: 'UTC',
      categories: [],
      maxNotificationsPerDay: 10
    };

    const updated = { ...existing, ...preferences };
    this.userPreferences.set(userId, updated);

    // Store in Redis
    await this.redisClient.hSet('user_preferences', userId, JSON.stringify(updated));
    
    console.log(`Updated preferences for user ${userId}`);
  }

  async getUserPreferences(userId: string): Promise<UserPreferences | null> {
    return this.userPreferences.get(userId) || null;
  }

  async getNotificationHistory(
    userId: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<Notification[]> {
    try {
      const notifications = await this.redisClient.lRange(
        `notifications:${userId}`,
        offset,
        offset + limit - 1
      );

      return notifications.map(n => JSON.parse(n));
    } catch (error) {
      console.error(`Failed to get notification history for ${userId}:`, error);
      return [];
    }
  }

  async markAsRead(notificationId: string, userId: string): Promise<boolean> {
    try {
      const notification = await this.getNotification(notificationId);
      if (!notification || notification.userId !== userId) {
        return false;
      }

      notification.readAt = new Date();
      notification.status = 'read';

      await this.storeNotification(notification);
      return true;
    } catch (error) {
      console.error(`Failed to mark notification ${notificationId} as read:`, error);
      return false;
    }
  }

  async getUnreadCount(userId: string): Promise<number> {
    try {
      const notifications = await this.getNotificationHistory(userId, 100);
      return notifications.filter(n => !n.readAt).length;
    } catch (error) {
      console.error(`Failed to get unread count for ${userId}:`, error);
      return 0;
    }
  }

  private startNotificationProcessor(): void {
    this.processingInterval = setInterval(async () => {
      await this.processNotificationQueue();
    }, 5000); // Process every 5 seconds
  }

  private async processNotificationQueue(): Promise<void> {
    if (this.notificationQueue.length === 0) return;

    const batch = this.notificationQueue.splice(0, 10); // Process 10 at a time
    
    for (const notification of batch) {
      try {
        await this.deliverNotification(notification);
      } catch (error) {
        console.error(`Failed to deliver notification ${notification.id}:`, error);
        notification.status = 'failed';
        await this.storeNotification(notification);
      }
    }
  }

  private async deliverNotification(notification: Notification): Promise<void> {
    const channels = notification.channels;
    let delivered = false;

    // WebSocket delivery
    if (channels.includes('websocket')) {
      delivered = await this.deliverViaWebSocket(notification) || delivered;
    }

    // Push notification delivery (placeholder)
    if (channels.includes('push')) {
      delivered = await this.deliverViaPush(notification) || delivered;
    }

    // Email delivery (placeholder)
    if (channels.includes('email')) {
      delivered = await this.deliverViaEmail(notification) || delivered;
    }

    // SMS delivery (placeholder)
    if (channels.includes('sms')) {
      delivered = await this.deliverViaSMS(notification) || delivered;
    }

    notification.status = delivered ? 'delivered' : 'failed';
    notification.sentAt = new Date();
    
    await this.storeNotification(notification);
  }

  private async deliverViaWebSocket(notification: Notification): Promise<boolean> {
    if (!notification.userId) return false;

    const ws = this.activeConnections.get(notification.userId);
    if (!ws || ws.readyState !== WebSocket.OPEN) {
      return false;
    }

    try {
      ws.send(JSON.stringify({
        type: 'notification',
        notification
      }));
      return true;
    } catch (error) {
      console.error('WebSocket delivery failed:', error);
      return false;
    }
  }

  private async deliverViaPush(notification: Notification): Promise<boolean> {
    // Placeholder for push notification implementation
    // This would integrate with services like Firebase FCM, APNs, etc.
    console.log(`Push notification sent: ${notification.title}`);
    return true;
  }

  private async deliverViaEmail(notification: Notification): Promise<boolean> {
    // Placeholder for email delivery implementation
    // This would integrate with services like SendGrid, AWS SES, etc.
    console.log(`Email sent: ${notification.title}`);
    return true;
  }

  private async deliverViaSMS(notification: Notification): Promise<boolean> {
    // Placeholder for SMS delivery implementation
    // This would integrate with services like Twilio, AWS SNS, etc.
    console.log(`SMS sent: ${notification.title}`);
    return true;
  }

  private shouldSendNotification(userId: string, notification: Partial<Notification>): boolean {
    const preferences = this.userPreferences.get(userId);
    if (!preferences) return false;

    // Check notification hours
    const now = new Date();
    const currentHour = now.getHours();
    
    if (currentHour < preferences.notificationHours.start || 
        currentHour > preferences.notificationHours.end) {
      return notification.priority === 'high'; // Only high priority outside hours
    }

    // Check daily limit
    // This would need to be implemented with Redis counters

    // Check category preferences
    if (notification.data?.product && preferences.categories.length > 0) {
      const productCategory = notification.data.product.category.main;
      return preferences.categories.includes(productCategory);
    }

    return true;
  }

  private async sendPendingNotifications(userId: string): Promise<void> {
    try {
      const pending = await this.redisClient.lRange(`pending_notifications:${userId}`, 0, -1);
      
      for (const notificationData of pending) {
        const notification: Notification = JSON.parse(notificationData);
        await this.deliverViaWebSocket(notification);
      }

      // Clear pending notifications
      await this.redisClient.del(`pending_notifications:${userId}`);
    } catch (error) {
      console.error(`Failed to send pending notifications for ${userId}:`, error);
    }
  }

  private async storeNotification(notification: Notification): Promise<void> {
    try {
      // Store individual notification
      await this.redisClient.hSet(
        'notifications',
        notification.id,
        JSON.stringify(notification)
      );

      // Add to user's notification list
      if (notification.userId) {
        await this.redisClient.lPush(
          `notifications:${notification.userId}`,
          JSON.stringify(notification)
        );

        // Keep only last 100 notifications per user
        await this.redisClient.lTrim(`notifications:${notification.userId}`, 0, 99);
      }
    } catch (error) {
      console.error(`Failed to store notification ${notification.id}:`, error);
    }
  }

  private async getNotification(notificationId: string): Promise<Notification | null> {
    try {
      const data = await this.redisClient.hGet('notifications', notificationId);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      console.error(`Failed to get notification ${notificationId}:`, error);
      return null;
    }
  }

  private async loadUserPreferences(): Promise<void> {
    try {
      const preferences = await this.redisClient.hGetAll('user_preferences');
      
      for (const [userId, prefData] of Object.entries(preferences)) {
        try {
          const pref: UserPreferences = JSON.parse(prefData);
          this.userPreferences.set(userId, pref);
        } catch (error) {
          console.error(`Failed to parse preferences for ${userId}:`, error);
        }
      }

      console.log(`Loaded preferences for ${this.userPreferences.size} users`);
    } catch (error) {
      console.error('Failed to load user preferences:', error);
    }
  }

  private handleWebSocketMessage(userId: string, message: any): void {
    switch (message.type) {
      case 'mark_read':
        if (message.notificationId) {
          this.markAsRead(message.notificationId, userId);
        }
        break;
      case 'update_preferences':
        if (message.preferences) {
          this.setUserPreferences(userId, message.preferences);
        }
        break;
      case 'get_unread_count':
        this.getUnreadCount(userId).then(count => {
          const ws = this.activeConnections.get(userId);
          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
              type: 'unread_count',
              count
            }));
          }
        });
        break;
    }
  }

  private generateNotificationId(): string {
    return `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  async shutdown(): Promise<void> {
    if (this.processingInterval) {
      clearInterval(this.processingInterval);
    }

    for (const ws of this.activeConnections.values()) {
      ws.close();
    }

    this.wsServer.close();
    await this.redisClient.disconnect();
    
    console.log('Notification service shut down');
  }
}