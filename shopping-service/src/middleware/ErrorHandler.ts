import { Request, Response, NextFunction } from 'express';
import { RateLimiterRedis } from 'rate-limiter-flexible';
import { createClient } from 'redis';
import winston from 'winston';

// Custom error types
export class AppError extends Error {
  statusCode: number;
  isOperational: boolean;
  code?: string;

  constructor(message: string, statusCode: number, isOperational = true, code?: string) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.code = code;

    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, code?: string) {
    super(message, 400, true, code);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'Resource not found') {
    super(message, 404, true, 'NOT_FOUND');
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized') {
    super(message, 401, true, 'UNAUTHORIZED');
  }
}

export class RateLimitError extends AppError {
  constructor(message: string = 'Too many requests') {
    super(message, 429, true, 'RATE_LIMIT_EXCEEDED');
  }
}

export class ServiceUnavailableError extends AppError {
  constructor(message: string = 'Service temporarily unavailable') {
    super(message, 503, true, 'SERVICE_UNAVAILABLE');
  }
}

// Logger configuration
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'shopping-service' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
  ],
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple()
  }));
}

// Rate limiter configurations
export class RateLimitManager {
  private redisClient;
  private rateLimiters: Map<string, RateLimiterRedis> = new Map();

  constructor() {
    this.redisClient = createClient({
      url: process.env.REDIS_URL || 'redis://localhost:6379'
    });
    this.setupRateLimiters();
  }

  private setupRateLimiters() {
    // General API rate limiter
    this.rateLimiters.set('api', new RateLimiterRedis({
      storeClient: this.redisClient,
      keyPrefix: 'rl:api',
      points: 100, // Number of requests
      duration: 60, // Per 60 seconds
      blockDuration: 60, // Block for 60 seconds if exceeded
    }));

    // Search endpoint rate limiter
    this.rateLimiters.set('search', new RateLimiterRedis({
      storeClient: this.redisClient,
      keyPrefix: 'rl:search',
      points: 30,
      duration: 60,
      blockDuration: 120,
    }));

    // Scraping rate limiter
    this.rateLimiters.set('scraping', new RateLimiterRedis({
      storeClient: this.redisClient,
      keyPrefix: 'rl:scraping',
      points: 10,
      duration: 60,
      blockDuration: 300,
    }));

    // Visual search rate limiter (more expensive operations)
    this.rateLimiters.set('visual', new RateLimiterRedis({
      storeClient: this.redisClient,
      keyPrefix: 'rl:visual',
      points: 5,
      duration: 60,
      blockDuration: 300,
    }));

    // Price tracking alerts
    this.rateLimiters.set('alerts', new RateLimiterRedis({
      storeClient: this.redisClient,
      keyPrefix: 'rl:alerts',
      points: 20,
      duration: 3600, // Per hour
      blockDuration: 3600,
    }));
  }

  getRateLimiter(type: string): RateLimiterRedis | undefined {
    return this.rateLimiters.get(type);
  }
}

// Rate limiting middleware
export function createRateLimitMiddleware(limiterType: string = 'api') {
  const rateLimitManager = new RateLimitManager();
  
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const rateLimiter = rateLimitManager.getRateLimiter(limiterType);
      if (!rateLimiter) {
        return next();
      }

      const key = req.ip || req.connection.remoteAddress || 'unknown';
      const resRateLimiter = await rateLimiter.consume(key);

      res.set({
        'Retry-After': Math.round(resRateLimiter.msBeforeNext / 1000) || 1,
        'X-RateLimit-Limit': rateLimiter.points,
        'X-RateLimit-Remaining': resRateLimiter.remainingPoints || 0,
        'X-RateLimit-Reset': new Date(Date.now() + resRateLimiter.msBeforeNext),
      });

      next();
    } catch (rejRes) {
      const secs = Math.round(rejRes.msBeforeNext / 1000) || 1;
      res.set('Retry-After', String(secs));
      
      logger.warn('Rate limit exceeded', {
        ip: req.ip,
        endpoint: req.path,
        method: req.method,
        limiterType,
        retryAfter: secs
      });

      next(new RateLimitError(`Rate limit exceeded. Try again in ${secs} seconds.`));
    }
  };
}

// Input validation middleware
export function validateRequest(schema: any) {
  return (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = schema.validate({
      body: req.body,
      query: req.query,
      params: req.params
    }, { abortEarly: false, allowUnknown: false });

    if (error) {
      const validationErrors = error.details.map((detail: any) => ({
        field: detail.path.join('.'),
        message: detail.message,
        value: detail.context?.value
      }));

      logger.warn('Validation error', {
        ip: req.ip,
        endpoint: req.path,
        method: req.method,
        errors: validationErrors
      });

      return next(new ValidationError('Validation failed', 'VALIDATION_ERROR'));
    }

    // Replace request data with validated data
    req.body = value.body || req.body;
    req.query = value.query || req.query;
    req.params = value.params || req.params;

    next();
  };
}

// Security middleware
export function securityHeaders(req: Request, res: Response, next: NextFunction) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Content-Security-Policy', "default-src 'self'");
  res.removeHeader('X-Powered-By');
  
  next();
}

// Request timeout middleware
export function requestTimeout(timeoutMs: number = 30000) {
  return (req: Request, res: Response, next: NextFunction) => {
    const timeout = setTimeout(() => {
      if (!res.headersSent) {
        logger.error('Request timeout', {
          ip: req.ip,
          endpoint: req.path,
          method: req.method,
          timeout: timeoutMs
        });

        next(new ServiceUnavailableError('Request timeout'));
      }
    }, timeoutMs);

    res.on('finish', () => clearTimeout(timeout));
    res.on('close', () => clearTimeout(timeout));

    next();
  };
}

// Request logging middleware
export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logLevel = res.statusCode >= 400 ? 'error' : 'info';
    
    logger.log(logLevel, 'HTTP Request', {
      method: req.method,
      url: req.originalUrl,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      contentLength: res.get('Content-Length')
    });
  });

  next();
}

// Error handling middleware
export function errorHandler(error: Error, req: Request, res: Response, next: NextFunction) {
  let err = error;

  // Log error
  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error('Application error', {
        error: err.message,
        stack: err.stack,
        statusCode: err.statusCode,
        code: err.code,
        ip: req.ip,
        endpoint: req.path,
        method: req.method
      });
    } else {
      logger.warn('Client error', {
        error: err.message,
        statusCode: err.statusCode,
        code: err.code,
        ip: req.ip,
        endpoint: req.path,
        method: req.method
      });
    }
  } else {
    // Handle unexpected errors
    logger.error('Unexpected error', {
      error: err.message,
      stack: err.stack,
      ip: req.ip,
      endpoint: req.path,
      method: req.method
    });

    err = new AppError('Internal server error', 500, false);
  }

  // Don't leak error details in production
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  const errorResponse: any = {
    status: 'error',
    code: (err as AppError).code || 'INTERNAL_ERROR',
    message: err.message
  };

  if (isDevelopment) {
    errorResponse.stack = err.stack;
  }

  res.status((err as AppError).statusCode || 500).json(errorResponse);
}

// Async error wrapper
export function asyncHandler(fn: Function) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// Health check middleware
export function healthCheck(req: Request, res: Response, next: NextFunction) {
  if (req.path === '/health' || req.path === '/health/') {
    return res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: process.env.APP_VERSION || '1.0.0'
    });
  }
  next();
}

// Service availability checker
export class ServiceMonitor {
  private services: Map<string, { url?: string; healthy: boolean; lastCheck: Date }> = new Map();

  constructor() {
    this.initializeServices();
    this.startHealthChecks();
  }

  private initializeServices() {
    const services = [
      { name: 'redis', url: process.env.REDIS_URL },
      { name: 'mongodb', url: process.env.MONGODB_URL },
      { name: 'zalando-api', url: 'https://api.zalando.com' },
      { name: 'asos-api', url: 'https://api.asos.com' }
    ];

    services.forEach(service => {
      this.services.set(service.name, {
        url: service.url,
        healthy: true,
        lastCheck: new Date()
      });
    });
  }

  private startHealthChecks() {
    setInterval(() => {
      this.checkServices();
    }, 30000); // Check every 30 seconds
  }

  private async checkServices() {
    for (const [name, service] of this.services) {
      try {
        if (service.url) {
          // Perform basic connectivity check
          const response = await fetch(service.url, { 
            method: 'HEAD', 
            timeout: 5000 
          });
          service.healthy = response.ok;
        }
        service.lastCheck = new Date();
      } catch (error) {
        service.healthy = false;
        service.lastCheck = new Date();
        logger.warn(`Service ${name} health check failed`, { error: error.message });
      }
    }
  }

  getServiceHealth(): Record<string, any> {
    const health: Record<string, any> = {};
    
    for (const [name, service] of this.services) {
      health[name] = {
        healthy: service.healthy,
        lastCheck: service.lastCheck.toISOString()
      };
    }

    return health;
  }

  isServiceHealthy(serviceName: string): boolean {
    return this.services.get(serviceName)?.healthy ?? false;
  }
}

// Export singleton instances
export const rateLimitManager = new RateLimitManager();
export const serviceMonitor = new ServiceMonitor();
export { logger };

// Default middleware stack
export function setupMiddleware(app: any) {
  app.use(requestLogger);
  app.use(securityHeaders);
  app.use(healthCheck);
  app.use(requestTimeout(30000));
  app.use(createRateLimitMiddleware('api'));
}

// Global error handlers
process.on('unhandledRejection', (reason: Error, promise: Promise<any>) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Application specific logging, throwing an error, or other logic here
});

process.on('uncaughtException', (error: Error) => {
  logger.error('Uncaught Exception:', error);
  // Application specific logging, throwing an error, or other logic here
  process.exit(1);
});