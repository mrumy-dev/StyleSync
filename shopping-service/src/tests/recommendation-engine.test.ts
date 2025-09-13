import { AIRecommendationEngine, RecommendationContext } from '../ai/RecommendationEngine';
import { IUserPreferences } from '../models/UserPreferences';
import { IProduct } from '../models/Product';

// Mock data for testing
const mockUserPreferences: IUserPreferences = {
  userId: 'test-user-1',
  shopping: {
    favoriteCategories: ['dresses', 'tops'],
    favoriteBrands: ['Zara', 'H&M'],
    preferredStores: ['Zara', 'H&M', 'Uniqlo'],
    priceRange: {
      min: 20,
      max: 150
    },
    sizes: {
      tops: ['S', 'M'],
      bottoms: ['S', 'M'],
      shoes: ['7', '7.5'],
      dresses: ['S', 'M']
    },
    style: {
      preferences: ['casual', 'minimalist'],
      colors: ['blue', 'white', 'black'],
      patterns: ['solid', 'stripes'],
      occasions: ['work', 'casual']
    },
    sustainability: {
      importance: 'medium',
      certifications: ['GOTS', 'OEKO-TEX'],
      preferEcoFriendly: true
    }
  },
  notifications: {
    priceDrops: {
      enabled: true,
      threshold: 20
    },
    stockAlerts: true,
    newArrivals: false,
    salesAndOffers: true,
    recommendations: true,
    channels: ['push', 'email'],
    frequency: 'daily',
    quietHours: {
      enabled: true,
      start: '22:00',
      end: '08:00'
    }
  },
  privacy: {
    dataRetentionDays: 90,
    shareWithPartners: false,
    personalizedAds: false,
    trackingOptOut: true,
    anonymousMode: false
  },
  recommendations: {
    visualSimilarity: {
      enabled: true,
      weight: 0.4
    },
    styleSimilarity: {
      enabled: true,
      weight: 0.3
    },
    priceBasedSuggestions: true,
    crossCategoryRecommendations: true,
    trendingItems: false
  },
  accessibility: {
    highContrast: false,
    largeText: false,
    screenReader: false,
    colorBlindFriendly: false
  },
  metadata: {
    createdAt: new Date(),
    lastUpdated: new Date(),
    profileCompleteness: 0.8,
    onboardingCompleted: true
  }
} as any;

const mockProducts: IProduct[] = [
  {
    id: '1',
    name: 'Classic Blue Dress',
    brand: 'Zara',
    price: { current: 79.99, original: 99.99, currency: 'USD' },
    images: ['https://example.com/dress1.jpg'],
    category: { main: 'dresses', sub: 'midi', tags: ['casual', 'summer'] },
    colors: ['blue'],
    sizes: ['S', 'M', 'L'],
    description: 'A beautiful midi dress perfect for summer occasions',
    inStock: true,
    rating: { average: 4.5, count: 128 },
    materials: ['cotton', 'polyester'],
    sustainability: { score: 8, certifications: ['GOTS'] },
    createdAt: new Date(),
    updatedAt: new Date()
  } as any,
  {
    id: '2',
    name: 'Minimalist White Top',
    brand: 'H&M',
    price: { current: 29.99, currency: 'USD' },
    images: ['https://example.com/top1.jpg'],
    category: { main: 'tops', sub: 'blouse', tags: ['minimalist', 'work'] },
    colors: ['white'],
    sizes: ['XS', 'S', 'M', 'L'],
    description: 'Clean lines and classic style for the modern woman',
    inStock: true,
    rating: { average: 4.2, count: 89 },
    materials: ['cotton'],
    sustainability: { score: 6 },
    createdAt: new Date(),
    updatedAt: new Date()
  } as any
];

const mockContext: RecommendationContext = {
  userId: 'test-user-1',
  timestamp: new Date(),
  timeOfDay: 'morning',
  dayOfWeek: 'Monday',
  weather: {
    temperature: 22,
    condition: 'sunny',
    humidity: 60
  },
  location: {
    latitude: 40.7128,
    longitude: -74.0060,
    context: 'work'
  },
  calendar: {
    hasEvents: true,
    eventTypes: ['meeting'],
    formalityLevel: 'business'
  },
  mood: {
    detected: 'professional',
    confidence: 0.8
  },
  energyLevel: 'high',
  socialPlans: false,
  budget: {
    available: 200,
    category: 'medium'
  }
};

describe('AI Recommendation Engine', () => {
  let engine: AIRecommendationEngine;

  beforeAll(async () => {
    engine = new AIRecommendationEngine();
    // Wait for initialization
    await new Promise(resolve => setTimeout(resolve, 2000));
  });

  afterAll(async () => {
    if (engine) {
      await engine.dispose();
    }
  });

  test('should initialize successfully', () => {
    expect(engine).toBeDefined();
  });

  test('should generate recommendations', async () => {
    const recommendations = await engine.getRecommendations(
      'test-user-1',
      mockUserPreferences,
      mockContext,
      mockProducts,
      { maxResults: 5, includeExplanations: true }
    );

    expect(recommendations).toBeDefined();
    expect(Array.isArray(recommendations)).toBe(true);
    expect(recommendations.length).toBeGreaterThan(0);
    expect(recommendations.length).toBeLessThanOrEqual(5);

    // Check recommendation structure
    const firstRec = recommendations[0];
    expect(firstRec).toHaveProperty('product');
    expect(firstRec).toHaveProperty('score');
    expect(firstRec).toHaveProperty('reasoning');
    expect(firstRec).toHaveProperty('rank');
    expect(firstRec).toHaveProperty('category');

    // Check score structure
    expect(firstRec.score).toHaveProperty('overall');
    expect(firstRec.score).toHaveProperty('breakdown');
    expect(firstRec.score).toHaveProperty('confidence');
    expect(firstRec.score.overall).toBeGreaterThan(0);
    expect(firstRec.score.overall).toBeLessThanOrEqual(1);
  }, 30000);

  test('should handle empty product list', async () => {
    const recommendations = await engine.getRecommendations(
      'test-user-1',
      mockUserPreferences,
      mockContext,
      [],
      { maxResults: 5 }
    );

    expect(recommendations).toBeDefined();
    expect(Array.isArray(recommendations)).toBe(true);
    expect(recommendations.length).toBe(0);
  });

  test('should learn from feedback', async () => {
    const feedback = {
      userId: 'test-user-1',
      productId: '1',
      interactionType: 'like' as const,
      timestamp: new Date(),
      context: mockContext,
      implicitSignals: {
        viewDuration: 30,
        scrollDepth: 0.8,
        clickPosition: 1
      },
      explicitRating: 5
    };

    await expect(engine.learnFromFeedback(feedback)).resolves.not.toThrow();
  });

  test('should respect maxResults parameter', async () => {
    const recommendations = await engine.getRecommendations(
      'test-user-1',
      mockUserPreferences,
      mockContext,
      mockProducts,
      { maxResults: 1 }
    );

    expect(recommendations.length).toBeLessThanOrEqual(1);
  });

  test('should include explanations when requested', async () => {
    const recommendations = await engine.getRecommendations(
      'test-user-1',
      mockUserPreferences,
      mockContext,
      mockProducts,
      { maxResults: 2, includeExplanations: true }
    );

    expect(recommendations.length).toBeGreaterThan(0);

    const firstRec = recommendations[0];
    expect(firstRec.reasoning).toBeDefined();
    expect(firstRec.reasoning.whyRecommended).toBeDefined();
    expect(Array.isArray(firstRec.reasoning.whyRecommended)).toBe(true);
  });
});

describe('Recommendation Context Processing', () => {
  test('should handle different times of day', async () => {
    const contexts = [
      { ...mockContext, timeOfDay: 'morning' as const },
      { ...mockContext, timeOfDay: 'afternoon' as const },
      { ...mockContext, timeOfDay: 'evening' as const },
      { ...mockContext, timeOfDay: 'night' as const }
    ];

    const engine = new AIRecommendationEngine();

    for (const context of contexts) {
      const recommendations = await engine.getRecommendations(
        'test-user-1',
        mockUserPreferences,
        context,
        mockProducts,
        { maxResults: 2 }
      );

      expect(recommendations).toBeDefined();
      expect(Array.isArray(recommendations)).toBe(true);
    }

    await engine.dispose();
  });

  test('should handle weather context', async () => {
    const weatherContexts = [
      { ...mockContext, weather: { temperature: 5, condition: 'cold', humidity: 70 } },
      { ...mockContext, weather: { temperature: 30, condition: 'hot', humidity: 80 } },
      { ...mockContext, weather: { temperature: 15, condition: 'rainy', humidity: 90 } }
    ];

    const engine = new AIRecommendationEngine();

    for (const context of weatherContexts) {
      const recommendations = await engine.getRecommendations(
        'test-user-1',
        mockUserPreferences,
        context,
        mockProducts,
        { maxResults: 2 }
      );

      expect(recommendations).toBeDefined();
    }

    await engine.dispose();
  });
});

describe('Learning System Integration', () => {
  test('should process different feedback types', async () => {
    const engine = new AIRecommendationEngine();

    const feedbackTypes = ['view', 'like', 'dislike', 'share', 'purchase', 'skip', 'save'] as const;

    for (const type of feedbackTypes) {
      const feedback = {
        userId: 'test-user-1',
        productId: '1',
        interactionType: type,
        timestamp: new Date(),
        context: mockContext,
        implicitSignals: {
          viewDuration: Math.random() * 60,
          scrollDepth: Math.random(),
          clickPosition: Math.floor(Math.random() * 10)
        }
      };

      await expect(engine.learnFromFeedback(feedback)).resolves.not.toThrow();
    }

    await engine.dispose();
  });

  test('should handle feedback with explicit ratings', async () => {
    const engine = new AIRecommendationEngine();

    const feedback = {
      userId: 'test-user-1',
      productId: '1',
      interactionType: 'like' as const,
      timestamp: new Date(),
      context: mockContext,
      implicitSignals: {
        viewDuration: 45,
        scrollDepth: 0.9,
        clickPosition: 2
      },
      explicitRating: 4,
      feedback: 'Great style but a bit expensive'
    };

    await expect(engine.learnFromFeedback(feedback)).resolves.not.toThrow();
    await engine.dispose();
  });
});

describe('Error Handling', () => {
  test('should handle invalid user preferences', async () => {
    const engine = new AIRecommendationEngine();

    const invalidPreferences = {} as IUserPreferences;

    await expect(
      engine.getRecommendations(
        'test-user-1',
        invalidPreferences,
        mockContext,
        mockProducts,
        { maxResults: 5 }
      )
    ).resolves.toBeDefined();

    await engine.dispose();
  });

  test('should handle missing context data', async () => {
    const engine = new AIRecommendationEngine();

    const minimalContext = {
      userId: 'test-user-1',
      timestamp: new Date(),
      timeOfDay: 'morning' as const,
      dayOfWeek: 'Monday'
    };

    await expect(
      engine.getRecommendations(
        'test-user-1',
        mockUserPreferences,
        minimalContext,
        mockProducts,
        { maxResults: 5 }
      )
    ).resolves.toBeDefined();

    await engine.dispose();
  });
});

// Performance tests
describe('Performance Tests', () => {
  test('should handle large product catalogs efficiently', async () => {
    const engine = new AIRecommendationEngine();

    // Generate large product catalog
    const largeProductCatalog = Array.from({ length: 1000 }, (_, i) => ({
      ...mockProducts[0],
      id: `product-${i}`,
      name: `Product ${i}`,
      price: { current: Math.random() * 200 + 20, currency: 'USD' }
    }));

    const startTime = Date.now();

    const recommendations = await engine.getRecommendations(
      'test-user-1',
      mockUserPreferences,
      mockContext,
      largeProductCatalog,
      { maxResults: 20 }
    );

    const endTime = Date.now();
    const duration = endTime - startTime;

    expect(recommendations).toBeDefined();
    expect(recommendations.length).toBeLessThanOrEqual(20);
    expect(duration).toBeLessThan(10000); // Should complete within 10 seconds

    await engine.dispose();
  }, 15000);

  test('should handle concurrent requests', async () => {
    const engine = new AIRecommendationEngine();

    const concurrentRequests = Array.from({ length: 5 }, (_, i) =>
      engine.getRecommendations(
        `test-user-${i}`,
        mockUserPreferences,
        mockContext,
        mockProducts,
        { maxResults: 5 }
      )
    );

    const results = await Promise.all(concurrentRequests);

    expect(results.length).toBe(5);
    results.forEach(result => {
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBeLessThanOrEqual(5);
    });

    await engine.dispose();
  });
});

export {};