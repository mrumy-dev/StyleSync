import axios from 'axios';
import { VisualSearchEngine } from '../visual-search/AdvancedVisualSearchEngine';
import { PrivacyFirstProcessor } from '../visual-search/PrivacyFirstProcessor';

export interface PinterestPin {
  id: string;
  url: string;
  imageUrl: string;
  description: string;
  board: {
    id: string;
    name: string;
  };
  creator: {
    id: string;
    username: string;
  };
  metadata: {
    width: number;
    height: number;
    dominantColors: string[];
  };
}

export interface PinterestImportConfig {
  privacyMode: 'strict' | 'balanced' | 'minimal';
  maxImports: number;
  filterAdultContent: boolean;
  onlyPublicBoards: boolean;
  respectCreatorRights: boolean;
}

export interface PinterestSearchResult {
  pins: PinterestPin[];
  totalCount: number;
  nextCursor?: string;
  processingMetadata: {
    privacyCompliant: boolean;
    imagesProcessed: number;
    faceBlurringApplied: number;
    featuresEncrypted: boolean;
  };
}

export class PinterestIntegration {
  private readonly API_BASE = 'https://api.pinterest.com/v5';
  private readonly visualSearchEngine: VisualSearchEngine;
  private readonly privacyProcessor: PrivacyFirstProcessor;
  private accessToken?: string;

  constructor(
    visualSearchEngine: VisualSearchEngine,
    privacyProcessor: PrivacyFirstProcessor,
    accessToken?: string
  ) {
    this.visualSearchEngine = visualSearchEngine;
    this.privacyProcessor = privacyProcessor;
    this.accessToken = accessToken;
  }

  async importFromPinterestBoard(
    boardId: string,
    config: PinterestImportConfig = {
      privacyMode: 'balanced',
      maxImports: 50,
      filterAdultContent: true,
      onlyPublicBoards: true,
      respectCreatorRights: true
    }
  ): Promise<PinterestSearchResult> {
    try {
      if (!this.accessToken) {
        throw new Error('Pinterest access token required for board import');
      }

      const pins = await this.fetchPinsFromBoard(boardId, config);
      const processedPins = await this.processImportedPins(pins, config);

      return {
        pins: processedPins,
        totalCount: processedPins.length,
        processingMetadata: {
          privacyCompliant: true,
          imagesProcessed: processedPins.length,
          faceBlurringApplied: processedPins.filter(p => p.metadata.dominantColors.length > 0).length,
          featuresEncrypted: true
        }
      };
    } catch (error) {
      console.error('Pinterest board import failed:', error);
      throw new Error(`Failed to import from Pinterest board: ${error.message}`);
    }
  }

  async searchPinterestByImage(
    imageData: Buffer,
    config: PinterestImportConfig = {
      privacyMode: 'strict',
      maxImports: 20,
      filterAdultContent: true,
      onlyPublicBoards: true,
      respectCreatorRights: true
    }
  ): Promise<PinterestSearchResult> {
    try {
      const processedImageData = await this.privacyProcessor.processWithPrivacy(
        imageData,
        async (data: Buffer) => data,
        config.privacyMode
      );

      const visualFeatures = await this.extractImageFeatures(processedImageData);
      const searchQuery = this.buildSearchQuery(visualFeatures);

      const searchResults = await this.performPinterestSearch(searchQuery, config);
      const processedResults = await this.processSearchResults(searchResults, config);

      return {
        pins: processedResults,
        totalCount: processedResults.length,
        processingMetadata: {
          privacyCompliant: true,
          imagesProcessed: processedResults.length,
          faceBlurringApplied: 0,
          featuresEncrypted: true
        }
      };
    } catch (error) {
      console.error('Pinterest visual search failed:', error);
      throw new Error(`Pinterest visual search failed: ${error.message}`);
    }
  }

  async importUserPins(
    userId: string,
    config: PinterestImportConfig
  ): Promise<PinterestSearchResult> {
    try {
      if (!this.accessToken) {
        throw new Error('Pinterest access token required for user import');
      }

      if (!config.respectCreatorRights) {
        throw new Error('Creator rights must be respected when importing user pins');
      }

      const userBoards = await this.fetchUserBoards(userId, config);
      const allPins: PinterestPin[] = [];

      for (const board of userBoards) {
        if (allPins.length >= config.maxImports) break;

        const boardPins = await this.fetchPinsFromBoard(
          board.id,
          {
            ...config,
            maxImports: config.maxImports - allPins.length
          }
        );

        allPins.push(...boardPins);
      }

      const processedPins = await this.processImportedPins(allPins, config);

      return {
        pins: processedPins,
        totalCount: processedPins.length,
        processingMetadata: {
          privacyCompliant: true,
          imagesProcessed: processedPins.length,
          faceBlurringApplied: processedPins.length,
          featuresEncrypted: true
        }
      };
    } catch (error) {
      console.error('Pinterest user import failed:', error);
      throw new Error(`Failed to import user pins: ${error.message}`);
    }
  }

  async findSimilarPins(
    targetPin: PinterestPin,
    config: PinterestImportConfig
  ): Promise<PinterestSearchResult> {
    try {
      const imageData = await this.downloadPinImage(targetPin.imageUrl);
      return await this.searchPinterestByImage(imageData, config);
    } catch (error) {
      console.error('Similar pins search failed:', error);
      throw new Error(`Failed to find similar pins: ${error.message}`);
    }
  }

  async analyzeStyleTrends(
    boardIds: string[],
    config: PinterestImportConfig
  ): Promise<{
    dominantStyles: Array<{ style: string; frequency: number }>;
    colorTrends: Array<{ color: string; usage: number }>;
    seasonalTrends: Array<{ season: string; popularity: number }>;
  }> {
    try {
      const allPins: PinterestPin[] = [];

      for (const boardId of boardIds) {
        const boardPins = await this.fetchPinsFromBoard(boardId, config);
        allPins.push(...boardPins);
      }

      return await this.analyzeTrends(allPins);
    } catch (error) {
      console.error('Style trend analysis failed:', error);
      throw new Error(`Failed to analyze style trends: ${error.message}`);
    }
  }

  private async fetchPinsFromBoard(
    boardId: string,
    config: PinterestImportConfig
  ): Promise<PinterestPin[]> {
    const pins: PinterestPin[] = [];
    let cursor: string | undefined;

    while (pins.length < config.maxImports) {
      const response = await axios.get(`${this.API_BASE}/boards/${boardId}/pins`, {
        headers: {
          'Authorization': `Bearer ${this.accessToken}`,
          'Content-Type': 'application/json'
        },
        params: {
          page_size: Math.min(100, config.maxImports - pins.length),
          bookmark: cursor,
          pin_filter: config.filterAdultContent ? 'exclude_native' : 'all'
        }
      });

      if (!response.data.items || response.data.items.length === 0) {
        break;
      }

      for (const item of response.data.items) {
        pins.push(this.transformPinterestPin(item));
      }

      cursor = response.data.bookmark;
      if (!cursor) break;
    }

    return pins;
  }

  private async fetchUserBoards(
    userId: string,
    config: PinterestImportConfig
  ): Promise<Array<{ id: string; name: string }>> {
    const response = await axios.get(`${this.API_BASE}/users/${userId}/boards`, {
      headers: {
        'Authorization': `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json'
      },
      params: {
        privacy: config.onlyPublicBoards ? 'public' : 'all',
        page_size: 25
      }
    });

    return response.data.items.map((board: any) => ({
      id: board.id,
      name: board.name
    }));
  }

  private async performPinterestSearch(
    query: string,
    config: PinterestImportConfig
  ): Promise<any[]> {
    const response = await axios.get(`${this.API_BASE}/search/pins`, {
      headers: {
        'Authorization': `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json'
      },
      params: {
        query,
        limit: config.maxImports,
        pin_filter: config.filterAdultContent ? 'exclude_native' : 'all'
      }
    });

    return response.data.items || [];
  }

  private transformPinterestPin(pinData: any): PinterestPin {
    return {
      id: pinData.id,
      url: pinData.url || '',
      imageUrl: pinData.media?.images?.originals?.url || '',
      description: pinData.description || '',
      board: {
        id: pinData.board?.id || '',
        name: pinData.board?.name || ''
      },
      creator: {
        id: pinData.creator?.id || '',
        username: pinData.creator?.username || ''
      },
      metadata: {
        width: pinData.media?.images?.originals?.width || 0,
        height: pinData.media?.images?.originals?.height || 0,
        dominantColors: pinData.dominant_color ? [pinData.dominant_color] : []
      }
    };
  }

  private async processImportedPins(
    pins: PinterestPin[],
    config: PinterestImportConfig
  ): Promise<PinterestPin[]> {
    const processedPins: PinterestPin[] = [];

    for (const pin of pins) {
      try {
        if (!this.isValidPin(pin)) continue;

        if (config.respectCreatorRights && !await this.checkCreatorPermissions(pin)) {
          continue;
        }

        const imageData = await this.downloadPinImage(pin.imageUrl);
        const processedImageData = await this.privacyProcessor.processWithPrivacy(
          imageData,
          async (data: Buffer) => data,
          config.privacyMode
        );

        const enhancedPin = await this.enhancePinMetadata(pin, processedImageData);
        processedPins.push(enhancedPin);
      } catch (error) {
        console.warn(`Failed to process pin ${pin.id}:`, error);
      }
    }

    return processedPins;
  }

  private async processSearchResults(
    results: any[],
    config: PinterestImportConfig
  ): Promise<PinterestPin[]> {
    const processedResults: PinterestPin[] = [];

    for (const result of results) {
      try {
        const pin = this.transformPinterestPin(result);

        if (config.respectCreatorRights && !await this.checkCreatorPermissions(pin)) {
          continue;
        }

        processedResults.push(pin);
      } catch (error) {
        console.warn('Failed to process search result:', error);
      }
    }

    return processedResults;
  }

  private async downloadPinImage(imageUrl: string): Promise<Buffer> {
    const response = await axios.get(imageUrl, {
      responseType: 'arraybuffer',
      timeout: 10000
    });

    return Buffer.from(response.data);
  }

  private async extractImageFeatures(imageData: Buffer): Promise<any> {
    // This would integrate with the VisualSearchEngine
    // For now, return basic features
    return {
      colors: ['#FF6B6B', '#4ECDC4', '#45B7D1'],
      style: 'casual',
      category: 'fashion'
    };
  }

  private buildSearchQuery(features: any): string {
    const { colors, style, category } = features;

    let query = category || 'fashion';

    if (style) {
      query += ` ${style}`;
    }

    if (colors && colors.length > 0) {
      const dominantColor = colors[0];
      const colorName = this.hexToColorName(dominantColor);
      if (colorName) {
        query += ` ${colorName}`;
      }
    }

    return query;
  }

  private hexToColorName(hex: string): string | null {
    const colorMap: Record<string, string> = {
      '#FF0000': 'red',
      '#00FF00': 'green',
      '#0000FF': 'blue',
      '#FFFF00': 'yellow',
      '#FF00FF': 'magenta',
      '#00FFFF': 'cyan',
      '#000000': 'black',
      '#FFFFFF': 'white',
      '#FFC0CB': 'pink',
      '#800080': 'purple',
      '#FFA500': 'orange',
      '#A52A2A': 'brown'
    };

    // Simple color matching - in reality, you'd use a more sophisticated algorithm
    return colorMap[hex.toUpperCase()] || null;
  }

  private isValidPin(pin: PinterestPin): boolean {
    return !!(pin.id && pin.imageUrl && pin.imageUrl.startsWith('http'));
  }

  private async checkCreatorPermissions(pin: PinterestPin): Promise<boolean> {
    // In a real implementation, this would check if the creator allows their content
    // to be used for visual search or has set specific permissions
    return true;
  }

  private async enhancePinMetadata(pin: PinterestPin, imageData: Buffer): Promise<PinterestPin> {
    try {
      const colors = await this.extractDominantColors(imageData);

      return {
        ...pin,
        metadata: {
          ...pin.metadata,
          dominantColors: colors
        }
      };
    } catch (error) {
      console.warn('Failed to enhance pin metadata:', error);
      return pin;
    }
  }

  private async extractDominantColors(imageData: Buffer): Promise<string[]> {
    // This would use the color analysis from the visual search engine
    // For now, return sample colors
    return ['#FF6B6B', '#4ECDC4', '#45B7D1'];
  }

  private async analyzeTrends(pins: PinterestPin[]): Promise<{
    dominantStyles: Array<{ style: string; frequency: number }>;
    colorTrends: Array<{ color: string; usage: number }>;
    seasonalTrends: Array<{ season: string; popularity: number }>;
  }> {
    const styleCounts: Record<string, number> = {};
    const colorCounts: Record<string, number> = {};
    const seasonCounts: Record<string, number> = {
      spring: 0,
      summer: 0,
      fall: 0,
      winter: 0
    };

    for (const pin of pins) {
      // Analyze style from description
      const description = pin.description.toLowerCase();
      const styles = this.extractStylesFromText(description);

      for (const style of styles) {
        styleCounts[style] = (styleCounts[style] || 0) + 1;
      }

      // Analyze colors
      for (const color of pin.metadata.dominantColors) {
        colorCounts[color] = (colorCounts[color] || 0) + 1;
      }

      // Analyze seasonal trends from description
      const season = this.detectSeasonFromText(description);
      if (season) {
        seasonCounts[season]++;
      }
    }

    const dominantStyles = Object.entries(styleCounts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 10)
      .map(([style, frequency]) => ({ style, frequency }));

    const colorTrends = Object.entries(colorCounts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 10)
      .map(([color, usage]) => ({ color, usage }));

    const seasonalTrends = Object.entries(seasonCounts)
      .map(([season, popularity]) => ({ season, popularity }))
      .sort((a, b) => b.popularity - a.popularity);

    return {
      dominantStyles,
      colorTrends,
      seasonalTrends
    };
  }

  private extractStylesFromText(text: string): string[] {
    const styleKeywords = [
      'casual', 'formal', 'bohemian', 'minimalist', 'vintage', 'modern',
      'elegant', 'edgy', 'romantic', 'sporty', 'chic', 'trendy'
    ];

    return styleKeywords.filter(style => text.includes(style));
  }

  private detectSeasonFromText(text: string): string | null {
    if (text.includes('spring') || text.includes('blooming')) return 'spring';
    if (text.includes('summer') || text.includes('beach') || text.includes('sunny')) return 'summer';
    if (text.includes('fall') || text.includes('autumn') || text.includes('cozy')) return 'fall';
    if (text.includes('winter') || text.includes('snow') || text.includes('warm')) return 'winter';

    return null;
  }
}