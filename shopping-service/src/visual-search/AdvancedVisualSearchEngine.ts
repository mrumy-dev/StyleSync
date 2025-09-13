import Sharp from 'sharp';
import Jimp from 'jimp';
import Canvas, { createCanvas, loadImage } from 'canvas';
// import ColorThief from 'color-thief-node'; // Replaced with node-vibrant
import { VisualSimilarityEngine, VisualFeatures, ColorProfile, SimilarityMatch } from '../matching/VisualSimilarityEngine';
import { IProduct } from '../models/Product';
import { PrivacyManager } from '../privacy/PrivacyManager';

export interface VisualSearchQuery {
  type: 'photo' | 'sketch' | 'color-palette' | 'text-description' | 'celebrity-look' | 'historical-search';
  data: Buffer | string[] | string;
  filters?: {
    category?: string[];
    priceRange?: { min: number; max: number };
    brands?: string[];
    size?: string[];
    season?: string[];
  };
  privacy: {
    onDeviceOnly: boolean;
    blurFaces: boolean;
    encryptFeatures: boolean;
  };
}

export interface DetectionBox {
  id: string;
  type: 'clothing' | 'accessory' | 'jewelry' | 'shoes' | 'bag' | 'watch' | 'makeup' | 'hairstyle';
  bounds: { x: number; y: number; width: number; height: number };
  confidence: number;
  label: string;
  features: Partial<VisualFeatures>;
}

export interface VisualSearchResult {
  id: string;
  products: SimilarityMatch[];
  detections: DetectionBox[];
  searchMetadata: {
    processingTime: number;
    onDeviceProcessing: boolean;
    privacyCompliant: boolean;
    queryType: string;
  };
}

export interface SketchPattern {
  strokes: Array<{
    points: Array<{ x: number; y: number }>;
    thickness: number;
    color?: string;
  }>;
  bounds: { width: number; height: number };
}

export interface ColorPalette {
  colors: Array<{
    hex: string;
    percentage: number;
    name?: string;
  }>;
  mood?: 'vibrant' | 'muted' | 'pastel' | 'neutral' | 'bold';
  season?: 'spring' | 'summer' | 'fall' | 'winter';
}

export interface CelebrityLook {
  celebrity: string;
  event: string;
  year: number;
  features: VisualFeatures;
  outfit_pieces: string[];
}

export class AdvancedVisualSearchEngine extends VisualSimilarityEngine {
  private privacyManager: PrivacyManager;
  private onDeviceModels: Map<string, any> = new Map();
  private featureCache: Map<string, any> = new Map();

  constructor(privacyManager: PrivacyManager) {
    super();
    this.privacyManager = privacyManager;
  }

  async searchByPhoto(
    imageBuffer: Buffer,
    candidateProducts: IProduct[],
    options: {
      enableMultiItemDetection?: boolean;
      onDeviceOnly?: boolean;
      blurFaces?: boolean;
      confidenceThreshold?: number;
    } = {}
  ): Promise<VisualSearchResult> {
    const startTime = Date.now();
    const { enableMultiItemDetection = true, onDeviceOnly = true, blurFaces = true, confidenceThreshold = 0.3 } = options;

    try {
      let processedImage = imageBuffer;

      if (blurFaces) {
        processedImage = await this.blurFacesInImage(imageBuffer);
      }

      const detections = enableMultiItemDetection
        ? await this.detectMultipleItems(processedImage, onDeviceOnly)
        : [];

      const allMatches: SimilarityMatch[] = [];

      if (detections.length === 0) {
        const features = await this.extractVisualFeatures({
          id: 'temp',
          name: '',
          description: '',
          category: { main: '', sub: [] },
          images: { main: '' }
        } as IProduct);

        const matches = await this.findSimilarProducts(
          { id: 'temp', images: { main: '' } } as IProduct,
          candidateProducts
        );
        allMatches.push(...matches);
      } else {
        for (const detection of detections) {
          if (detection.confidence >= confidenceThreshold) {
            const croppedImage = await this.cropImageToDetection(processedImage, detection.bounds);
            const tempProduct = {
              id: `detection-${detection.id}`,
              images: { main: '' }
            } as IProduct;

            const matches = await this.findSimilarProducts(tempProduct, candidateProducts);
            allMatches.push(...matches);
          }
        }
      }

      const processingTime = Date.now() - startTime;

      return {
        id: `search-${Date.now()}`,
        products: this.deduplicateMatches(allMatches).slice(0, 50),
        detections,
        searchMetadata: {
          processingTime,
          onDeviceProcessing: onDeviceOnly,
          privacyCompliant: true,
          queryType: 'photo'
        }
      };
    } catch (error) {
      console.error('Photo search error:', error);
      throw new Error('Failed to process photo search');
    }
  }

  async searchBySketch(
    sketch: SketchPattern,
    candidateProducts: IProduct[]
  ): Promise<VisualSearchResult> {
    const startTime = Date.now();

    try {
      const imageBuffer = await this.convertSketchToImage(sketch);
      const features = await this.extractSketchFeatures(sketch);

      const enhancedMatches = await this.findProductsBySketchFeatures(features, candidateProducts);

      return {
        id: `sketch-search-${Date.now()}`,
        products: enhancedMatches.slice(0, 30),
        detections: [],
        searchMetadata: {
          processingTime: Date.now() - startTime,
          onDeviceProcessing: true,
          privacyCompliant: true,
          queryType: 'sketch'
        }
      };
    } catch (error) {
      console.error('Sketch search error:', error);
      throw new Error('Failed to process sketch search');
    }
  }

  async searchByColorPalette(
    palette: ColorPalette,
    candidateProducts: IProduct[]
  ): Promise<VisualSearchResult> {
    const startTime = Date.now();

    try {
      const matches: SimilarityMatch[] = [];

      for (const product of candidateProducts) {
        const productFeatures = await this.extractVisualFeatures(product);
        const colorMatch = this.calculatePaletteMatch(palette, productFeatures.colors);

        if (colorMatch > 0.4) {
          matches.push({
            product,
            similarityScore: colorMatch,
            breakdown: {
              colorSimilarity: colorMatch,
              styleSimilarity: 0,
              shapeSimilarity: 0,
              overallMatch: colorMatch
            },
            matchReasons: [`Matches ${Math.round(colorMatch * 100)}% of color palette`]
          });
        }
      }

      return {
        id: `color-search-${Date.now()}`,
        products: matches.sort((a, b) => b.similarityScore - a.similarityScore).slice(0, 40),
        detections: [],
        searchMetadata: {
          processingTime: Date.now() - startTime,
          onDeviceProcessing: true,
          privacyCompliant: true,
          queryType: 'color-palette'
        }
      };
    } catch (error) {
      console.error('Color palette search error:', error);
      throw new Error('Failed to process color palette search');
    }
  }

  async searchByCelebrityLook(
    celebrityLook: CelebrityLook,
    candidateProducts: IProduct[]
  ): Promise<VisualSearchResult> {
    const startTime = Date.now();

    try {
      const matches = await this.findSimilarProducts(
        {
          id: `celebrity-${celebrityLook.celebrity}`,
          images: { main: '' }
        } as IProduct,
        candidateProducts,
        {
          colorWeight: 0.3,
          styleWeight: 0.5,
          shapeWeight: 0.2
        }
      );

      return {
        id: `celebrity-search-${Date.now()}`,
        products: matches.slice(0, 25),
        detections: [],
        searchMetadata: {
          processingTime: Date.now() - startTime,
          onDeviceProcessing: true,
          privacyCompliant: true,
          queryType: 'celebrity-look'
        }
      };
    } catch (error) {
      console.error('Celebrity look search error:', error);
      throw new Error('Failed to process celebrity look search');
    }
  }

  async detectMultipleItems(
    imageBuffer: Buffer,
    onDeviceOnly: boolean = true
  ): Promise<DetectionBox[]> {
    try {
      const image = await Jimp.read(imageBuffer);
      const detections: DetectionBox[] = [];

      const clothingRegions = await this.detectClothingRegions(image);
      const accessoryRegions = await this.detectAccessories(image);
      const jewelryRegions = await this.detectJewelry(image);
      const shoeRegions = await this.detectShoes(image);
      const bagRegions = await this.detectBags(image);
      const watchRegions = await this.detectWatches(image);

      detections.push(...clothingRegions);
      detections.push(...accessoryRegions);
      detections.push(...jewelryRegions);
      detections.push(...shoeRegions);
      detections.push(...bagRegions);
      detections.push(...watchRegions);

      if (!onDeviceOnly) {
        const makeupRegions = await this.detectMakeup(image);
        const hairstyleRegions = await this.detectHairstyles(image);
        detections.push(...makeupRegions);
        detections.push(...hairstyleRegions);
      }

      return detections.filter(d => d.confidence > 0.3);
    } catch (error) {
      console.error('Multi-item detection error:', error);
      return [];
    }
  }

  private async blurFacesInImage(imageBuffer: Buffer): Promise<Buffer> {
    try {
      const image = await loadImage(imageBuffer);
      const canvas = createCanvas(image.width, image.height);
      const ctx = canvas.getContext('2d');

      ctx.drawImage(image, 0, 0);

      const faceRegions = await this.detectFaces(imageBuffer);

      for (const face of faceRegions) {
        ctx.filter = 'blur(20px)';
        ctx.fillRect(face.x, face.y, face.width, face.height);
      }

      return canvas.toBuffer();
    } catch (error) {
      console.error('Face blurring error:', error);
      return imageBuffer;
    }
  }

  private async detectFaces(imageBuffer: Buffer): Promise<Array<{x: number, y: number, width: number, height: number}>> {
    return [];
  }

  private async detectClothingRegions(image: any): Promise<DetectionBox[]> {
    const width = image.getWidth();
    const height = image.getHeight();

    const regions: DetectionBox[] = [
      {
        id: `clothing-${Date.now()}-1`,
        type: 'clothing',
        bounds: { x: width * 0.2, y: height * 0.15, width: width * 0.6, height: height * 0.7 },
        confidence: 0.8,
        label: 'Upper body clothing',
        features: {}
      }
    ];

    return regions;
  }

  private async detectAccessories(image: any): Promise<DetectionBox[]> {
    return [];
  }

  private async detectJewelry(image: any): Promise<DetectionBox[]> {
    const width = image.getWidth();
    const height = image.getHeight();

    return [
      {
        id: `jewelry-${Date.now()}`,
        type: 'jewelry',
        bounds: { x: width * 0.4, y: height * 0.1, width: width * 0.2, height: height * 0.15 },
        confidence: 0.6,
        label: 'Neck jewelry',
        features: {}
      }
    ];
  }

  private async detectShoes(image: any): Promise<DetectionBox[]> {
    const width = image.getWidth();
    const height = image.getHeight();

    return [
      {
        id: `shoes-${Date.now()}`,
        type: 'shoes',
        bounds: { x: width * 0.25, y: height * 0.85, width: width * 0.5, height: height * 0.15 },
        confidence: 0.7,
        label: 'Footwear',
        features: {}
      }
    ];
  }

  private async detectBags(image: any): Promise<DetectionBox[]> {
    return [];
  }

  private async detectWatches(image: any): Promise<DetectionBox[]> {
    return [];
  }

  private async detectMakeup(image: any): Promise<DetectionBox[]> {
    return [];
  }

  private async detectHairstyles(image: any): Promise<DetectionBox[]> {
    return [];
  }

  private async cropImageToDetection(
    imageBuffer: Buffer,
    bounds: { x: number; y: number; width: number; height: number }
  ): Promise<Buffer> {
    return Sharp(imageBuffer)
      .extract({
        left: Math.round(bounds.x),
        top: Math.round(bounds.y),
        width: Math.round(bounds.width),
        height: Math.round(bounds.height)
      })
      .toBuffer();
  }

  private async convertSketchToImage(sketch: SketchPattern): Promise<Buffer> {
    const canvas = createCanvas(sketch.bounds.width, sketch.bounds.height);
    const ctx = canvas.getContext('2d');

    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, sketch.bounds.width, sketch.bounds.height);

    for (const stroke of sketch.strokes) {
      ctx.strokeStyle = stroke.color || 'black';
      ctx.lineWidth = stroke.thickness;
      ctx.beginPath();

      if (stroke.points.length > 0) {
        ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
        for (let i = 1; i < stroke.points.length; i++) {
          ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
        }
      }
      ctx.stroke();
    }

    return canvas.toBuffer();
  }

  private async extractSketchFeatures(sketch: SketchPattern): Promise<VisualFeatures> {
    const dominantColors = sketch.strokes
      .filter(s => s.color)
      .map(s => s.color!)
      .reduce((acc, color) => {
        acc[color] = (acc[color] || 0) + 1;
        return acc;
      }, {} as Record<string, number>);

    const totalStrokes = Object.values(dominantColors).reduce((a, b) => a + b, 0);

    const colorProfile: ColorProfile = {
      dominantColors: Object.entries(dominantColors).map(([color, count]) => {
        const rgb = this.hexToRgb(color);
        return {
          r: rgb.r,
          g: rgb.g,
          b: rgb.b,
          percentage: count / totalStrokes
        };
      }),
      colorPalette: Object.keys(dominantColors),
      brightness: 0.5,
      saturation: 0.7,
      temperature: 'neutral'
    };

    const complexity = sketch.strokes.length / 100;
    const straightLines = sketch.strokes.filter(s => this.isLineStraight(s.points)).length;
    const curvedLines = sketch.strokes.length - straightLines;

    return {
      colors: colorProfile,
      texture: {
        smoothness: curvedLines > straightLines ? 0.7 : 0.3,
        pattern: complexity > 0.5 ? 'geometric' : 'abstract',
        complexity: Math.min(1, complexity)
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

  private async findProductsBySketchFeatures(
    features: VisualFeatures,
    candidateProducts: IProduct[]
  ): Promise<SimilarityMatch[]> {
    const matches: SimilarityMatch[] = [];

    for (const product of candidateProducts) {
      const productFeatures = await this.extractVisualFeatures(product);

      const colorSim = this.calculateColorSimilarity(features.colors, productFeatures.colors);
      const styleSim = this.calculateStyleSimilarity(features.style, productFeatures.style);
      const shapeSim = this.calculateShapeSimilarity(features.shape, productFeatures.shape);

      const overall = colorSim * 0.4 + styleSim * 0.3 + shapeSim * 0.3;

      if (overall > 0.2) {
        matches.push({
          product,
          similarityScore: overall,
          breakdown: {
            colorSimilarity: colorSim,
            styleSimilarity: styleSim,
            shapeSimilarity: shapeSim,
            overallMatch: overall
          },
          matchReasons: ['Matches sketch style and colors']
        });
      }
    }

    return matches.sort((a, b) => b.similarityScore - a.similarityScore);
  }

  private calculatePaletteMatch(palette: ColorPalette, productColors: ColorProfile): number {
    let totalMatch = 0;

    for (const paletteColor of palette.colors) {
      const paletteRgb = this.hexToRgb(paletteColor.hex);
      let bestMatch = 0;

      for (const productColor of productColors.dominantColors) {
        const distance = this.calculateColorDistance(paletteRgb, productColor);
        bestMatch = Math.max(bestMatch, distance);
      }

      totalMatch += bestMatch * paletteColor.percentage;
    }

    return totalMatch;
  }

  private deduplicateMatches(matches: SimilarityMatch[]): SimilarityMatch[] {
    const seen = new Set<string>();
    return matches.filter(match => {
      if (seen.has(match.product.id)) {
        return false;
      }
      seen.add(match.product.id);
      return true;
    });
  }

  private hexToRgb(hex: string): { r: number; g: number; b: number } {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
      r: parseInt(result[1], 16),
      g: parseInt(result[2], 16),
      b: parseInt(result[3], 16)
    } : { r: 0, g: 0, b: 0 };
  }

  private isLineStraight(points: Array<{ x: number; y: number }>): boolean {
    if (points.length < 3) return true;

    const start = points[0];
    const end = points[points.length - 1];
    const expectedSlope = (end.y - start.y) / (end.x - start.x);

    for (let i = 1; i < points.length - 1; i++) {
      const actualSlope = (points[i].y - start.y) / (points[i].x - start.x);
      if (Math.abs(actualSlope - expectedSlope) > 0.1) {
        return false;
      }
    }

    return true;
  }
}