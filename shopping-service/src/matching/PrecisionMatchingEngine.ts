import sharp from 'sharp';
import Jimp from 'jimp';
import { createHash } from 'crypto';
import { Product } from '../models/Product';
import { logger } from '../middleware/ErrorHandler';

export interface VisualMatchResult {
  product: Product;
  similarity: number;
  matchType: 'exact' | 'very_high' | 'high' | 'medium' | 'low';
  confidence: number;
  features: MatchedFeatures;
}

export interface MatchedFeatures {
  color: {
    similarity: number;
    dominantColors: string[];
    colorHarmony: number;
  };
  shape: {
    similarity: number;
    silhouette: string;
    proportions: number[];
  };
  texture: {
    similarity: number;
    pattern: string;
    fabric: string;
  };
  style: {
    similarity: number;
    category: string;
    aesthetic: string;
  };
  details: {
    similarity: number;
    features: string[];
    hardware: string[];
  };
}

export interface SemanticMatchResult {
  product: Product;
  relevance: number;
  semanticScore: number;
  keywordMatches: string[];
  contextualRelevance: number;
}

export interface StyleMatchCriteria {
  visualWeight: number;
  semanticWeight: number;
  priceRange?: { min: number; max: number };
  brandPreference?: string[];
  qualityThreshold?: number;
  materialPreferences?: string[];
  colorPreferences?: string[];
  stylePreferences?: string[];
  excludeExact?: boolean;
}

export interface ImageFeatures {
  colorHistogram: number[];
  dominantColors: Color[];
  shapeDescriptor: number[];
  textureFeatures: number[];
  edges: number[];
  keypoints: ImageKeypoint[];
  phash: string;
  dhash: string;
}

export interface Color {
  r: number;
  g: number;
  b: number;
  hex: string;
  percentage: number;
  name?: string;
}

export interface ImageKeypoint {
  x: number;
  y: number;
  scale: number;
  angle: number;
  response: number;
}

export class PrecisionMatchingEngine {
  private colorNames: Map<string, string> = new Map();
  private materialDatabase: Map<string, MaterialProperties> = new Map();

  constructor() {
    this.initializeColorNames();
    this.initializeMaterialDatabase();
  }

  async findVisualMatches(
    targetImage: Buffer | string,
    candidateProducts: Product[],
    criteria: StyleMatchCriteria
  ): Promise<VisualMatchResult[]> {
    try {
      // Extract features from target image
      const targetFeatures = await this.extractImageFeatures(targetImage);
      const results: VisualMatchResult[] = [];

      // Process candidates in parallel batches
      const batchSize = 10;
      for (let i = 0; i < candidateProducts.length; i += batchSize) {
        const batch = candidateProducts.slice(i, i + batchSize);
        const batchPromises = batch.map(async (product) => {
          try {
            return await this.calculateVisualSimilarity(targetFeatures, product, criteria);
          } catch (error) {
            logger.error(`Error processing product ${product.id}:`, error);
            return null;
          }
        });

        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults.filter(result => result !== null) as VisualMatchResult[]);
      }

      // Sort by similarity and apply quality thresholds
      const filteredResults = results
        .filter(result => result.similarity >= 0.5) // Minimum 50% similarity
        .sort((a, b) => b.similarity - a.similarity);

      // Apply additional filters
      return this.applyQualityFilters(filteredResults, criteria);

    } catch (error) {
      logger.error('Error in findVisualMatches:', error);
      throw error;
    }
  }

  private async calculateVisualSimilarity(
    targetFeatures: ImageFeatures,
    product: Product,
    criteria: StyleMatchCriteria
  ): Promise<VisualMatchResult | null> {
    if (!product.images || product.images.length === 0) {
      return null;
    }

    // Use the first image as primary for matching
    const productImage = product.images[0];
    let productFeatures: ImageFeatures;

    try {
      productFeatures = await this.extractImageFeatures(productImage);
    } catch (error) {
      logger.error(`Failed to extract features for product ${product.id}:`, error);
      return null;
    }

    // Calculate feature similarities
    const colorSimilarity = this.calculateColorSimilarity(targetFeatures, productFeatures);
    const shapeSimilarity = this.calculateShapeSimilarity(targetFeatures, productFeatures);
    const textureSimilarity = this.calculateTextureSimilarity(targetFeatures, productFeatures);
    const styleSimilarity = this.calculateStyleSimilarity(product);
    const detailsSimilarity = this.calculateDetailsSimilarity(targetFeatures, productFeatures);

    // Check for exact matches using perceptual hashes
    const isExactMatch = this.isExactMatch(targetFeatures, productFeatures);
    if (isExactMatch && criteria.excludeExact) {
      return null;
    }

    // Calculate weighted overall similarity
    const weights = {
      color: 0.25,
      shape: 0.25,
      texture: 0.20,
      style: 0.15,
      details: 0.15
    };

    const overallSimilarity = (
      colorSimilarity.similarity * weights.color +
      shapeSimilarity.similarity * weights.shape +
      textureSimilarity.similarity * weights.texture +
      styleSimilarity.similarity * weights.style +
      detailsSimilarity.similarity * weights.details
    );

    // Determine match type based on similarity score
    let matchType: VisualMatchResult['matchType'];
    if (isExactMatch) matchType = 'exact';
    else if (overallSimilarity >= 0.9) matchType = 'very_high';
    else if (overallSimilarity >= 0.8) matchType = 'high';
    else if (overallSimilarity >= 0.6) matchType = 'medium';
    else matchType = 'low';

    // Calculate confidence based on feature consistency
    const featureSimilarities = [
      colorSimilarity.similarity,
      shapeSimilarity.similarity,
      textureSimilarity.similarity,
      styleSimilarity.similarity,
      detailsSimilarity.similarity
    ];

    const mean = featureSimilarities.reduce((sum, s) => sum + s, 0) / featureSimilarities.length;
    const variance = featureSimilarities.reduce((sum, s) => sum + Math.pow(s - mean, 2), 0) / featureSimilarities.length;
    const confidence = Math.max(0.5, 1 - variance); // Higher confidence when features are consistent

    return {
      product,
      similarity: overallSimilarity,
      matchType,
      confidence,
      features: {
        color: colorSimilarity,
        shape: shapeSimilarity,
        texture: textureSimilarity,
        style: styleSimilarity,
        details: detailsSimilarity
      }
    };
  }

  private async extractImageFeatures(imageInput: Buffer | string): Promise<ImageFeatures> {
    let imageBuffer: Buffer;

    if (typeof imageInput === 'string') {
      // Download image if URL
      const axios = (await import('axios')).default;
      const response = await axios.get(imageInput, { responseType: 'arraybuffer' });
      imageBuffer = Buffer.from(response.data);
    } else {
      imageBuffer = imageInput;
    }

    // Use Sharp for initial processing
    const image = sharp(imageBuffer);
    const metadata = await image.metadata();

    // Resize for consistent processing
    const processedBuffer = await image
      .resize(512, 512, { fit: 'contain', background: { r: 255, g: 255, b: 255 } })
      .jpeg()
      .toBuffer();

    // Extract features using Jimp for pixel manipulation
    const jimpImage = await Jimp.read(processedBuffer);

    return {
      colorHistogram: this.extractColorHistogram(jimpImage),
      dominantColors: await this.extractDominantColors(jimpImage),
      shapeDescriptor: this.extractShapeDescriptor(jimpImage),
      textureFeatures: this.extractTextureFeatures(jimpImage),
      edges: this.extractEdgeFeatures(jimpImage),
      keypoints: this.extractKeypoints(jimpImage),
      phash: this.calculatePerceptualHash(jimpImage),
      dhash: this.calculateDifferenceHash(jimpImage)
    };
  }

  private extractColorHistogram(image: Jimp): number[] {
    const histogram = new Array(256 * 3).fill(0); // RGB histograms
    const pixelData = image.bitmap.data;

    for (let i = 0; i < pixelData.length; i += 4) {
      const r = pixelData[i];
      const g = pixelData[i + 1];
      const b = pixelData[i + 2];

      histogram[r]++;
      histogram[256 + g]++;
      histogram[512 + b]++;
    }

    // Normalize
    const totalPixels = image.bitmap.width * image.bitmap.height;
    return histogram.map(count => count / totalPixels);
  }

  private async extractDominantColors(image: Jimp): Promise<Color[]> {
    const colorCounts = new Map<string, number>();
    const pixelData = image.bitmap.data;

    // Sample pixels (every 4th pixel for performance)
    for (let i = 0; i < pixelData.length; i += 16) {
      const r = Math.floor(pixelData[i] / 16) * 16; // Quantize to reduce noise
      const g = Math.floor(pixelData[i + 1] / 16) * 16;
      const b = Math.floor(pixelData[i + 2] / 16) * 16;

      const key = `${r},${g},${b}`;
      colorCounts.set(key, (colorCounts.get(key) || 0) + 1);
    }

    // Get top colors
    const sortedColors = Array.from(colorCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8);

    const totalSamples = Array.from(colorCounts.values()).reduce((sum, count) => sum + count, 0);

    return sortedColors.map(([colorKey, count]) => {
      const [r, g, b] = colorKey.split(',').map(Number);
      const hex = `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;

      return {
        r,
        g,
        b,
        hex,
        percentage: (count / totalSamples) * 100,
        name: this.getColorName(hex)
      };
    });
  }

  private extractShapeDescriptor(image: Jimp): number[] {
    // Simplified shape descriptor based on edge distribution
    const edges = this.detectEdges(image);
    const descriptor = new Array(36).fill(0); // 36 bins for edge orientations

    for (let y = 0; y < edges.bitmap.height; y++) {
      for (let x = 0; x < edges.bitmap.width; x++) {
        const edgeValue = edges.getPixelColor(x, y) & 0xFF;
        if (edgeValue > 128) { // Edge threshold
          // Calculate gradient orientation (simplified)
          const dx = x < edges.bitmap.width - 1 ?
            (edges.getPixelColor(x + 1, y) & 0xFF) - edgeValue : 0;
          const dy = y < edges.bitmap.height - 1 ?
            (edges.getPixelColor(x, y + 1) & 0xFF) - edgeValue : 0;

          const angle = Math.atan2(dy, dx);
          const bin = Math.floor(((angle + Math.PI) / (2 * Math.PI)) * 36);
          descriptor[bin]++;
        }
      }
    }

    // Normalize
    const sum = descriptor.reduce((s, v) => s + v, 0);
    return sum > 0 ? descriptor.map(v => v / sum) : descriptor;
  }

  private extractTextureFeatures(image: Jimp): number[] {
    // Local Binary Pattern (LBP) texture features
    const gray = image.clone().greyscale();
    const features = [];

    for (let y = 1; y < gray.bitmap.height - 1; y += 8) { // Sample every 8 pixels
      for (let x = 1; x < gray.bitmap.width - 1; x += 8) {
        const center = gray.getPixelColor(x, y) & 0xFF;
        let pattern = 0;

        // 8-connected neighbors
        const neighbors = [
          [x-1, y-1], [x, y-1], [x+1, y-1],
          [x+1, y], [x+1, y+1], [x, y+1],
          [x-1, y+1], [x-1, y]
        ];

        for (let i = 0; i < neighbors.length; i++) {
          const [nx, ny] = neighbors[i];
          const neighborValue = gray.getPixelColor(nx, ny) & 0xFF;
          if (neighborValue >= center) {
            pattern |= (1 << i);
          }
        }

        features.push(pattern / 255); // Normalize to 0-1
      }
    }

    return features.slice(0, 64); // Limit feature vector size
  }

  private extractEdgeFeatures(image: Jimp): number[] {
    const edges = this.detectEdges(image);
    const features = [];

    // Extract edge statistics
    let edgeCount = 0;
    let totalIntensity = 0;

    for (let y = 0; y < edges.bitmap.height; y++) {
      for (let x = 0; x < edges.bitmap.width; x++) {
        const intensity = edges.getPixelColor(x, y) & 0xFF;
        if (intensity > 128) {
          edgeCount++;
        }
        totalIntensity += intensity;
      }
    }

    const totalPixels = edges.bitmap.width * edges.bitmap.height;
    features.push(edgeCount / totalPixels); // Edge density
    features.push(totalIntensity / (totalPixels * 255)); // Average edge intensity

    return features;
  }

  private detectEdges(image: Jimp): Jimp {
    const gray = image.clone().greyscale();
    const edges = gray.clone();

    // Sobel edge detection
    for (let y = 1; y < gray.bitmap.height - 1; y++) {
      for (let x = 1; x < gray.bitmap.width - 1; x++) {
        // Sobel X kernel
        const gx =
          -1 * (gray.getPixelColor(x-1, y-1) & 0xFF) +
          1 * (gray.getPixelColor(x+1, y-1) & 0xFF) +
          -2 * (gray.getPixelColor(x-1, y) & 0xFF) +
          2 * (gray.getPixelColor(x+1, y) & 0xFF) +
          -1 * (gray.getPixelColor(x-1, y+1) & 0xFF) +
          1 * (gray.getPixelColor(x+1, y+1) & 0xFF);

        // Sobel Y kernel
        const gy =
          -1 * (gray.getPixelColor(x-1, y-1) & 0xFF) +
          -2 * (gray.getPixelColor(x, y-1) & 0xFF) +
          -1 * (gray.getPixelColor(x+1, y-1) & 0xFF) +
          1 * (gray.getPixelColor(x-1, y+1) & 0xFF) +
          2 * (gray.getPixelColor(x, y+1) & 0xFF) +
          1 * (gray.getPixelColor(x+1, y+1) & 0xFF);

        const magnitude = Math.sqrt(gx * gx + gy * gy);
        const edgeValue = Math.min(255, Math.max(0, magnitude));

        edges.setPixelColor(
          (edgeValue << 24) | (edgeValue << 16) | (edgeValue << 8) | 0xFF,
          x, y
        );
      }
    }

    return edges;
  }

  private extractKeypoints(image: Jimp): ImageKeypoint[] {
    // Simplified corner detection (Harris corners)
    const gray = image.clone().greyscale();
    const keypoints: ImageKeypoint[] = [];

    for (let y = 2; y < gray.bitmap.height - 2; y += 8) {
      for (let x = 2; x < gray.bitmap.width - 2; x += 8) {
        const response = this.calculateCornerResponse(gray, x, y);

        if (response > 1000) { // Threshold for corner detection
          keypoints.push({
            x: x / gray.bitmap.width, // Normalize coordinates
            y: y / gray.bitmap.height,
            scale: 1.0,
            angle: 0,
            response
          });
        }
      }
    }

    return keypoints.slice(0, 50); // Limit number of keypoints
  }

  private calculateCornerResponse(image: Jimp, x: number, y: number): number {
    // Harris corner response
    let Ixx = 0, Iyy = 0, Ixy = 0;

    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        const px = x + dx;
        const py = y + dy;

        if (px > 0 && px < image.bitmap.width - 1 && py > 0 && py < image.bitmap.height - 1) {
          const Ix = (image.getPixelColor(px + 1, py) & 0xFF) - (image.getPixelColor(px - 1, py) & 0xFF);
          const Iy = (image.getPixelColor(px, py + 1) & 0xFF) - (image.getPixelColor(px, py - 1) & 0xFF);

          Ixx += Ix * Ix;
          Iyy += Iy * Iy;
          Ixy += Ix * Iy;
        }
      }
    }

    const det = Ixx * Iyy - Ixy * Ixy;
    const trace = Ixx + Iyy;
    const k = 0.04;

    return det - k * trace * trace;
  }

  private calculatePerceptualHash(image: Jimp): string {
    // DCT-based perceptual hash
    const small = image.clone().resize(32, 32).greyscale();
    const dct = this.calculateDCT(small);

    // Get median of low frequencies (excluding DC component)
    const lowFreqs = dct.slice(1, 65).sort((a, b) => a - b);
    const median = lowFreqs[lowFreqs.length / 2];

    // Create hash based on median comparison
    let hash = '';
    for (let i = 1; i < 65; i++) {
      hash += dct[i] > median ? '1' : '0';
    }

    return hash;
  }

  private calculateDifferenceHash(image: Jimp): string {
    const small = image.clone().resize(9, 8).greyscale();
    let hash = '';

    for (let y = 0; y < 8; y++) {
      for (let x = 0; x < 8; x++) {
        const current = small.getPixelColor(x, y) & 0xFF;
        const next = small.getPixelColor(x + 1, y) & 0xFF;
        hash += current > next ? '1' : '0';
      }
    }

    return hash;
  }

  private calculateDCT(image: Jimp): number[] {
    // Simplified 8x8 DCT for perceptual hashing
    const N = 8;
    const result: number[] = [];

    for (let u = 0; u < N; u++) {
      for (let v = 0; v < N; v++) {
        let sum = 0;
        for (let x = 0; x < N; x++) {
          for (let y = 0; y < N; y++) {
            const pixel = image.getPixelColor(x, y) & 0xFF;
            sum += pixel *
              Math.cos(((2 * x + 1) * u * Math.PI) / (2 * N)) *
              Math.cos(((2 * y + 1) * v * Math.PI) / (2 * N));
          }
        }

        const cu = u === 0 ? 1 / Math.sqrt(2) : 1;
        const cv = v === 0 ? 1 / Math.sqrt(2) : 1;
        result.push((cu * cv / 4) * sum);
      }
    }

    return result;
  }

  private calculateColorSimilarity(features1: ImageFeatures, features2: ImageFeatures): MatchedFeatures['color'] {
    // Histogram intersection
    const histogramSimilarity = this.calculateHistogramIntersection(
      features1.colorHistogram,
      features2.colorHistogram
    );

    // Dominant color comparison
    const colorMatch = this.compareDominantColors(features1.dominantColors, features2.dominantColors);

    return {
      similarity: (histogramSimilarity * 0.6 + colorMatch.similarity * 0.4),
      dominantColors: features2.dominantColors.map(c => c.hex),
      colorHarmony: colorMatch.harmony
    };
  }

  private calculateShapeSimilarity(features1: ImageFeatures, features2: ImageFeatures): MatchedFeatures['shape'] {
    const shapeSim = this.calculateVectorSimilarity(features1.shapeDescriptor, features2.shapeDescriptor);
    const edgeSim = this.calculateVectorSimilarity(features1.edges, features2.edges);

    return {
      similarity: (shapeSim * 0.7 + edgeSim * 0.3),
      silhouette: 'unknown', // Would require more sophisticated analysis
      proportions: features2.shapeDescriptor
    };
  }

  private calculateTextureSimilarity(features1: ImageFeatures, features2: ImageFeatures): MatchedFeatures['texture'] {
    const textureSim = this.calculateVectorSimilarity(features1.textureFeatures, features2.textureFeatures);

    return {
      similarity: textureSim,
      pattern: 'unknown',
      fabric: 'unknown'
    };
  }

  private calculateStyleSimilarity(product: Product): MatchedFeatures['style'] {
    // This would use semantic analysis of product metadata
    return {
      similarity: 0.5, // Default for now
      category: product.category?.main || 'unknown',
      aesthetic: 'unknown'
    };
  }

  private calculateDetailsSimilarity(features1: ImageFeatures, features2: ImageFeatures): MatchedFeatures['details'] {
    const keypointSim = this.calculateKeypointSimilarity(features1.keypoints, features2.keypoints);

    return {
      similarity: keypointSim,
      features: [],
      hardware: []
    };
  }

  private isExactMatch(features1: ImageFeatures, features2: ImageFeatures): boolean {
    const pHashDistance = this.calculateHammingDistance(features1.phash, features2.phash);
    const dHashDistance = this.calculateHammingDistance(features1.dhash, features2.dhash);

    return pHashDistance <= 5 || dHashDistance <= 5; // Very similar hashes
  }

  private calculateHistogramIntersection(hist1: number[], hist2: number[]): number {
    let intersection = 0;
    for (let i = 0; i < Math.min(hist1.length, hist2.length); i++) {
      intersection += Math.min(hist1[i], hist2[i]);
    }
    return intersection;
  }

  private compareDominantColors(colors1: Color[], colors2: Color[]): { similarity: number; harmony: number } {
    if (colors1.length === 0 || colors2.length === 0) {
      return { similarity: 0, harmony: 0 };
    }

    let totalSimilarity = 0;
    let matches = 0;

    for (const color1 of colors1) {
      let bestMatch = 0;
      for (const color2 of colors2) {
        const colorDist = this.calculateColorDistance(color1, color2);
        const similarity = Math.max(0, 1 - colorDist / 442); // Max RGB distance is ~442
        bestMatch = Math.max(bestMatch, similarity);
      }

      if (bestMatch > 0.7) {
        totalSimilarity += bestMatch * color1.percentage;
        matches++;
      }
    }

    const similarity = matches > 0 ? totalSimilarity / 100 : 0;
    const harmony = this.calculateColorHarmony(colors1, colors2);

    return { similarity, harmony };
  }

  private calculateColorDistance(color1: Color, color2: Color): number {
    const dr = color1.r - color2.r;
    const dg = color1.g - color2.g;
    const db = color1.b - color2.b;
    return Math.sqrt(dr * dr + dg * dg + db * db);
  }

  private calculateColorHarmony(colors1: Color[], colors2: Color[]): number {
    // Simplified color harmony calculation
    // In practice, this would use color theory principles
    return 0.7;
  }

  private calculateVectorSimilarity(vec1: number[], vec2: number[]): number {
    if (vec1.length === 0 || vec2.length === 0) return 0;

    const minLength = Math.min(vec1.length, vec2.length);
    let dotProduct = 0;
    let norm1 = 0;
    let norm2 = 0;

    for (let i = 0; i < minLength; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }

    if (norm1 === 0 || norm2 === 0) return 0;

    return dotProduct / (Math.sqrt(norm1) * Math.sqrt(norm2));
  }

  private calculateKeypointSimilarity(kp1: ImageKeypoint[], kp2: ImageKeypoint[]): number {
    if (kp1.length === 0 || kp2.length === 0) return 0;

    let matches = 0;
    const threshold = 0.1; // Distance threshold

    for (const point1 of kp1) {
      for (const point2 of kp2) {
        const distance = Math.sqrt(
          Math.pow(point1.x - point2.x, 2) +
          Math.pow(point1.y - point2.y, 2)
        );

        if (distance < threshold) {
          matches++;
          break;
        }
      }
    }

    return matches / Math.max(kp1.length, kp2.length);
  }

  private calculateHammingDistance(hash1: string, hash2: string): number {
    let distance = 0;
    for (let i = 0; i < Math.min(hash1.length, hash2.length); i++) {
      if (hash1[i] !== hash2[i]) {
        distance++;
      }
    }
    return distance;
  }

  private applyQualityFilters(
    results: VisualMatchResult[],
    criteria: StyleMatchCriteria
  ): VisualMatchResult[] {
    return results.filter(result => {
      // Price range filter
      if (criteria.priceRange) {
        const price = result.product.currentPrice || 0;
        if (price < criteria.priceRange.min || price > criteria.priceRange.max) {
          return false;
        }
      }

      // Brand preference
      if (criteria.brandPreference && criteria.brandPreference.length > 0) {
        if (!criteria.brandPreference.includes(result.product.brand || '')) {
          return false;
        }
      }

      // Quality threshold
      if (criteria.qualityThreshold && result.confidence < criteria.qualityThreshold) {
        return false;
      }

      return true;
    });
  }

  private getColorName(hex: string): string {
    return this.colorNames.get(hex.toLowerCase()) || 'unknown';
  }

  private initializeColorNames(): void {
    // Basic color name mapping
    const colors = {
      '#ffffff': 'white',
      '#000000': 'black',
      '#ff0000': 'red',
      '#00ff00': 'green',
      '#0000ff': 'blue',
      '#ffff00': 'yellow',
      '#ff00ff': 'magenta',
      '#00ffff': 'cyan',
      '#808080': 'gray',
      '#800000': 'maroon',
      '#008000': 'dark green',
      '#000080': 'navy',
      '#800080': 'purple',
      '#008080': 'teal',
      '#c0c0c0': 'silver',
      '#ffa500': 'orange',
      '#ffc0cb': 'pink',
      '#a52a2a': 'brown',
      '#dda0dd': 'plum'
    };

    Object.entries(colors).forEach(([hex, name]) => {
      this.colorNames.set(hex, name);
    });
  }

  private initializeMaterialDatabase(): void {
    // Initialize material properties database
    // This would be expanded with real material data
  }
}

interface MaterialProperties {
  texture: string;
  durability: number;
  comfort: number;
  breathability: number;
  wrinkleResistance: number;
}