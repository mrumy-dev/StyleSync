import { IProduct } from '../models/Product';
import { IUserPreferences } from '../models/UserPreferences';
import { EventEmitter } from 'events';


export interface RecommendationContext {
  userId: string;
  timestamp: Date;
  timeOfDay: 'morning' | 'afternoon' | 'evening' | 'night';
  dayOfWeek: string;
  weather?: {
    temperature: number;
    condition: string;
    humidity: number;
  };
  location?: {
    latitude: number;
    longitude: number;
    context: 'home' | 'work' | 'travel' | 'social';
  };
  calendar?: {
    hasEvents: boolean;
    eventTypes: string[];
    formalityLevel: 'casual' | 'business' | 'formal';
  };
  mood?: {
    detected: string;
    confidence: number;
  };
  energyLevel?: 'low' | 'medium' | 'high';
  socialPlans?: boolean;
  budget?: {
    available: number;
    category: 'low' | 'medium' | 'high' | 'luxury';
  };
  recentPurchases?: IProduct[];
  wardrobeStatus?: {
    laundryPending: string[];
    availableItems: string[];
  };
}

export interface RecommendationScore {
  overall: number;
  breakdown: {
    collaborative: number;
    contentBased: number;
    contextual: number;
    deepLearning: number;
    reinforcement: number;
  };
  confidence: number;
  explanation: {
    primary: string;
    factors: string[];
    confidence: number;
    alternatives?: string[];
  };
}

export interface RecommendationResult {
  product: IProduct;
  score: RecommendationScore;
  reasoning: {
    whyRecommended: string[];
    styleRules: string[];
    personalizationFactors: string[];
    visualExplanation?: string;
    abTestGroup?: string;
  };
  rank: number;
  category: 'trending' | 'personalized' | 'similar' | 'contextual' | 'discovery';
}

export interface LearningFeedback {
  userId: string;
  productId: string;
  interactionType: 'view' | 'like' | 'dislike' | 'share' | 'purchase' | 'skip' | 'save';
  timestamp: Date;
  context: RecommendationContext;
  implicitSignals?: {
    viewDuration: number;
    scrollDepth: number;
    clickPosition: number;
  };
  explicitRating?: number; // 1-5 stars
  feedback?: string;
}

export class AIRecommendationEngine extends EventEmitter {
  private collaborativeModel?: tf.LayersModel;
  private contentModel?: tf.LayersModel;
  private deepLearningModel?: tf.LayersModel;
  private transformerModel?: tf.LayersModel;
  private reinforcementAgent?: any;
  private isInitialized = false;
  private userEmbeddings = new Map<string, Float32Array>();
  private productEmbeddings = new Map<string, Float32Array>();
  private contextualBandits = new Map<string, any>();
  private multiArmedBandits = new Map<string, any>();

  constructor() {
    super();
    this.initializeModels();
  }

  private async initializeModels(): Promise<void> {
    try {
      // Initialize TensorFlow models
      await this.loadCollaborativeFilteringModel();
      await this.loadContentBasedModel();
      await this.loadDeepLearningModel();
      await this.loadTransformerModel();

      // Initialize reinforcement learning
      this.initializeReinforcementLearning();

      // Initialize bandits
      this.initializeBandits();

      this.isInitialized = true;
      this.emit('initialized');
    } catch (error) {
      console.error('Failed to initialize AI models:', error);
      throw error;
    }
  }

  async getRecommendations(
    userId: string,
    preferences: IUserPreferences,
    context: RecommendationContext,
    availableProducts: IProduct[],
    options: {
      maxResults?: number;
      includeExplanations?: boolean;
      diversityWeight?: number;
      noveltyWeight?: number;
      mode?: 'smart' | 'inspiration' | 'similar' | 'random' | 'trending';
    } = {}
  ): Promise<RecommendationResult[]> {
    if (!this.isInitialized) {
      await this.initializeModels();
    }

    const config = {
      maxResults: options.maxResults || 20,
      includeExplanations: options.includeExplanations || true,
      diversityWeight: options.diversityWeight || 0.2,
      noveltyWeight: options.noveltyWeight || 0.1,
      mode: options.mode || 'smart'
    };

    // Generate recommendations from multiple algorithms
    const recommendations = new Map<string, RecommendationResult>();

    // 1. Collaborative Filtering
    const collaborativeRecs = await this.getCollaborativeRecommendations(
      userId, availableProducts, config.maxResults * 2
    );
    this.mergeRecommendations(recommendations, collaborativeRecs, 'collaborative');

    // 2. Content-Based Filtering
    const contentRecs = await this.getContentBasedRecommendations(
      preferences, availableProducts, config.maxResults * 2
    );
    this.mergeRecommendations(recommendations, contentRecs, 'content-based');

    // 3. Deep Learning Recommendations
    const deepLearningRecs = await this.getDeepLearningRecommendations(
      userId, preferences, context, availableProducts, config.maxResults * 2
    );
    this.mergeRecommendations(recommendations, deepLearningRecs, 'deep-learning');

    // 4. Transformer-based Recommendations
    const transformerRecs = await this.getTransformerRecommendations(
      userId, context, availableProducts, config.maxResults * 2
    );
    this.mergeRecommendations(recommendations, transformerRecs, 'transformer');

    // 5. Contextual Bandits
    const contextualRecs = await this.getContextualBanditsRecommendations(
      userId, context, availableProducts, config.maxResults
    );
    this.mergeRecommendations(recommendations, contextualRecs, 'contextual');

    // 6. Multi-Armed Bandits for exploration
    const explorationRecs = await this.getMultiArmedBanditsRecommendations(
      userId, availableProducts, config.maxResults
    );
    this.mergeRecommendations(recommendations, explorationRecs, 'exploration');

    // Apply final ranking and diversity
    const finalRecommendations = Array.from(recommendations.values())
      .map(rec => this.enhanceWithPersonalization(rec, preferences, context))
      .sort((a, b) => b.score.overall - a.score.overall);

    // Apply diversity and novelty
    const diversifiedRecs = this.applyDiversification(
      finalRecommendations,
      config.diversityWeight,
      config.noveltyWeight
    );

    // Generate explanations
    if (config.includeExplanations) {
      diversifiedRecs.forEach(rec => {
        rec.reasoning = this.generateExplanation(rec, preferences, context);
      });
    }

    return diversifiedRecs
      .slice(0, config.maxResults)
      .map((rec, index) => ({ ...rec, rank: index + 1 }));
  }

  private async loadCollaborativeFilteringModel(): Promise<void> {
    try {
      // Load pre-trained collaborative filtering model
      this.collaborativeModel = await tf.loadLayersModel('/models/collaborative_filtering.json');
    } catch (error) {
      // Create and train a new model if none exists
      this.collaborativeModel = this.createCollaborativeFilteringModel();
    }
  }

  private createCollaborativeFilteringModel(): tf.LayersModel {
    const numUsers = 10000; // Adjust based on user base
    const numProducts = 50000; // Adjust based on product catalog
    const embeddingDim = 128;

    const userInput = tf.input({ shape: [1], name: 'user_id' });
    const productInput = tf.input({ shape: [1], name: 'product_id' });

    const userEmbedding = tf.layers.embedding({
      inputDim: numUsers,
      outputDim: embeddingDim,
      name: 'user_embedding'
    }).apply(userInput) as tf.SymbolicTensor;

    const productEmbedding = tf.layers.embedding({
      inputDim: numProducts,
      outputDim: embeddingDim,
      name: 'product_embedding'
    }).apply(productInput) as tf.SymbolicTensor;

    const userFlat = tf.layers.flatten().apply(userEmbedding) as tf.SymbolicTensor;
    const productFlat = tf.layers.flatten().apply(productEmbedding) as tf.SymbolicTensor;

    const dot = tf.layers.dot({ axes: 1 }).apply([userFlat, productFlat]) as tf.SymbolicTensor;
    const output = tf.layers.dense({ units: 1, activation: 'sigmoid' }).apply(dot) as tf.SymbolicTensor;

    const model = tf.model({
      inputs: [userInput, productInput],
      outputs: output
    });

    model.compile({
      optimizer: 'adam',
      loss: 'binaryCrossentropy',
      metrics: ['accuracy']
    });

    return model;
  }

  private async loadContentBasedModel(): Promise<void> {
    try {
      this.contentModel = await tf.loadLayersModel('/models/content_based.json');
    } catch (error) {
      this.contentModel = this.createContentBasedModel();
    }
  }

  private createContentBasedModel(): tf.LayersModel {
    const inputShape = [100]; // Feature vector size

    const input = tf.input({ shape: inputShape });

    let x = tf.layers.dense({ units: 256, activation: 'relu' }).apply(input) as tf.SymbolicTensor;
    x = tf.layers.dropout({ rate: 0.2 }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dense({ units: 128, activation: 'relu' }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dropout({ rate: 0.2 }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dense({ units: 64, activation: 'relu' }).apply(x) as tf.SymbolicTensor;

    const output = tf.layers.dense({ units: 1, activation: 'sigmoid' }).apply(x) as tf.SymbolicTensor;

    const model = tf.model({ inputs: input, outputs: output });

    model.compile({
      optimizer: 'adam',
      loss: 'binaryCrossentropy',
      metrics: ['accuracy']
    });

    return model;
  }

  private async loadDeepLearningModel(): Promise<void> {
    try {
      this.deepLearningModel = await tf.loadLayersModel('/models/deep_learning.json');
    } catch (error) {
      this.deepLearningModel = this.createDeepLearningModel();
    }
  }

  private createDeepLearningModel(): tf.LayersModel {
    // Multi-input deep neural network
    const userFeatures = tf.input({ shape: [50], name: 'user_features' });
    const productFeatures = tf.input({ shape: [100], name: 'product_features' });
    const contextFeatures = tf.input({ shape: [30], name: 'context_features' });

    // User tower
    let userTower = tf.layers.dense({ units: 128, activation: 'relu' }).apply(userFeatures) as tf.SymbolicTensor;
    userTower = tf.layers.batchNormalization().apply(userTower) as tf.SymbolicTensor;
    userTower = tf.layers.dropout({ rate: 0.3 }).apply(userTower) as tf.SymbolicTensor;
    userTower = tf.layers.dense({ units: 64, activation: 'relu' }).apply(userTower) as tf.SymbolicTensor;

    // Product tower
    let productTower = tf.layers.dense({ units: 256, activation: 'relu' }).apply(productFeatures) as tf.SymbolicTensor;
    productTower = tf.layers.batchNormalization().apply(productTower) as tf.SymbolicTensor;
    productTower = tf.layers.dropout({ rate: 0.3 }).apply(productTower) as tf.SymbolicTensor;
    productTower = tf.layers.dense({ units: 128, activation: 'relu' }).apply(productTower) as tf.SymbolicTensor;
    productTower = tf.layers.dense({ units: 64, activation: 'relu' }).apply(productTower) as tf.SymbolicTensor;

    // Context tower
    let contextTower = tf.layers.dense({ units: 64, activation: 'relu' }).apply(contextFeatures) as tf.SymbolicTensor;
    contextTower = tf.layers.dropout({ rate: 0.2 }).apply(contextTower) as tf.SymbolicTensor;
    contextTower = tf.layers.dense({ units: 32, activation: 'relu' }).apply(contextTower) as tf.SymbolicTensor;

    // Combine all towers
    const combined = tf.layers.concatenate().apply([userTower, productTower, contextTower]) as tf.SymbolicTensor;

    let x = tf.layers.dense({ units: 256, activation: 'relu' }).apply(combined) as tf.SymbolicTensor;
    x = tf.layers.batchNormalization().apply(x) as tf.SymbolicTensor;
    x = tf.layers.dropout({ rate: 0.4 }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dense({ units: 128, activation: 'relu' }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dropout({ rate: 0.3 }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dense({ units: 64, activation: 'relu' }).apply(x) as tf.SymbolicTensor;

    const output = tf.layers.dense({ units: 1, activation: 'sigmoid' }).apply(x) as tf.SymbolicTensor;

    const model = tf.model({
      inputs: [userFeatures, productFeatures, contextFeatures],
      outputs: output
    });

    model.compile({
      optimizer: tf.train.adam(0.001),
      loss: 'binaryCrossentropy',
      metrics: ['accuracy', 'auc']
    });

    return model;
  }

  private async loadTransformerModel(): Promise<void> {
    try {
      this.transformerModel = await tf.loadLayersModel('/models/transformer.json');
    } catch (error) {
      this.transformerModel = this.createTransformerModel();
    }
  }

  private createTransformerModel(): tf.LayersModel {
    const seqLength = 50; // User interaction sequence length
    const embeddingDim = 128;
    const numHeads = 8;
    const ffDim = 512;

    const input = tf.input({ shape: [seqLength, embeddingDim] });

    // Multi-head attention layer
    let x = input;

    // Simplified transformer block (would need custom layers for full implementation)
    x = tf.layers.dense({ units: ffDim, activation: 'relu' }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dense({ units: embeddingDim }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.layerNormalization().apply(x) as tf.SymbolicTensor;

    // Global average pooling
    x = tf.layers.globalAveragePooling1d().apply(x) as tf.SymbolicTensor;

    // Classification head
    x = tf.layers.dense({ units: 256, activation: 'relu' }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dropout({ rate: 0.3 }).apply(x) as tf.SymbolicTensor;
    x = tf.layers.dense({ units: 128, activation: 'relu' }).apply(x) as tf.SymbolicTensor;

    const output = tf.layers.dense({ units: 1, activation: 'sigmoid' }).apply(x) as tf.SymbolicTensor;

    const model = tf.model({ inputs: input, outputs: output });

    model.compile({
      optimizer: tf.train.adam(0.001),
      loss: 'binaryCrossentropy',
      metrics: ['accuracy']
    });

    return model;
  }

  private initializeReinforcementLearning(): void {
    // Initialize Q-learning agent for recommendation optimization
    this.reinforcementAgent = {
      qTable: new Map(),
      learningRate: 0.1,
      discountFactor: 0.95,
      explorationRate: 0.1,

      getAction: (state: string) => {
        if (Math.random() < this.reinforcementAgent.explorationRate) {
          // Explore: random action
          return Math.floor(Math.random() * 10); // 10 possible actions
        } else {
          // Exploit: best known action
          const stateActions = this.reinforcementAgent.qTable.get(state) || {};
          return Object.keys(stateActions).reduce((best, action) =>
            (stateActions[action] > stateActions[best]) ? action : best, '0'
          );
        }
      },

      updateQValue: (state: string, action: string, reward: number, nextState: string) => {
        const currentQ = this.reinforcementAgent.qTable.get(state)?.[action] || 0;
        const nextStateActions = this.reinforcementAgent.qTable.get(nextState) || {};
        const maxNextQ = Math.max(...Object.values(nextStateActions), 0);

        const newQ = currentQ + this.reinforcementAgent.learningRate *
          (reward + this.reinforcementAgent.discountFactor * maxNextQ - currentQ);

        if (!this.reinforcementAgent.qTable.has(state)) {
          this.reinforcementAgent.qTable.set(state, {});
        }
        this.reinforcementAgent.qTable.get(state)[action] = newQ;
      }
    };
  }

  private initializeBandits(): void {
    // Multi-Armed Bandits for exploration vs exploitation
    this.multiArmedBandits.set('category_exploration', {
      arms: ['tops', 'bottoms', 'dresses', 'shoes', 'accessories'],
      counts: new Map(),
      rewards: new Map(),

      selectArm: function() {
        // UCB1 algorithm
        const totalCounts = Array.from(this.counts.values()).reduce((sum, count) => sum + count, 0);

        if (totalCounts === 0) {
          return this.arms[Math.floor(Math.random() * this.arms.length)];
        }

        const ucbValues = this.arms.map(arm => {
          const count = this.counts.get(arm) || 0;
          const reward = this.rewards.get(arm) || 0;

          if (count === 0) return Infinity;

          const averageReward = reward / count;
          const confidence = Math.sqrt((2 * Math.log(totalCounts)) / count);

          return averageReward + confidence;
        });

        const bestArmIndex = ucbValues.indexOf(Math.max(...ucbValues));
        return this.arms[bestArmIndex];
      },

      updateReward: function(arm: string, reward: number) {
        this.counts.set(arm, (this.counts.get(arm) || 0) + 1);
        this.rewards.set(arm, (this.rewards.get(arm) || 0) + reward);
      }
    });
  }

  private async getCollaborativeRecommendations(
    userId: string,
    products: IProduct[],
    maxResults: number
  ): Promise<RecommendationResult[]> {
    if (!this.collaborativeModel) return [];

    const userIdTensor = tf.tensor2d([[this.getUserIndex(userId)]]);
    const recommendations: RecommendationResult[] = [];

    for (const product of products.slice(0, maxResults)) {
      const productIdTensor = tf.tensor2d([[this.getProductIndex(product.id)]]);

      const prediction = this.collaborativeModel.predict([userIdTensor, productIdTensor]) as tf.Tensor;
      const score = await prediction.data();

      recommendations.push({
        product,
        score: {
          overall: score[0],
          breakdown: {
            collaborative: score[0],
            contentBased: 0,
            contextual: 0,
            deepLearning: 0,
            reinforcement: 0
          },
          confidence: score[0],
          explanation: {
            primary: 'Users with similar preferences also liked this item',
            factors: ['Collaborative filtering', 'User similarity'],
            confidence: score[0]
          }
        },
        reasoning: {
          whyRecommended: [],
          styleRules: [],
          personalizationFactors: []
        },
        rank: 0,
        category: 'personalized'
      });

      prediction.dispose();
      productIdTensor.dispose();
    }

    userIdTensor.dispose();
    return recommendations.sort((a, b) => b.score.overall - a.score.overall);
  }

  private async getContentBasedRecommendations(
    preferences: IUserPreferences,
    products: IProduct[],
    maxResults: number
  ): Promise<RecommendationResult[]> {
    if (!this.contentModel) return [];

    const recommendations: RecommendationResult[] = [];

    for (const product of products.slice(0, maxResults)) {
      const features = this.extractProductFeatures(product, preferences);
      const featureTensor = tf.tensor2d([features]);

      const prediction = this.contentModel.predict(featureTensor) as tf.Tensor;
      const score = await prediction.data();

      recommendations.push({
        product,
        score: {
          overall: score[0],
          breakdown: {
            collaborative: 0,
            contentBased: score[0],
            contextual: 0,
            deepLearning: 0,
            reinforcement: 0
          },
          confidence: score[0],
          explanation: {
            primary: 'Matches your style preferences and past choices',
            factors: ['Style similarity', 'Category preference', 'Brand preference'],
            confidence: score[0]
          }
        },
        reasoning: {
          whyRecommended: [],
          styleRules: [],
          personalizationFactors: []
        },
        rank: 0,
        category: 'similar'
      });

      prediction.dispose();
      featureTensor.dispose();
    }

    return recommendations.sort((a, b) => b.score.overall - a.score.overall);
  }

  private async getDeepLearningRecommendations(
    userId: string,
    preferences: IUserPreferences,
    context: RecommendationContext,
    products: IProduct[],
    maxResults: number
  ): Promise<RecommendationResult[]> {
    if (!this.deepLearningModel) return [];

    const userFeatures = this.extractUserFeatures(preferences, userId);
    const contextFeatures = this.extractContextFeatures(context);
    const recommendations: RecommendationResult[] = [];

    const userTensor = tf.tensor2d([userFeatures]);
    const contextTensor = tf.tensor2d([contextFeatures]);

    for (const product of products.slice(0, maxResults)) {
      const productFeatures = this.extractProductFeatures(product, preferences);
      const productTensor = tf.tensor2d([productFeatures]);

      const prediction = this.deepLearningModel.predict([
        userTensor, productTensor, contextTensor
      ]) as tf.Tensor;

      const score = await prediction.data();

      recommendations.push({
        product,
        score: {
          overall: score[0],
          breakdown: {
            collaborative: 0,
            contentBased: 0,
            contextual: 0,
            deepLearning: score[0],
            reinforcement: 0
          },
          confidence: score[0],
          explanation: {
            primary: 'AI analysis of your preferences, context, and product features',
            factors: ['Deep learning analysis', 'Multi-factor optimization'],
            confidence: score[0]
          }
        },
        reasoning: {
          whyRecommended: [],
          styleRules: [],
          personalizationFactors: []
        },
        rank: 0,
        category: 'personalized'
      });

      prediction.dispose();
      productTensor.dispose();
    }

    userTensor.dispose();
    contextTensor.dispose();

    return recommendations.sort((a, b) => b.score.overall - a.score.overall);
  }

  private async getTransformerRecommendations(
    userId: string,
    context: RecommendationContext,
    products: IProduct[],
    maxResults: number
  ): Promise<RecommendationResult[]> {
    // Implementation would require user interaction history
    // For now, return empty array - would be filled with actual transformer predictions
    return [];
  }

  private async getContextualBanditsRecommendations(
    userId: string,
    context: RecommendationContext,
    products: IProduct[],
    maxResults: number
  ): Promise<RecommendationResult[]> {
    // Contextual bandits based on context
    const contextKey = this.generateContextKey(context);
    let bandit = this.contextualBandits.get(contextKey);

    if (!bandit) {
      bandit = {
        arms: products.slice(0, 20).map(p => p.id),
        contexts: new Map(),
        rewards: new Map()
      };
      this.contextualBandits.set(contextKey, bandit);
    }

    // Select products based on contextual bandit algorithm
    const selectedProducts = products
      .filter(p => bandit.arms.includes(p.id))
      .slice(0, maxResults)
      .map(product => ({
        product,
        score: {
          overall: Math.random() * 0.3 + 0.4, // Placeholder scoring
          breakdown: {
            collaborative: 0,
            contentBased: 0,
            contextual: Math.random() * 0.3 + 0.4,
            deepLearning: 0,
            reinforcement: 0
          },
          confidence: Math.random() * 0.3 + 0.4,
          explanation: {
            primary: 'Selected based on current context and situation',
            factors: ['Time of day', 'Weather', 'Location context'],
            confidence: Math.random() * 0.3 + 0.4
          }
        },
        reasoning: {
          whyRecommended: [],
          styleRules: [],
          personalizationFactors: []
        },
        rank: 0,
        category: 'contextual' as const
      }));

    return selectedProducts;
  }

  private async getMultiArmedBanditsRecommendations(
    userId: string,
    products: IProduct[],
    maxResults: number
  ): Promise<RecommendationResult[]> {
    const categoryBandit = this.multiArmedBandits.get('category_exploration');
    if (!categoryBandit) return [];

    const selectedCategory = categoryBandit.selectArm();
    const categoryProducts = products.filter(p =>
      p.category.main.toLowerCase().includes(selectedCategory)
    );

    return categoryProducts
      .slice(0, maxResults)
      .map(product => ({
        product,
        score: {
          overall: Math.random() * 0.2 + 0.3, // Lower score for exploration
          breakdown: {
            collaborative: 0,
            contentBased: 0,
            contextual: 0,
            deepLearning: 0,
            reinforcement: Math.random() * 0.2 + 0.3
          },
          confidence: 0.5,
          explanation: {
            primary: 'Exploring new categories to discover your preferences',
            factors: ['Category exploration', 'Discovery algorithm'],
            confidence: 0.5
          }
        },
        reasoning: {
          whyRecommended: [],
          styleRules: [],
          personalizationFactors: []
        },
        rank: 0,
        category: 'discovery' as const
      }));
  }

  private mergeRecommendations(
    recommendations: Map<string, RecommendationResult>,
    newRecs: RecommendationResult[],
    source: string
  ): void {
    for (const rec of newRecs) {
      const existing = recommendations.get(rec.product.id);

      if (existing) {
        // Combine scores
        existing.score.overall = Math.max(existing.score.overall, rec.score.overall);
        Object.assign(existing.score.breakdown, rec.score.breakdown);
        existing.score.confidence = Math.max(existing.score.confidence, rec.score.confidence);
      } else {
        recommendations.set(rec.product.id, rec);
      }
    }
  }

  private enhanceWithPersonalization(
    rec: RecommendationResult,
    preferences: IUserPreferences,
    context: RecommendationContext
  ): RecommendationResult {
    const personalizationFactors = this.calculatePersonalizationFactors(
      rec.product, preferences, context
    );

    // Boost score based on personalization
    const personalizedScore = rec.score.overall * (1 + personalizationFactors.boost);

    return {
      ...rec,
      score: {
        ...rec.score,
        overall: Math.min(1, personalizedScore)
      },
      reasoning: {
        ...rec.reasoning,
        personalizationFactors: personalizationFactors.factors
      }
    };
  }

  private calculatePersonalizationFactors(
    product: IProduct,
    preferences: IUserPreferences,
    context: RecommendationContext
  ) {
    const factors: string[] = [];
    let boost = 0;

    // Time-based factors
    if (context.timeOfDay === 'morning' && product.category.tags.includes('workwear')) {
      factors.push('Perfect for morning work outfits');
      boost += 0.1;
    }

    // Weather-based factors
    if (context.weather) {
      if (context.weather.temperature < 10 && product.category.tags.includes('warm')) {
        factors.push('Warm clothing for cold weather');
        boost += 0.15;
      }
      if (context.weather.condition.includes('rain') && product.category.tags.includes('waterproof')) {
        factors.push('Weather-appropriate choice');
        boost += 0.2;
      }
    }

    // Style preference match
    const styleMatch = preferences.shopping.style.preferences.some(style =>
      product.category.tags.includes(style)
    );
    if (styleMatch) {
      factors.push('Matches your style preferences');
      boost += 0.1;
    }

    // Color preference match
    const colorMatch = preferences.shopping.style.colors.some(color =>
      product.colors?.some(pColor => pColor.toLowerCase().includes(color.toLowerCase()))
    );
    if (colorMatch) {
      factors.push('In your preferred colors');
      boost += 0.08;
    }

    // Brand preference
    if (preferences.shopping.favoriteBrands.includes(product.brand)) {
      factors.push('From your favorite brands');
      boost += 0.15;
    }

    // Price range match
    if (product.price.current >= preferences.shopping.priceRange.min &&
        product.price.current <= preferences.shopping.priceRange.max) {
      factors.push('Within your budget');
      boost += 0.05;
    }

    // Sustainability preference
    if (preferences.shopping.sustainability.preferEcoFriendly &&
        product.sustainability && product.sustainability.score > 7) {
      factors.push('Eco-friendly choice');
      boost += 0.12;
    }

    // Calendar/occasion context
    if (context.calendar?.formalityLevel === 'formal' &&
        product.category.tags.includes('formal')) {
      factors.push('Appropriate for your calendar events');
      boost += 0.2;
    }

    // Location context
    if (context.location?.context === 'work' &&
        product.category.tags.includes('professional')) {
      factors.push('Perfect for work setting');
      boost += 0.15;
    }

    // Recent purchases - avoid too similar items
    if (context.recentPurchases?.some(rp =>
        rp.category.main === product.category.main &&
        rp.category.sub === product.category.sub)) {
      boost -= 0.1;
      factors.push('Different from recent purchases');
    }

    return { factors, boost };
  }

  private applyDiversification(
    recommendations: RecommendationResult[],
    diversityWeight: number,
    noveltyWeight: number
  ): RecommendationResult[] {
    // Apply diversity to avoid too many similar items
    const diversified: RecommendationResult[] = [];
    const categoryCount = new Map<string, number>();
    const brandCount = new Map<string, number>();

    for (const rec of recommendations) {
      const category = rec.product.category.main;
      const brand = rec.product.brand;

      // Apply diversity penalty
      const categoryPenalty = (categoryCount.get(category) || 0) * diversityWeight;
      const brandPenalty = (brandCount.get(brand) || 0) * diversityWeight;

      rec.score.overall *= (1 - categoryPenalty - brandPenalty);

      // Apply novelty boost for less common items
      if (rec.category === 'discovery') {
        rec.score.overall *= (1 + noveltyWeight);
      }

      diversified.push(rec);

      categoryCount.set(category, (categoryCount.get(category) || 0) + 1);
      brandCount.set(brand, (brandCount.get(brand) || 0) + 1);
    }

    return diversified.sort((a, b) => b.score.overall - a.score.overall);
  }

  private generateExplanation(
    rec: RecommendationResult,
    preferences: IUserPreferences,
    context: RecommendationContext
  ) {
    const whyRecommended: string[] = [];
    const styleRules: string[] = [];

    // Generate explanation based on the recommendation source
    if (rec.score.breakdown.collaborative > 0.3) {
      whyRecommended.push('Users with similar taste also loved this');
    }

    if (rec.score.breakdown.contentBased > 0.3) {
      whyRecommended.push('Matches your style profile perfectly');
    }

    if (rec.score.breakdown.contextual > 0.3) {
      whyRecommended.push('Perfect for your current situation');
    }

    // Style rules
    if (preferences.shopping.style.preferences.includes('minimalist')) {
      styleRules.push('Clean, simple design aligns with minimalist aesthetic');
    }

    if (context.calendar?.formalityLevel === 'formal') {
      styleRules.push('Appropriate formality level for your scheduled events');
    }

    return {
      whyRecommended,
      styleRules,
      personalizationFactors: rec.reasoning.personalizationFactors,
      visualExplanation: `This ${rec.product.category.main} complements your style preferences`,
      abTestGroup: Math.random() > 0.5 ? 'A' : 'B'
    };
  }

  async learnFromFeedback(feedback: LearningFeedback): Promise<void> {
    const reward = this.calculateReward(feedback);

    // Update collaborative filtering
    await this.updateCollaborativeModel(feedback, reward);

    // Update content-based model
    await this.updateContentModel(feedback, reward);

    // Update reinforcement learning
    this.updateReinforcementLearning(feedback, reward);

    // Update bandits
    this.updateBandits(feedback, reward);

    this.emit('learned', feedback, reward);
  }

  private calculateReward(feedback: LearningFeedback): number {
    const baseRewards = {
      view: 0.1,
      like: 0.3,
      save: 0.5,
      share: 0.6,
      purchase: 1.0,
      dislike: -0.3,
      skip: -0.1
    };

    let reward = baseRewards[feedback.interactionType] || 0;

    // Bonus for explicit ratings
    if (feedback.explicitRating) {
      reward += (feedback.explicitRating - 3) * 0.2; // Scale 1-5 to -0.4 to 0.4
    }

    // Bonus for engagement metrics
    if (feedback.implicitSignals) {
      if (feedback.implicitSignals.viewDuration > 10) reward += 0.1;
      if (feedback.implicitSignals.scrollDepth > 0.8) reward += 0.05;
    }

    return Math.max(-1, Math.min(1, reward));
  }

  private async updateCollaborativeModel(feedback: LearningFeedback, reward: number): Promise<void> {
    // In a real implementation, this would update the model with new training data
    // For now, we'll update user embeddings
    const userId = feedback.userId;
    const embedding = this.userEmbeddings.get(userId) || new Float32Array(128);

    // Simple embedding update (in practice, this would be more sophisticated)
    for (let i = 0; i < embedding.length; i++) {
      embedding[i] += reward * 0.01 * Math.random();
    }

    this.userEmbeddings.set(userId, embedding);
  }

  private async updateContentModel(feedback: LearningFeedback, reward: number): Promise<void> {
    // Similar to collaborative model, update product embeddings
    const productId = feedback.productId;
    const embedding = this.productEmbeddings.get(productId) || new Float32Array(100);

    for (let i = 0; i < embedding.length; i++) {
      embedding[i] += reward * 0.01 * Math.random();
    }

    this.productEmbeddings.set(productId, embedding);
  }

  private updateReinforcementLearning(feedback: LearningFeedback, reward: number): void {
    const state = this.generateStateKey(feedback.context);
    const action = feedback.interactionType;
    const nextState = state; // Simplified - would normally be different

    this.reinforcementAgent.updateQValue(state, action, reward, nextState);
  }

  private updateBandits(feedback: LearningFeedback, reward: number): void {
    // Update multi-armed bandits
    const categoryBandit = this.multiArmedBandits.get('category_exploration');
    if (categoryBandit) {
      // This would need the actual category that was recommended
      const category = 'tops'; // Placeholder
      categoryBandit.updateReward(category, reward);
    }

    // Update contextual bandits
    const contextKey = this.generateContextKey(feedback.context);
    const bandit = this.contextualBandits.get(contextKey);
    if (bandit) {
      if (!bandit.rewards.has(feedback.productId)) {
        bandit.rewards.set(feedback.productId, []);
      }
      bandit.rewards.get(feedback.productId).push(reward);
    }
  }

  // Utility methods
  private getUserIndex(userId: string): number {
    // In a real implementation, maintain a mapping of user IDs to indices
    return Math.abs(this.hashString(userId)) % 10000;
  }

  private getProductIndex(productId: string): number {
    // Similar mapping for products
    return Math.abs(this.hashString(productId)) % 50000;
  }

  private hashString(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash;
  }

  private extractUserFeatures(preferences: IUserPreferences, userId: string): number[] {
    const features = new Array(50).fill(0);

    // Encode user preferences as features
    features[0] = preferences.shopping.priceRange.max / 1000; // Normalized price
    features[1] = preferences.shopping.favoriteCategories.length / 10;
    features[2] = preferences.shopping.favoriteBrands.length / 10;
    features[3] = preferences.shopping.sustainability.importance === 'high' ? 1 : 0;
    features[4] = preferences.metadata.profileCompleteness;

    // Add more feature engineering as needed
    return features;
  }

  private extractProductFeatures(product: IProduct, preferences: IUserPreferences): number[] {
    const features = new Array(100).fill(0);

    // Basic product features
    features[0] = product.price.current / 1000; // Normalized price
    features[1] = product.rating?.average || 0;
    features[2] = product.rating?.count || 0;
    features[3] = product.sustainability?.score || 0;

    // Category encoding (one-hot)
    const categories = ['tops', 'bottoms', 'dresses', 'shoes', 'accessories'];
    const categoryIndex = categories.indexOf(product.category.main.toLowerCase());
    if (categoryIndex >= 0) {
      features[10 + categoryIndex] = 1;
    }

    // Brand popularity (simplified)
    features[20] = Math.random(); // Placeholder for brand popularity score

    return features;
  }

  private extractContextFeatures(context: RecommendationContext): number[] {
    const features = new Array(30).fill(0);

    // Time features
    const timeMap = { morning: 0, afternoon: 1, evening: 2, night: 3 };
    features[0] = timeMap[context.timeOfDay] / 3;

    // Day of week (0-6)
    const dayIndex = new Date(context.timestamp).getDay();
    features[1] = dayIndex / 6;

    // Weather features
    if (context.weather) {
      features[2] = context.weather.temperature / 40; // Normalized temperature
      features[3] = context.weather.humidity / 100;
      features[4] = context.weather.condition.includes('rain') ? 1 : 0;
      features[5] = context.weather.condition.includes('sunny') ? 1 : 0;
    }

    // Location context
    if (context.location) {
      const locationMap = { home: 0, work: 1, travel: 2, social: 3 };
      features[10] = locationMap[context.location.context] / 3;
    }

    // Calendar context
    if (context.calendar) {
      features[15] = context.calendar.hasEvents ? 1 : 0;
      const formalityMap = { casual: 0, business: 1, formal: 2 };
      features[16] = formalityMap[context.calendar.formalityLevel] / 2;
    }

    return features;
  }

  private generateStateKey(context: RecommendationContext): string {
    return `${context.timeOfDay}_${context.dayOfWeek}_${context.location?.context || 'unknown'}`;
  }

  private generateContextKey(context: RecommendationContext): string {
    return `${context.timeOfDay}_${context.weather?.condition || 'unknown'}_${context.location?.context || 'unknown'}`;
  }

  async dispose(): Promise<void> {
    if (this.collaborativeModel) {
      this.collaborativeModel.dispose();
    }
    if (this.contentModel) {
      this.contentModel.dispose();
    }
    if (this.deepLearningModel) {
      this.deepLearningModel.dispose();
    }
    if (this.transformerModel) {
      this.transformerModel.dispose();
    }
  }
}