import { createHash, randomBytes } from 'crypto';
import { createClient, RedisClientType } from 'redis';
import { EventEmitter } from 'events';

export interface PrivacySettings {
  userId: string;
  anonymousMode: boolean;
  trackingOptOut: boolean;
  dataRetentionDays: number;
  shareWithPartners: boolean;
  personalizedAds: boolean;
  locationTracking: boolean;
  biometricData: boolean;
  searchHistory: boolean;
  purchaseHistory: boolean;
  priceAlerts: boolean;
  recommendations: boolean;
}

export interface AnonymousSession {
  sessionId: string;
  anonymousId: string;
  createdAt: Date;
  expiresAt: Date;
  preferences: {
    categories: string[];
    priceRange: { min: number; max: number };
    sustainabilityPreference: boolean;
  };
  searchHistory: string[]; // Hashed search terms
  interactions: {
    productViews: string[]; // Hashed product IDs
    comparisons: string[]; // Hashed product IDs
    priceChecks: string[]; // Hashed product IDs
  };
}

export interface DataExportRequest {
  userId: string;
  requestId: string;
  requestedAt: Date;
  dataTypes: string[];
  format: 'json' | 'csv' | 'xml';
  status: 'pending' | 'processing' | 'completed' | 'failed';
  downloadUrl?: string;
  expiresAt?: Date;
}

export class PrivacyManager extends EventEmitter {
  private redisClient: RedisClientType;
  private anonymousSessions: Map<string, AnonymousSession> = new Map();
  private activeDataExports: Map<string, DataExportRequest> = new Map();
  private cleanupInterval: NodeJS.Timeout | null = null;

  constructor() {
    super();
    this.redisClient = createClient({
      url: process.env.REDIS_URL || 'redis://localhost:6379'
    });
    this.initialize();
  }

  private async initialize(): Promise<void> {
    try {
      await this.redisClient.connect();
      await this.loadActiveSessions();
      this.startCleanupScheduler();
      console.log('Privacy manager initialized');
    } catch (error) {
      console.error('Failed to initialize privacy manager:', error);
    }
  }

  // Anonymous browsing functionality
  async createAnonymousSession(preferences?: Partial<AnonymousSession['preferences']>): Promise<string> {
    const sessionId = this.generateSecureId();
    const anonymousId = this.generateAnonymousId();
    
    const session: AnonymousSession = {
      sessionId,
      anonymousId,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
      preferences: {
        categories: preferences?.categories || [],
        priceRange: preferences?.priceRange || { min: 0, max: 1000 },
        sustainabilityPreference: preferences?.sustainabilityPreference || false
      },
      searchHistory: [],
      interactions: {
        productViews: [],
        comparisons: [],
        priceChecks: []
      }
    };

    this.anonymousSessions.set(sessionId, session);
    
    // Store in Redis with expiration
    await this.redisClient.setEx(
      `anonymous_session:${sessionId}`,
      24 * 60 * 60, // 24 hours in seconds
      JSON.stringify(session)
    );

    console.log(`Anonymous session created: ${sessionId}`);
    return sessionId;
  }

  async getAnonymousSession(sessionId: string): Promise<AnonymousSession | null> {
    let session = this.anonymousSessions.get(sessionId);
    
    if (!session) {
      try {
        const sessionData = await this.redisClient.get(`anonymous_session:${sessionId}`);
        if (sessionData) {
          session = JSON.parse(sessionData);
          this.anonymousSessions.set(sessionId, session!);
        }
      } catch (error) {
        console.error(`Failed to retrieve anonymous session ${sessionId}:`, error);
        return null;
      }
    }

    if (session && new Date() > session.expiresAt) {
      await this.deleteAnonymousSession(sessionId);
      return null;
    }

    return session || null;
  }

  async updateAnonymousSession(
    sessionId: string,
    updates: Partial<Omit<AnonymousSession, 'sessionId' | 'anonymousId' | 'createdAt'>>
  ): Promise<boolean> {
    const session = await this.getAnonymousSession(sessionId);
    if (!session) return false;

    const updatedSession = { ...session, ...updates };
    this.anonymousSessions.set(sessionId, updatedSession);
    
    await this.redisClient.setEx(
      `anonymous_session:${sessionId}`,
      Math.floor((session.expiresAt.getTime() - Date.now()) / 1000),
      JSON.stringify(updatedSession)
    );

    return true;
  }

  async deleteAnonymousSession(sessionId: string): Promise<void> {
    this.anonymousSessions.delete(sessionId);
    await this.redisClient.del(`anonymous_session:${sessionId}`);
    console.log(`Anonymous session deleted: ${sessionId}`);
  }

  // Privacy settings management
  async getPrivacySettings(userId: string): Promise<PrivacySettings> {
    try {
      const settings = await this.redisClient.hGet('privacy_settings', userId);
      
      if (settings) {
        return JSON.parse(settings);
      }

      // Return default privacy settings (privacy-first)
      const defaultSettings: PrivacySettings = {
        userId,
        anonymousMode: true,
        trackingOptOut: true,
        dataRetentionDays: 30,
        shareWithPartners: false,
        personalizedAds: false,
        locationTracking: false,
        biometricData: false,
        searchHistory: false,
        purchaseHistory: false,
        priceAlerts: true, // This is useful and relatively privacy-safe
        recommendations: false
      };

      await this.setPrivacySettings(userId, defaultSettings);
      return defaultSettings;
    } catch (error) {
      console.error(`Failed to get privacy settings for ${userId}:`, error);
      throw error;
    }
  }

  async setPrivacySettings(userId: string, settings: PrivacySettings): Promise<void> {
    try {
      await this.redisClient.hSet('privacy_settings', userId, JSON.stringify(settings));
      
      // Emit event for other services to update their behavior
      this.emit('privacySettingsUpdated', { userId, settings });
      
      console.log(`Privacy settings updated for user ${userId}`);
    } catch (error) {
      console.error(`Failed to set privacy settings for ${userId}:`, error);
      throw error;
    }
  }

  // Data anonymization
  hashData(data: string, salt?: string): string {
    const actualSalt = salt || this.getGlobalSalt();
    return createHash('sha256').update(data + actualSalt).digest('hex');
  }

  anonymizeProductId(productId: string, sessionId?: string): string {
    const salt = sessionId || this.getGlobalSalt();
    return this.hashData(productId, salt);
  }

  anonymizeSearchQuery(query: string, sessionId?: string): string {
    const salt = sessionId || this.getGlobalSalt();
    return this.hashData(query.toLowerCase().trim(), salt);
  }

  // No tracking pixel functionality
  generateSecureImageProxy(originalUrl: string): string {
    // Create a secure proxy URL that strips tracking parameters
    const cleanUrl = this.removeTrackingParameters(originalUrl);
    const proxyToken = this.generateProxyToken(cleanUrl);
    
    return `/api/image-proxy/${proxyToken}`;
  }

  private removeTrackingParameters(url: string): string {
    try {
      const urlObj = new URL(url);
      
      // Common tracking parameters to remove
      const trackingParams = [
        'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
        'fbclid', 'gclid', 'msclkid', 'mc_eid', 'mc_cid',
        '_ga', '_gid', '_gac', 'gclsrc',
        'ref', 'referer', 'referrer'
      ];

      trackingParams.forEach(param => {
        urlObj.searchParams.delete(param);
      });

      return urlObj.toString();
    } catch (error) {
      console.error('Invalid URL for tracking parameter removal:', url);
      return url;
    }
  }

  private generateProxyToken(url: string): string {
    const hash = createHash('sha256').update(url + this.getGlobalSalt()).digest('hex');
    return hash.substring(0, 16);
  }

  // Secure checkout redirect
  generateSecureCheckoutUrl(originalUrl: string, sessionId?: string): string {
    try {
      const cleanUrl = this.removeTrackingParameters(originalUrl);
      const urlObj = new URL(cleanUrl);
      
      // Add privacy parameters
      urlObj.searchParams.set('privacy_mode', '1');
      urlObj.searchParams.set('no_tracking', '1');
      
      if (sessionId) {
        // Add session reference for order tracking without personal data
        const sessionHash = this.hashData(sessionId).substring(0, 8);
        urlObj.searchParams.set('session_ref', sessionHash);
      }

      return urlObj.toString();
    } catch (error) {
      console.error('Invalid checkout URL:', originalUrl);
      return originalUrl;
    }
  }

  // Data export functionality (GDPR compliance)
  async requestDataExport(
    userId: string,
    dataTypes: string[],
    format: 'json' | 'csv' | 'xml' = 'json'
  ): Promise<string> {
    const requestId = this.generateSecureId();
    
    const exportRequest: DataExportRequest = {
      userId,
      requestId,
      requestedAt: new Date(),
      dataTypes,
      format,
      status: 'pending'
    };

    this.activeDataExports.set(requestId, exportRequest);
    
    // Store in Redis
    await this.redisClient.hSet(
      'data_export_requests',
      requestId,
      JSON.stringify(exportRequest)
    );

    // Schedule processing (in a real implementation, this would be a background job)
    setTimeout(() => this.processDataExport(requestId), 1000);

    console.log(`Data export requested: ${requestId} for user ${userId}`);
    return requestId;
  }

  async getDataExportStatus(requestId: string): Promise<DataExportRequest | null> {
    let request = this.activeDataExports.get(requestId);
    
    if (!request) {
      try {
        const requestData = await this.redisClient.hGet('data_export_requests', requestId);
        if (requestData) {
          request = JSON.parse(requestData);
        }
      } catch (error) {
        console.error(`Failed to get data export status ${requestId}:`, error);
      }
    }

    return request || null;
  }

  private async processDataExport(requestId: string): Promise<void> {
    try {
      const request = await this.getDataExportStatus(requestId);
      if (!request) return;

      request.status = 'processing';
      await this.updateDataExportRequest(request);

      // Collect user data based on requested types
      const userData: any = {};

      for (const dataType of request.dataTypes) {
        switch (dataType) {
          case 'search_history':
            userData.searchHistory = await this.getUserSearchHistory(request.userId);
            break;
          case 'price_alerts':
            userData.priceAlerts = await this.getUserPriceAlerts(request.userId);
            break;
          case 'preferences':
            userData.preferences = await this.getPrivacySettings(request.userId);
            break;
          case 'interactions':
            userData.interactions = await this.getUserInteractions(request.userId);
            break;
        }
      }

      // Generate export file
      const exportData = this.formatExportData(userData, request.format);
      const downloadUrl = await this.saveExportFile(requestId, exportData, request.format);

      request.status = 'completed';
      request.downloadUrl = downloadUrl;
      request.expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

      await this.updateDataExportRequest(request);

      console.log(`Data export completed: ${requestId}`);
      this.emit('dataExportCompleted', request);

    } catch (error) {
      console.error(`Data export failed: ${requestId}`, error);
      
      const request = await this.getDataExportStatus(requestId);
      if (request) {
        request.status = 'failed';
        await this.updateDataExportRequest(request);
      }
    }
  }

  // Data deletion (Right to be forgotten)
  async deleteUserData(userId: string, dataTypes?: string[]): Promise<boolean> {
    try {
      const settings = await this.getPrivacySettings(userId);
      const typesToDelete = dataTypes || [
        'search_history', 'price_alerts', 'preferences', 
        'interactions', 'export_requests'
      ];

      for (const dataType of typesToDelete) {
        switch (dataType) {
          case 'search_history':
            await this.redisClient.del(`search_history:${userId}`);
            break;
          case 'price_alerts':
            await this.redisClient.del(`price_alerts:${userId}`);
            break;
          case 'preferences':
            await this.redisClient.hDel('privacy_settings', userId);
            break;
          case 'interactions':
            await this.redisClient.del(`interactions:${userId}`);
            break;
          case 'export_requests':
            // Delete all export requests for this user
            const allRequests = await this.redisClient.hGetAll('data_export_requests');
            for (const [reqId, reqData] of Object.entries(allRequests)) {
              try {
                const request: DataExportRequest = JSON.parse(reqData);
                if (request.userId === userId) {
                  await this.redisClient.hDel('data_export_requests', reqId);
                }
              } catch (e) {
                console.error(`Failed to parse export request ${reqId}:`, e);
              }
            }
            break;
        }
      }

      console.log(`User data deleted for ${userId}: ${typesToDelete.join(', ')}`);
      this.emit('userDataDeleted', { userId, dataTypes: typesToDelete });
      
      return true;
    } catch (error) {
      console.error(`Failed to delete user data for ${userId}:`, error);
      return false;
    }
  }

  // Helper methods
  private generateSecureId(): string {
    return randomBytes(16).toString('hex');
  }

  private generateAnonymousId(): string {
    return 'anon_' + randomBytes(12).toString('hex');
  }

  private getGlobalSalt(): string {
    return process.env.PRIVACY_SALT || 'default_salt_change_in_production';
  }

  private async loadActiveSessions(): Promise<void> {
    try {
      const keys = await this.redisClient.keys('anonymous_session:*');
      
      for (const key of keys) {
        const sessionData = await this.redisClient.get(key);
        if (sessionData) {
          const session: AnonymousSession = JSON.parse(sessionData);
          this.anonymousSessions.set(session.sessionId, session);
        }
      }

      console.log(`Loaded ${this.anonymousSessions.size} active anonymous sessions`);
    } catch (error) {
      console.error('Failed to load active sessions:', error);
    }
  }

  private startCleanupScheduler(): void {
    this.cleanupInterval = setInterval(async () => {
      await this.cleanupExpiredSessions();
      await this.cleanupExpiredExports();
    }, 60 * 60 * 1000); // Run every hour
  }

  private async cleanupExpiredSessions(): Promise<void> {
    const now = new Date();
    const expiredSessions: string[] = [];

    for (const [sessionId, session] of this.anonymousSessions) {
      if (now > session.expiresAt) {
        expiredSessions.push(sessionId);
      }
    }

    for (const sessionId of expiredSessions) {
      await this.deleteAnonymousSession(sessionId);
    }

    if (expiredSessions.length > 0) {
      console.log(`Cleaned up ${expiredSessions.length} expired sessions`);
    }
  }

  private async cleanupExpiredExports(): Promise<void> {
    const allRequests = await this.redisClient.hGetAll('data_export_requests');
    const expiredRequests: string[] = [];
    const now = new Date();

    for (const [requestId, requestData] of Object.entries(allRequests)) {
      try {
        const request: DataExportRequest = JSON.parse(requestData);
        if (request.expiresAt && now > new Date(request.expiresAt)) {
          expiredRequests.push(requestId);
        }
      } catch (e) {
        console.error(`Failed to parse export request ${requestId}:`, e);
        expiredRequests.push(requestId); // Remove corrupted data
      }
    }

    for (const requestId of expiredRequests) {
      await this.redisClient.hDel('data_export_requests', requestId);
      this.activeDataExports.delete(requestId);
    }

    if (expiredRequests.length > 0) {
      console.log(`Cleaned up ${expiredRequests.length} expired export requests`);
    }
  }

  private async updateDataExportRequest(request: DataExportRequest): Promise<void> {
    this.activeDataExports.set(request.requestId, request);
    await this.redisClient.hSet(
      'data_export_requests',
      request.requestId,
      JSON.stringify(request)
    );
  }

  private formatExportData(data: any, format: string): string {
    switch (format) {
      case 'json':
        return JSON.stringify(data, null, 2);
      case 'csv':
        // Simple CSV implementation - would need proper CSV library for complex data
        return this.convertToCSV(data);
      case 'xml':
        return this.convertToXML(data);
      default:
        return JSON.stringify(data, null, 2);
    }
  }

  private convertToCSV(data: any): string {
    // Simplified CSV conversion
    // In production, use a proper CSV library
    return 'CSV export not fully implemented';
  }

  private convertToXML(data: any): string {
    // Simplified XML conversion
    // In production, use a proper XML library
    return '<xml>XML export not fully implemented</xml>';
  }

  private async saveExportFile(
    requestId: string,
    data: string,
    format: string
  ): Promise<string> {
    // In production, this would save to secure cloud storage
    // For now, return a mock URL
    return `/api/exports/${requestId}.${format}`;
  }

  // Mock methods for user data retrieval
  private async getUserSearchHistory(userId: string): Promise<any[]> {
    try {
      const history = await this.redisClient.lRange(`search_history:${userId}`, 0, -1);
      return history.map(h => JSON.parse(h));
    } catch (error) {
      return [];
    }
  }

  private async getUserPriceAlerts(userId: string): Promise<any[]> {
    try {
      const alerts = await this.redisClient.lRange(`price_alerts:${userId}`, 0, -1);
      return alerts.map(a => JSON.parse(a));
    } catch (error) {
      return [];
    }
  }

  private async getUserInteractions(userId: string): Promise<any[]> {
    try {
      const interactions = await this.redisClient.lRange(`interactions:${userId}`, 0, -1);
      return interactions.map(i => JSON.parse(i));
    } catch (error) {
      return [];
    }
  }

  async shutdown(): Promise<void> {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }
    await this.redisClient.disconnect();
    console.log('Privacy manager shut down');
  }
}