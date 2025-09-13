import Sharp from 'sharp';
import Jimp from 'jimp';

import * as Vibrant from 'node-vibrant';
import { IProduct } from '../models/Product';

export interface ColorProfile {
  dominantColors: Array<{ r: number; g: number; b: number; percentage: number }>;
  colorPalette: string[];
  brightness: number;
  saturation: number;
  temperature: 'warm' | 'cool' | 'neutral';
}

export interface VisualFeatures {
  colors: ColorProfile;
  texture: {
    smoothness: number;
    pattern: 'solid' | 'striped' | 'checkered' | 'floral' | 'geometric' | 'abstract';
    complexity: number;
  };
  shape: {
    silhouette: 'fitted' | 'loose' | 'oversized' | 'tailored';
    neckline?: 'round' | 'v-neck' | 'scoop' | 'high' | 'off-shoulder';
    sleeves?: 'short' | 'long' | 'sleeveless' | '3/4' | 'cap';
  };
  style: {
    category: 'casual' | 'formal' | 'sporty' | 'bohemian' | 'minimalist' | 'vintage';
    mood: 'playful' | 'elegant' | 'edgy' | 'romantic' | 'professional';
    season: 'spring' | 'summer' | 'fall' | 'winter' | 'all-season';
  };
}

export interface SimilarityMatch {
  product: IProduct;
  similarityScore: number;
  breakdown: {
    colorSimilarity: number;
    styleSimilarity: number;
    shapeSimilarity: number;
    overallMatch: number;
  };
  matchReasons: string[];
}

export class VisualSimilarityEngine {
  private modelCache: Map<string, any> = new Map();

  async extractVisualFeatures(product: IProduct): Promise<VisualFeatures> {
    const imageUrl = product.images.main;
    if (!imageUrl) {
      throw new Error('No main image available for feature extraction');
    }

    try {
      // Download and process image
      const imageBuffer = await this.downloadImage(imageUrl);
      const processedImage = await this.preprocessImage(imageBuffer);

      // Extract color profile
      const colorProfile = await this.extractColorProfile(processedImage);

      // Extract texture and pattern information
      const textureInfo = await this.analyzeTexture(processedImage);

      // Analyze shape and silhouette (basic implementation)
      const shapeInfo = this.analyzeShape(product);

      // Determine style characteristics
      const styleInfo = this.analyzeStyle(product, colorProfile);

      return {
        colors: colorProfile,
        texture: textureInfo,
        shape: shapeInfo,
        style: styleInfo
      };
    } catch (error) {
      console.error('Error extracting visual features:', error);
      // Return default features
      return this.getDefaultFeatures(product);
    }
  }

  async findSimilarProducts(
    targetProduct: IProduct,
    candidateProducts: IProduct[],
    options: {
      colorWeight?: number;
      styleWeight?: number;
      shapeWeight?: number;
      minSimilarityThreshold?: number;
      maxResults?: number;
    } = {}
  ): Promise<SimilarityMatch[]> {
    const {
      colorWeight = 0.4,
      styleWeight = 0.3,
      shapeWeight = 0.3,
      minSimilarityThreshold = 0.3,
      maxResults = 20
    } = options;

    const targetFeatures = await this.extractVisualFeatures(targetProduct);
    const matches: SimilarityMatch[] = [];

    for (const candidate of candidateProducts) {
      if (candidate.id === targetProduct.id) continue;

      try {
        const candidateFeatures = await this.extractVisualFeatures(candidate);
        
        const colorSimilarity = this.calculateColorSimilarity(
          targetFeatures.colors,
          candidateFeatures.colors
        );
        
        const styleSimilarity = this.calculateStyleSimilarity(
          targetFeatures.style,
          candidateFeatures.style
        );
        
        const shapeSimilarity = this.calculateShapeSimilarity(
          targetFeatures.shape,
          candidateFeatures.shape
        );

        const overallMatch = (
          colorSimilarity * colorWeight +
          styleSimilarity * styleWeight +
          shapeSimilarity * shapeWeight
        );

        if (overallMatch >= minSimilarityThreshold) {
          const matchReasons = this.generateMatchReasons(
            targetFeatures,
            candidateFeatures,
            { colorSimilarity, styleSimilarity, shapeSimilarity }
          );

          matches.push({
            product: candidate,
            similarityScore: overallMatch,
            breakdown: {
              colorSimilarity,
              styleSimilarity,
              shapeSimilarity,
              overallMatch
            },
            matchReasons
          });
        }
      } catch (error) {
        console.warn(`Error processing candidate product ${candidate.id}:`, error);
      }
    }

    // Sort by similarity score and return top matches
    return matches
      .sort((a, b) => b.similarityScore - a.similarityScore)
      .slice(0, maxResults);
  }

  private async downloadImage(url: string): Promise<Buffer> {
    const axios = await import('axios');
    const response = await axios.default.get(url, { 
      responseType: 'arraybuffer',
      timeout: 10000 
    });
    return Buffer.from(response.data);
  }

  private async preprocessImage(imageBuffer: Buffer): Promise<Buffer> {
    return Sharp(imageBuffer)
      .resize(300, 400, { fit: 'cover' })
      .normalize()
      .jpeg({ quality: 80 })
      .toBuffer();
  }

  private async extractColorProfile(imageBuffer: Buffer): Promise<ColorProfile> {
    try {
      const palette = await Vibrant.from(imageBuffer).getPalette();

      const swatches = [
        palette.Vibrant,
        palette.DarkVibrant,
        palette.LightVibrant,
        palette.Muted,
        palette.DarkMuted,
        palette.LightMuted
      ].filter(Boolean);

      const dominantColors = swatches.map((swatch, index) => {
        const rgb = swatch!.getRgb();
        return {
          r: Math.round(rgb[0]),
          g: Math.round(rgb[1]),
          b: Math.round(rgb[2]),
          percentage: index === 0 ? 0.4 : 0.6 / (swatches.length - 1)
        };
      });

      const colorPalette = swatches.map(swatch => swatch!.getHex());
      const dominantColor = dominantColors[0] || { r: 128, g: 128, b: 128, percentage: 1.0 };

      const brightness = this.calculateBrightness([dominantColor.r, dominantColor.g, dominantColor.b]);
      const saturation = this.calculateSaturation([dominantColor.r, dominantColor.g, dominantColor.b]);
      const temperature = this.determineTemperature([dominantColor.r, dominantColor.g, dominantColor.b]);

      return {
        dominantColors,
        colorPalette,
        brightness,
        saturation,
        temperature
      };
    } catch (error) {
      console.warn('Color extraction failed:', error);
      return {
        dominantColors: [{ r: 128, g: 128, b: 128, percentage: 1.0 }],
        colorPalette: ['#808080'],
        brightness: 0.5,
        saturation: 0.5,
        temperature: 'neutral'
      };
    }
  }

  private async analyzeTexture(imageBuffer: Buffer): Promise<VisualFeatures['texture']> {
    try {
      const image = await Jimp.read(imageBuffer);
      
      // Basic texture analysis using edge detection and pattern recognition
      const edgeCount = this.detectEdges(image);
      const patternType = this.detectPattern(image);
      
      const smoothness = Math.max(0, 1 - (edgeCount / 1000));
      const complexity = edgeCount / 500;

      return {
        smoothness,
        pattern: patternType,
        complexity: Math.min(1, complexity)
      };
    } catch (error) {
      console.warn('Texture analysis failed:', error);
      return {
        smoothness: 0.5,
        pattern: 'solid',
        complexity: 0.5
      };
    }
  }

  private analyzeShape(product: IProduct): VisualFeatures['shape'] {
    const name = product.name.toLowerCase();
    const description = product.description.toLowerCase();
    const text = `${name} ${description}`;

    // Basic shape analysis from product text
    let silhouette: VisualFeatures['shape']['silhouette'] = 'fitted';
    let neckline: VisualFeatures['shape']['neckline'] | undefined;
    let sleeves: VisualFeatures['shape']['sleeves'] | undefined;

    // Silhouette detection
    if (text.includes('oversized') || text.includes('baggy')) {
      silhouette = 'oversized';
    } else if (text.includes('loose') || text.includes('relaxed')) {
      silhouette = 'loose';
    } else if (text.includes('tailored') || text.includes('structured')) {
      silhouette = 'tailored';
    }

    // Neckline detection
    if (text.includes('v-neck') || text.includes('v neck')) {
      neckline = 'v-neck';
    } else if (text.includes('scoop')) {
      neckline = 'scoop';
    } else if (text.includes('high neck') || text.includes('turtle')) {
      neckline = 'high';
    } else if (text.includes('off shoulder')) {
      neckline = 'off-shoulder';
    } else if (text.includes('round neck') || text.includes('crew')) {
      neckline = 'round';
    }

    // Sleeve detection
    if (text.includes('sleeveless') || text.includes('tank') || text.includes('strapless')) {
      sleeves = 'sleeveless';
    } else if (text.includes('short sleeve')) {
      sleeves = 'short';
    } else if (text.includes('long sleeve')) {
      sleeves = 'long';
    } else if (text.includes('3/4') || text.includes('three quarter')) {
      sleeves = '3/4';
    } else if (text.includes('cap sleeve')) {
      sleeves = 'cap';
    }

    return { silhouette, neckline, sleeves };
  }

  private analyzeStyle(product: IProduct, colorProfile: ColorProfile): VisualFeatures['style'] {
    const name = product.name.toLowerCase();
    const description = product.description.toLowerCase();
    const category = product.category.main.toLowerCase();
    const text = `${name} ${description} ${category}`;

    // Style category detection
    let styleCategory: VisualFeatures['style']['category'] = 'casual';
    if (text.includes('formal') || text.includes('dress') || text.includes('blazer')) {
      styleCategory = 'formal';
    } else if (text.includes('sport') || text.includes('athletic') || text.includes('gym')) {
      styleCategory = 'sporty';
    } else if (text.includes('boho') || text.includes('bohemian') || text.includes('flowy')) {
      styleCategory = 'bohemian';
    } else if (text.includes('minimal') || text.includes('clean') || text.includes('simple')) {
      styleCategory = 'minimalist';
    } else if (text.includes('vintage') || text.includes('retro') || text.includes('classic')) {
      styleCategory = 'vintage';
    }

    // Mood detection
    let mood: VisualFeatures['style']['mood'] = 'casual';
    if (text.includes('elegant') || text.includes('sophisticated')) {
      mood = 'elegant';
    } else if (text.includes('edgy') || text.includes('rock') || text.includes('punk')) {
      mood = 'edgy';
    } else if (text.includes('romantic') || text.includes('feminine') || text.includes('floral')) {
      mood = 'romantic';
    } else if (text.includes('professional') || text.includes('business')) {
      mood = 'professional';
    } else if (text.includes('fun') || text.includes('playful') || text.includes('colorful')) {
      mood = 'playful';
    }

    // Season detection
    let season: VisualFeatures['style']['season'] = 'all-season';
    if (text.includes('summer') || text.includes('light') || text.includes('breathable')) {
      season = 'summer';
    } else if (text.includes('winter') || text.includes('warm') || text.includes('coat')) {
      season = 'winter';
    } else if (text.includes('spring') || text.includes('light jacket')) {
      season = 'spring';
    } else if (text.includes('fall') || text.includes('autumn') || text.includes('sweater')) {
      season = 'fall';
    }

    return { category: styleCategory, mood, season };
  }

  private calculateColorSimilarity(color1: ColorProfile, color2: ColorProfile): number {
    // Compare dominant colors using LAB color space for perceptual accuracy
    let totalSimilarity = 0;
    let weightSum = 0;

    for (const c1 of color1.dominantColors) {
      let bestMatch = 0;
      for (const c2 of color2.dominantColors) {
        const similarity = this.calculateColorDistance(c1, c2);
        bestMatch = Math.max(bestMatch, similarity);
      }
      totalSimilarity += bestMatch * c1.percentage;
      weightSum += c1.percentage;
    }

    const colorSimilarity = weightSum > 0 ? totalSimilarity / weightSum : 0;
    
    // Factor in temperature and brightness similarity
    const tempSimilarity = color1.temperature === color2.temperature ? 0.2 : 0;
    const brightnessSimilarity = 1 - Math.abs(color1.brightness - color2.brightness);
    
    return Math.min(1, colorSimilarity * 0.6 + tempSimilarity + brightnessSimilarity * 0.2);
  }

  private calculateStyleSimilarity(style1: VisualFeatures['style'], style2: VisualFeatures['style']): number {
    let similarity = 0;
    
    if (style1.category === style2.category) similarity += 0.4;
    if (style1.mood === style2.mood) similarity += 0.3;
    if (style1.season === style2.season) similarity += 0.3;
    
    return similarity;
  }

  private calculateShapeSimilarity(shape1: VisualFeatures['shape'], shape2: VisualFeatures['shape']): number {
    let similarity = 0;
    
    if (shape1.silhouette === shape2.silhouette) similarity += 0.5;
    if (shape1.neckline && shape2.neckline && shape1.neckline === shape2.neckline) similarity += 0.25;
    if (shape1.sleeves && shape2.sleeves && shape1.sleeves === shape2.sleeves) similarity += 0.25;
    
    return similarity;
  }

  private calculateColorDistance(color1: { r: number; g: number; b: number }, color2: { r: number; g: number; b: number }): number {
    // Convert to LAB color space for better perceptual distance
    const lab1 = this.rgbToLab(color1.r, color1.g, color1.b);
    const lab2 = this.rgbToLab(color2.r, color2.g, color2.b);
    
    const deltaE = Math.sqrt(
      Math.pow(lab1.l - lab2.l, 2) +
      Math.pow(lab1.a - lab2.a, 2) +
      Math.pow(lab1.b - lab2.b, 2)
    );
    
    // Normalize deltaE to 0-1 scale (deltaE of 100 = 0 similarity)
    return Math.max(0, 1 - deltaE / 100);
  }

  private generateMatchReasons(
    target: VisualFeatures,
    candidate: VisualFeatures,
    similarities: { colorSimilarity: number; styleSimilarity: number; shapeSimilarity: number }
  ): string[] {
    const reasons: string[] = [];
    
    if (similarities.colorSimilarity > 0.7) {
      reasons.push('Similar color palette');
    }
    
    if (target.style.category === candidate.style.category) {
      reasons.push(`Both are ${target.style.category} style`);
    }
    
    if (target.style.mood === candidate.style.mood) {
      reasons.push(`Similar ${target.style.mood} mood`);
    }
    
    if (target.shape.silhouette === candidate.shape.silhouette) {
      reasons.push(`Same ${target.shape.silhouette} silhouette`);
    }
    
    if (target.colors.temperature === candidate.colors.temperature) {
      reasons.push(`Both have ${target.colors.temperature} color temperature`);
    }
    
    return reasons;
  }

  // Helper methods
  private rgbToHex(r: number, g: number, b: number): string {
    return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
  }

  private calculateBrightness(color: number[]): number {
    return (0.299 * color[0] + 0.587 * color[1] + 0.114 * color[2]) / 255;
  }

  private calculateSaturation(color: number[]): number {
    const max = Math.max(...color);
    const min = Math.min(...color);
    return max === 0 ? 0 : (max - min) / max;
  }

  private determineTemperature(color: number[]): 'warm' | 'cool' | 'neutral' {
    const [r, g, b] = color;
    const warmth = (r - b) / 255;
    
    if (warmth > 0.2) return 'warm';
    if (warmth < -0.2) return 'cool';
    return 'neutral';
  }

  private rgbToLab(r: number, g: number, b: number): { l: number; a: number; b: number } {
    // Simplified RGB to LAB conversion
    let x = (r / 255) * 100;
    let y = (g / 255) * 100;
    let z = (b / 255) * 100;
    
    return {
      l: y,
      a: (x - y) * 2,
      b: (y - z) * 2
    };
  }

  private detectEdges(image: any): number {
    // Simplified edge detection - count significant color changes
    let edgeCount = 0;
    const width = image.getWidth();
    const height = image.getHeight();
    
    for (let y = 1; y < height - 1; y++) {
      for (let x = 1; x < width - 1; x++) {
        const current = Jimp.intToRGBA(image.getPixelColor(x, y));
        const right = Jimp.intToRGBA(image.getPixelColor(x + 1, y));
        const down = Jimp.intToRGBA(image.getPixelColor(x, y + 1));
        
        const diffRight = Math.abs(current.r - right.r) + Math.abs(current.g - right.g) + Math.abs(current.b - right.b);
        const diffDown = Math.abs(current.r - down.r) + Math.abs(current.g - down.g) + Math.abs(current.b - down.b);
        
        if (diffRight > 50 || diffDown > 50) {
          edgeCount++;
        }
      }
    }
    
    return edgeCount;
  }

  private detectPattern(image: any): VisualFeatures['texture']['pattern'] {
    // Simplified pattern detection based on edge distribution
    const edgeCount = this.detectEdges(image);
    const totalPixels = image.getWidth() * image.getHeight();
    const edgeRatio = edgeCount / totalPixels;
    
    if (edgeRatio < 0.05) return 'solid';
    if (edgeRatio > 0.2) return 'geometric';
    return 'abstract';
  }

  private getDefaultFeatures(product: IProduct): VisualFeatures {
    return {
      colors: {
        dominantColors: [{ r: 128, g: 128, b: 128, percentage: 1.0 }],
        colorPalette: ['#808080'],
        brightness: 0.5,
        saturation: 0.5,
        temperature: 'neutral'
      },
      texture: {
        smoothness: 0.5,
        pattern: 'solid',
        complexity: 0.5
      },
      shape: {
        silhouette: 'fitted'
      },
      style: {
        category: 'casual',
        mood: 'playful',
        season: 'all-season'
      }
    };
  }
}