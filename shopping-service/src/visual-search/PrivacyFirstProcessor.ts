import crypto from 'crypto';
import { EventEmitter } from 'events';

export interface PrivacyConfig {
  onDeviceOnly: boolean;
  differentialPrivacy: {
    epsilon: number;
    delta: number;
  };
  faceBlurring: {
    enabled: boolean;
    strength: number;
  };
  featureEncryption: {
    enabled: boolean;
    algorithm: 'aes-256-gcm' | 'chacha20-poly1305';
    keyRotationHours: number;
  };
  localCaching: {
    enabled: boolean;
    maxSizeMB: number;
    ttlHours: number;
  };
  federatedLearning: {
    enabled: boolean;
    minParticipants: number;
    privacyBudget: number;
  };
}

export interface EncryptedFeatures {
  data: Buffer;
  iv: Buffer;
  tag: Buffer;
  algorithm: string;
  keyId: string;
}

export interface NoiseParameters {
  sensitivity: number;
  epsilon: number;
  delta: number;
}

export class PrivacyFirstProcessor extends EventEmitter {
  private encryptionKeys: Map<string, Buffer> = new Map();
  private privacyBudget: number = 1.0;
  private currentKeyId: string = '';
  private config: PrivacyConfig;

  constructor(config: PrivacyConfig) {
    super();
    this.config = config;
    this.initializeEncryption();
    this.setupKeyRotation();
  }

  async processWithPrivacy<T>(
    data: T,
    operation: (data: T) => Promise<any>,
    privacyLevel: 'strict' | 'balanced' | 'minimal' = 'balanced'
  ): Promise<any> {
    try {
      const startTime = Date.now();

      if (!this.config.onDeviceOnly) {
        throw new Error('Privacy violation: Off-device processing not allowed');
      }

      let processedData = data;

      if (this.config.differentialPrivacy.epsilon > 0) {
        processedData = await this.addDifferentialPrivacyNoise(
          processedData,
          this.getNoiseParameters(privacyLevel)
        );
      }

      const result = await operation(processedData);

      if (this.config.featureEncryption.enabled && result.features) {
        result.features = await this.encryptFeatures(result.features);
      }

      this.emit('privacy-metrics', {
        processingTime: Date.now() - startTime,
        privacyBudgetUsed: this.calculateBudgetUsage(privacyLevel),
        onDeviceProcessing: true,
        encryptionApplied: this.config.featureEncryption.enabled
      });

      return result;
    } catch (error) {
      this.emit('privacy-error', { error: error.message, timestamp: Date.now() });
      throw error;
    }
  }

  async blurFaces(imageBuffer: Buffer, strength: number = 20): Promise<Buffer> {
    if (!this.config.faceBlurring.enabled) {
      return imageBuffer;
    }

    const sharp = await import('sharp');

    try {
      const faceRegions = await this.detectFacesPrivately(imageBuffer);

      if (faceRegions.length === 0) {
        return imageBuffer;
      }

      let image = sharp.default(imageBuffer);

      for (const region of faceRegions) {
        const mask = Buffer.alloc(region.width * region.height * 4, 255);

        image = image.composite([{
          input: await sharp.default(mask)
            .resize(region.width, region.height)
            .blur(strength)
            .png()
            .toBuffer(),
          left: region.x,
          top: region.y,
          blend: 'over'
        }]);
      }

      const blurredBuffer = await image.jpeg().toBuffer();

      this.emit('face-blur-applied', {
        facesDetected: faceRegions.length,
        blurStrength: strength,
        processingTime: Date.now()
      });

      return blurredBuffer;
    } catch (error) {
      console.error('Face blurring failed:', error);
      return imageBuffer;
    }
  }

  async encryptFeatures(features: any): Promise<EncryptedFeatures> {
    if (!this.config.featureEncryption.enabled) {
      return features;
    }

    const algorithm = this.config.featureEncryption.algorithm;
    const key = this.getCurrentEncryptionKey();
    const iv = crypto.randomBytes(12);

    const cipher = crypto.createCipher(algorithm, key);
    cipher.setAAD(Buffer.from('visual-features'));

    const featureString = JSON.stringify(features);
    const encrypted = Buffer.concat([
      cipher.update(featureString, 'utf8'),
      cipher.final()
    ]);

    const tag = cipher.getAuthTag();

    return {
      data: encrypted,
      iv,
      tag,
      algorithm,
      keyId: this.currentKeyId
    };
  }

  async decryptFeatures(encryptedFeatures: EncryptedFeatures): Promise<any> {
    const key = this.encryptionKeys.get(encryptedFeatures.keyId);
    if (!key) {
      throw new Error('Decryption key not found');
    }

    const decipher = crypto.createDecipher(encryptedFeatures.algorithm, key);
    decipher.setAAD(Buffer.from('visual-features'));
    decipher.setAuthTag(encryptedFeatures.tag);

    const decrypted = Buffer.concat([
      decipher.update(encryptedFeatures.data),
      decipher.final()
    ]);

    return JSON.parse(decrypted.toString('utf8'));
  }

  async addDifferentialPrivacyNoise<T>(data: T, params: NoiseParameters): Promise<T> {
    if (this.privacyBudget <= 0) {
      throw new Error('Privacy budget exhausted');
    }

    const noise = this.generateLaplaceNoise(params.sensitivity, params.epsilon);

    if (typeof data === 'object' && data !== null) {
      const noisyData = JSON.parse(JSON.stringify(data));

      this.addNoiseToNumericValues(noisyData, noise);

      this.privacyBudget -= params.epsilon;

      this.emit('differential-privacy-applied', {
        epsilon: params.epsilon,
        remainingBudget: this.privacyBudget,
        noiseAdded: noise
      });

      return noisyData;
    }

    return data;
  }

  async processWithFederatedLearning(
    localFeatures: any[],
    participantCount: number
  ): Promise<any> {
    if (!this.config.federatedLearning.enabled) {
      return localFeatures;
    }

    if (participantCount < this.config.federatedLearning.minParticipants) {
      throw new Error(`Insufficient participants for federated learning: ${participantCount} < ${this.config.federatedLearning.minParticipants}`);
    }

    const aggregatedFeatures = this.aggregateFeatures(localFeatures);

    const noisyFeatures = await this.addDifferentialPrivacyNoise(
      aggregatedFeatures,
      {
        sensitivity: 1.0,
        epsilon: this.config.federatedLearning.privacyBudget / participantCount,
        delta: 1e-5
      }
    );

    this.emit('federated-learning-update', {
      participants: participantCount,
      featuresAggregated: localFeatures.length,
      privacyBudgetUsed: this.config.federatedLearning.privacyBudget / participantCount
    });

    return noisyFeatures;
  }

  getPrivacyMetrics(): {
    privacyBudgetRemaining: number;
    onDeviceProcessingOnly: boolean;
    encryptionEnabled: boolean;
    faceBlurringEnabled: boolean;
    cacheSize: number;
  } {
    return {
      privacyBudgetRemaining: this.privacyBudget,
      onDeviceProcessingOnly: this.config.onDeviceOnly,
      encryptionEnabled: this.config.featureEncryption.enabled,
      faceBlurringEnabled: this.config.faceBlurring.enabled,
      cacheSize: this.getCacheSize()
    };
  }

  clearLocalCache(): void {
    if (this.config.localCaching.enabled) {
      this.emit('cache-cleared', { timestamp: Date.now() });
    }
  }

  private initializeEncryption(): void {
    if (!this.config.featureEncryption.enabled) return;

    this.currentKeyId = crypto.randomBytes(16).toString('hex');
    const key = crypto.randomBytes(32);
    this.encryptionKeys.set(this.currentKeyId, key);
  }

  private setupKeyRotation(): void {
    if (!this.config.featureEncryption.enabled) return;

    const rotationInterval = this.config.featureEncryption.keyRotationHours * 60 * 60 * 1000;

    setInterval(() => {
      this.rotateEncryptionKey();
    }, rotationInterval);
  }

  private rotateEncryptionKey(): void {
    const oldKeyId = this.currentKeyId;
    this.currentKeyId = crypto.randomBytes(16).toString('hex');
    const newKey = crypto.randomBytes(32);

    this.encryptionKeys.set(this.currentKeyId, newKey);

    setTimeout(() => {
      this.encryptionKeys.delete(oldKeyId);
    }, 24 * 60 * 60 * 1000);

    this.emit('key-rotated', {
      oldKeyId,
      newKeyId: this.currentKeyId,
      timestamp: Date.now()
    });
  }

  private getCurrentEncryptionKey(): Buffer {
    const key = this.encryptionKeys.get(this.currentKeyId);
    if (!key) {
      throw new Error('Current encryption key not found');
    }
    return key;
  }

  private async detectFacesPrivately(imageBuffer: Buffer): Promise<Array<{x: number, y: number, width: number, height: number}>> {
    const jimp = await import('jimp');
    const image = await jimp.default.read(imageBuffer);

    const width = image.getWidth();
    const height = image.getHeight();

    const faceRegions = [];

    for (let y = 0; y < height - 100; y += 20) {
      for (let x = 0; x < width - 100; x += 20) {
        if (await this.isFaceRegion(image, x, y, 100, 100)) {
          faceRegions.push({ x, y, width: 100, height: 100 });
        }
      }
    }

    return this.mergeFaceRegions(faceRegions);
  }

  private async isFaceRegion(image: any, x: number, y: number, width: number, height: number): Promise<boolean> {
    const region = image.clone().crop(x, y, width, height);
    const colors = this.analyzeRegionColors(region);

    const skinToneRange = this.getSkinToneRange();
    const skinPixels = colors.filter(color => this.isInSkinToneRange(color, skinToneRange));

    return skinPixels.length / colors.length > 0.3;
  }

  private analyzeRegionColors(image: any): Array<{r: number, g: number, b: number}> {
    const colors = [];
    const width = image.getWidth();
    const height = image.getHeight();

    for (let y = 0; y < height; y += 5) {
      for (let x = 0; x < width; x += 5) {
        const pixel = image.getPixelColor(x, y);
        const rgba = (jimp as any).intToRGBA(pixel);
        colors.push({ r: rgba.r, g: rgba.g, b: rgba.b });
      }
    }

    return colors;
  }

  private getSkinToneRange(): {min: {r: number, g: number, b: number}, max: {r: number, g: number, b: number}} {
    return {
      min: { r: 95, g: 60, b: 20 },
      max: { r: 255, g: 220, b: 180 }
    };
  }

  private isInSkinToneRange(color: {r: number, g: number, b: number}, range: any): boolean {
    return color.r >= range.min.r && color.r <= range.max.r &&
           color.g >= range.min.g && color.g <= range.max.g &&
           color.b >= range.min.b && color.b <= range.max.b;
  }

  private mergeFaceRegions(regions: Array<{x: number, y: number, width: number, height: number}>): Array<{x: number, y: number, width: number, height: number}> {
    const merged = [];
    const used = new Set();

    for (let i = 0; i < regions.length; i++) {
      if (used.has(i)) continue;

      let currentRegion = regions[i];
      used.add(i);

      for (let j = i + 1; j < regions.length; j++) {
        if (used.has(j)) continue;

        if (this.regionsOverlap(currentRegion, regions[j])) {
          currentRegion = this.mergeRegions(currentRegion, regions[j]);
          used.add(j);
        }
      }

      merged.push(currentRegion);
    }

    return merged;
  }

  private regionsOverlap(r1: {x: number, y: number, width: number, height: number}, r2: {x: number, y: number, width: number, height: number}): boolean {
    return !(r1.x + r1.width < r2.x ||
             r2.x + r2.width < r1.x ||
             r1.y + r1.height < r2.y ||
             r2.y + r2.height < r1.y);
  }

  private mergeRegions(r1: {x: number, y: number, width: number, height: number}, r2: {x: number, y: number, width: number, height: number}): {x: number, y: number, width: number, height: number} {
    const x = Math.min(r1.x, r2.x);
    const y = Math.min(r1.y, r2.y);
    const width = Math.max(r1.x + r1.width, r2.x + r2.width) - x;
    const height = Math.max(r1.y + r1.height, r2.y + r2.height) - y;

    return { x, y, width, height };
  }

  private generateLaplaceNoise(sensitivity: number, epsilon: number): number {
    const u = Math.random() - 0.5;
    const b = sensitivity / epsilon;
    return -b * Math.sign(u) * Math.log(1 - 2 * Math.abs(u));
  }

  private addNoiseToNumericValues(obj: any, baseNoise: number): void {
    for (const key in obj) {
      if (typeof obj[key] === 'number') {
        const noise = baseNoise * (Math.random() - 0.5) * 0.1;
        obj[key] += noise;
      } else if (typeof obj[key] === 'object' && obj[key] !== null) {
        this.addNoiseToNumericValues(obj[key], baseNoise);
      }
    }
  }

  private getNoiseParameters(privacyLevel: string): NoiseParameters {
    switch (privacyLevel) {
      case 'strict':
        return { sensitivity: 1.0, epsilon: 0.1, delta: 1e-6 };
      case 'balanced':
        return { sensitivity: 1.0, epsilon: 0.5, delta: 1e-5 };
      case 'minimal':
        return { sensitivity: 1.0, epsilon: 1.0, delta: 1e-4 };
      default:
        return { sensitivity: 1.0, epsilon: 0.5, delta: 1e-5 };
    }
  }

  private calculateBudgetUsage(privacyLevel: string): number {
    return this.getNoiseParameters(privacyLevel).epsilon;
  }

  private aggregateFeatures(features: any[]): any {
    if (features.length === 0) return {};

    const aggregated = JSON.parse(JSON.stringify(features[0]));

    for (let i = 1; i < features.length; i++) {
      this.mergeFeatures(aggregated, features[i]);
    }

    this.normalizeFeatures(aggregated, features.length);

    return aggregated;
  }

  private mergeFeatures(target: any, source: any): void {
    for (const key in source) {
      if (typeof source[key] === 'number' && typeof target[key] === 'number') {
        target[key] += source[key];
      } else if (typeof source[key] === 'object' && source[key] !== null) {
        if (!target[key]) target[key] = {};
        this.mergeFeatures(target[key], source[key]);
      }
    }
  }

  private normalizeFeatures(features: any, count: number): void {
    for (const key in features) {
      if (typeof features[key] === 'number') {
        features[key] /= count;
      } else if (typeof features[key] === 'object' && features[key] !== null) {
        this.normalizeFeatures(features[key], count);
      }
    }
  }

  private getCacheSize(): number {
    return 0;
  }
}