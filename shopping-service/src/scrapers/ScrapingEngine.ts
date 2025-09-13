import { BaseScraper, ScrapingOptions } from './BaseScraper';
import { SHEINScraper } from './SHEINScraper';
import { ZaraScraper } from './ZaraScraper';
import { IProduct } from '../models/Product';

export interface ScrapingTask {
  id: string;
  store: string;
  type: 'search' | 'product' | 'categories';
  query?: string;
  url?: string;
  options?: ScrapingOptions;
  priority: number;
  createdAt: Date;
  status: 'pending' | 'running' | 'completed' | 'failed';
  result?: any;
  error?: string;
  retries: number;
}

export class ScrapingEngine {
  private scrapers: Map<string, BaseScraper> = new Map();
  private taskQueue: ScrapingTask[] = [];
  private runningTasks: Map<string, Promise<any>> = new Map();
  private maxConcurrentTasks = 5;
  private isRunning = false;

  constructor() {
    this.initializeScrapers();
  }

  private initializeScrapers() {
    this.scrapers.set('shein', new SHEINScraper());
    this.scrapers.set('zara', new ZaraScraper());
    // Add more scrapers as needed
  }

  async searchProducts(
    stores: string[],
    query: string,
    options: ScrapingOptions = {}
  ): Promise<{
    results: Map<string, Partial<IProduct>[]>;
    errors: Map<string, Error>;
  }> {
    const tasks = stores.map(store => ({
      id: this.generateTaskId(),
      store,
      type: 'search' as const,
      query,
      options,
      priority: 1,
      createdAt: new Date(),
      status: 'pending' as const,
      retries: 0
    }));

    // Add tasks to queue
    this.taskQueue.push(...tasks);

    // Start processing if not already running
    if (!this.isRunning) {
      this.startProcessing();
    }

    // Wait for all tasks to complete
    await this.waitForTasks(tasks.map(t => t.id));

    const results = new Map<string, Partial<IProduct>[]>();
    const errors = new Map<string, Error>();

    for (const task of tasks) {
      if (task.status === 'completed' && task.result) {
        results.set(task.store, task.result);
      } else if (task.status === 'failed' && task.error) {
        errors.set(task.store, new Error(task.error));
      }
    }

    return { results, errors };
  }

  async scrapeProduct(
    store: string,
    url: string,
    options: ScrapingOptions = {}
  ): Promise<IProduct | null> {
    const taskId = this.generateTaskId();
    const task: ScrapingTask = {
      id: taskId,
      store,
      type: 'product',
      url,
      options,
      priority: 2,
      createdAt: new Date(),
      status: 'pending',
      retries: 0
    };

    this.taskQueue.push(task);

    if (!this.isRunning) {
      this.startProcessing();
    }

    await this.waitForTasks([taskId]);

    return task.status === 'completed' ? task.result : null;
  }

  async getCategories(
    stores: string[],
    options: ScrapingOptions = {}
  ): Promise<Map<string, string[]>> {
    const tasks = stores.map(store => ({
      id: this.generateTaskId(),
      store,
      type: 'categories' as const,
      options,
      priority: 3,
      createdAt: new Date(),
      status: 'pending' as const,
      retries: 0
    }));

    this.taskQueue.push(...tasks);

    if (!this.isRunning) {
      this.startProcessing();
    }

    await this.waitForTasks(tasks.map(t => t.id));

    const results = new Map<string, string[]>();

    for (const task of tasks) {
      if (task.status === 'completed' && task.result) {
        results.set(task.store, task.result);
      }
    }

    return results;
  }

  private async startProcessing() {
    this.isRunning = true;

    while (this.taskQueue.length > 0 || this.runningTasks.size > 0) {
      // Start new tasks if we have capacity
      while (
        this.runningTasks.size < this.maxConcurrentTasks &&
        this.taskQueue.length > 0
      ) {
        const task = this.getNextTask();
        if (task) {
          this.executeTask(task);
        }
      }

      // Wait a bit before checking again
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    this.isRunning = false;
  }

  private getNextTask(): ScrapingTask | null {
    // Sort by priority (lower number = higher priority) and creation time
    this.taskQueue.sort((a, b) => {
      if (a.priority !== b.priority) {
        return a.priority - b.priority;
      }
      return a.createdAt.getTime() - b.createdAt.getTime();
    });

    const pendingTasks = this.taskQueue.filter(task => task.status === 'pending');
    if (pendingTasks.length === 0) return null;

    const task = pendingTasks[0];
    task.status = 'running';
    return task;
  }

  private async executeTask(task: ScrapingTask): Promise<void> {
    const scraper = this.scrapers.get(task.store);
    if (!scraper) {
      task.status = 'failed';
      task.error = `Scraper not found for store: ${task.store}`;
      return;
    }

    const taskPromise = this.performScraping(scraper, task);
    this.runningTasks.set(task.id, taskPromise);

    try {
      const result = await taskPromise;
      task.result = result;
      task.status = 'completed';
    } catch (error) {
      console.error(`Task ${task.id} failed:`, error);
      task.error = error instanceof Error ? error.message : String(error);
      
      // Retry logic
      if (task.retries < 3) {
        task.retries++;
        task.status = 'pending';
        console.log(`Retrying task ${task.id}, attempt ${task.retries}`);
      } else {
        task.status = 'failed';
      }
    } finally {
      this.runningTasks.delete(task.id);
    }
  }

  private async performScraping(scraper: BaseScraper, task: ScrapingTask): Promise<any> {
    switch (task.type) {
      case 'search':
        if (!task.query) throw new Error('Query required for search task');
        return scraper.searchProducts(task.query, task.options);
      
      case 'product':
        if (!task.url) throw new Error('URL required for product task');
        return scraper.scrapeProduct(task.url, task.options);
      
      case 'categories':
        return scraper.getCategories(task.options);
      
      default:
        throw new Error(`Unknown task type: ${task.type}`);
    }
  }

  private async waitForTasks(taskIds: string[]): Promise<void> {
    const checkInterval = 500; // 500ms
    const timeout = 60000; // 60 seconds
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      const allCompleted = taskIds.every(id => {
        const task = this.taskQueue.find(t => t.id === id);
        return task && (task.status === 'completed' || task.status === 'failed');
      });

      if (allCompleted) {
        return;
      }

      await new Promise(resolve => setTimeout(resolve, checkInterval));
    }

    throw new Error('Tasks timed out');
  }

  private generateTaskId(): string {
    return `task_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  getTaskStatus(taskId: string): ScrapingTask | null {
    return this.taskQueue.find(task => task.id === taskId) || null;
  }

  getQueueStatus(): {
    pending: number;
    running: number;
    completed: number;
    failed: number;
    total: number;
  } {
    const stats = {
      pending: 0,
      running: 0,
      completed: 0,
      failed: 0,
      total: this.taskQueue.length
    };

    for (const task of this.taskQueue) {
      stats[task.status]++;
    }

    return stats;
  }

  async shutdown(): Promise<void> {
    // Wait for running tasks to complete
    await Promise.allSettled(Array.from(this.runningTasks.values()));

    // Close all scrapers
    for (const scraper of this.scrapers.values()) {
      await scraper.close();
    }

    this.isRunning = false;
  }

  clearCompletedTasks(): void {
    this.taskQueue = this.taskQueue.filter(
      task => task.status !== 'completed' && task.status !== 'failed'
    );
  }

  setMaxConcurrentTasks(max: number): void {
    this.maxConcurrentTasks = Math.max(1, Math.min(max, 10));
  }
}