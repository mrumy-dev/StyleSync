import * as cheerio from 'cheerio';
import { logger } from '../middleware/ErrorHandler';
import { Product } from '../models/Product';

export interface ProductExtractionResult {
  product: Partial<Product>;
  confidence: number;
  extractedFields: string[];
  images: ExtractedImage[];
  reviews: ExtractedReview[];
  technicalSpecs: Record<string, string>;
  sizingInfo: SizingInfo;
  relatedProducts: RelatedProduct[];
}

export interface ExtractedImage {
  url: string;
  alt?: string;
  type: 'main' | 'thumbnail' | 'variant' | 'zoom' | 'lifestyle' | 'detail';
  dimensions?: { width: number; height: number };
  colorVariant?: string;
}

export interface ExtractedReview {
  id?: string;
  rating: number;
  title?: string;
  text: string;
  author?: string;
  date?: Date;
  verified?: boolean;
  helpful?: number;
  images?: string[];
}

export interface SizingInfo {
  availableSizes: string[];
  sizeChart?: {
    measurements: Record<string, Record<string, string>>;
    units: string;
  };
  fitRecommendations?: {
    runsSmall?: boolean;
    runsLarge?: boolean;
    trueToSize?: boolean;
    recommendedSize?: string;
  };
}

export interface RelatedProduct {
  id?: string;
  name: string;
  url: string;
  price?: number;
  image?: string;
  relationship: 'similar' | 'complement' | 'alternative' | 'bundle' | 'upsell';
}

export class AdvancedDataExtractor {
  private commonSelectors = {
    title: [
      'h1[data-automation-id="product-title"]',
      'h1.product-title',
      'h1.pdp-product-name',
      'h1[data-testid="product-name"]',
      '.product-name h1',
      '.product-detail-title',
      '[data-test="product-name"]',
      '.product-title',
      'h1'
    ],
    price: [
      '[data-automation-id="product-price"]',
      '.price-current',
      '.price-now',
      '.product-price-value',
      '[data-testid="price-current"]',
      '.price',
      '.current-price',
      '.sale-price'
    ],
    originalPrice: [
      '.price-was',
      '.price-original',
      '.price-before',
      '[data-testid="price-was"]',
      '.original-price',
      '.regular-price'
    ],
    description: [
      '[data-automation-id="product-description"]',
      '.product-description',
      '.product-details',
      '[data-testid="product-description"]',
      '.pdp-description',
      '.description'
    ],
    images: [
      '.product-images img',
      '.product-gallery img',
      '[data-testid="product-image"] img',
      '.pdp-images img',
      '.hero-image img',
      '.product-image img'
    ],
    brand: [
      '[data-automation-id="product-brand"]',
      '.product-brand',
      '.brand-name',
      '[data-testid="brand"]',
      '.designer-name'
    ],
    rating: [
      '[data-automation-id="product-rating"]',
      '.product-rating',
      '.rating-value',
      '[data-testid="rating"]',
      '.stars-rating'
    ],
    reviews: [
      '.review',
      '.product-review',
      '[data-testid="review"]',
      '.review-item',
      '.customer-review'
    ],
    sizes: [
      '.size-selector option',
      '.size-button',
      '[data-testid="size"]',
      '.size-option',
      '.variant-size'
    ],
    colors: [
      '.color-selector',
      '.color-option',
      '[data-testid="color"]',
      '.variant-color'
    ],
    category: [
      '.breadcrumb a',
      '.breadcrumbs a',
      '[data-testid="breadcrumb"] a',
      '.category-path a'
    ]
  };

  async extractProduct(html: string, url: string): Promise<ProductExtractionResult> {
    const $ = cheerio.load(html);
    const product: Partial<Product> = {};
    const extractedFields: string[] = [];
    let confidence = 0;

    // Extract basic product information
    const title = this.extractTitle($);
    if (title) {
      product.name = title;
      extractedFields.push('name');
      confidence += 20;
    }

    const pricing = this.extractPricing($);
    if (pricing.currentPrice) {
      product.currentPrice = pricing.currentPrice;
      extractedFields.push('currentPrice');
      confidence += 15;
    }
    if (pricing.originalPrice) {
      product.originalPrice = pricing.originalPrice;
      extractedFields.push('originalPrice');
      confidence += 10;
    }

    const description = this.extractDescription($);
    if (description) {
      product.description = description;
      extractedFields.push('description');
      confidence += 10;
    }

    const brand = this.extractBrand($);
    if (brand) {
      product.brand = brand;
      extractedFields.push('brand');
      confidence += 10;
    }

    const category = this.extractCategory($);
    if (category) {
      product.category = category;
      extractedFields.push('category');
      confidence += 5;
    }

    const rating = this.extractRating($);
    if (rating) {
      product.rating = rating;
      extractedFields.push('rating');
      confidence += 5;
    }

    // Extract images
    const images = this.extractImages($, url);
    if (images.length > 0) {
      product.images = images.map(img => img.url);
      extractedFields.push('images');
      confidence += 15;
    }

    // Extract reviews
    const reviews = this.extractReviews($);

    // Extract technical specifications
    const technicalSpecs = this.extractTechnicalSpecs($);

    // Extract sizing information
    const sizingInfo = this.extractSizingInfo($);

    // Extract related products
    const relatedProducts = this.extractRelatedProducts($, url);

    // Set final properties
    product.url = url;
    product.lastUpdated = new Date();
    product.availability = this.extractAvailability($);

    return {
      product,
      confidence: Math.min(confidence, 100),
      extractedFields,
      images,
      reviews,
      technicalSpecs,
      sizingInfo,
      relatedProducts
    };
  }

  private extractTitle($: cheerio.CheerioAPI): string | null {
    for (const selector of this.commonSelectors.title) {
      const element = $(selector).first();
      if (element.length && element.text().trim()) {
        return element.text().trim();
      }
    }

    // Fallback to structured data
    const jsonLd = this.extractJsonLd($);
    if (jsonLd?.name) return jsonLd.name;

    // Fallback to Open Graph
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle) return ogTitle;

    return null;
  }

  private extractPricing($: cheerio.CheerioAPI): {currentPrice?: number, originalPrice?: number} {
    const pricing: {currentPrice?: number, originalPrice?: number} = {};

    // Extract current price
    for (const selector of this.commonSelectors.price) {
      const priceText = $(selector).first().text().trim();
      if (priceText) {
        const price = this.parsePrice(priceText);
        if (price) {
          pricing.currentPrice = price;
          break;
        }
      }
    }

    // Extract original price
    for (const selector of this.commonSelectors.originalPrice) {
      const priceText = $(selector).first().text().trim();
      if (priceText) {
        const price = this.parsePrice(priceText);
        if (price) {
          pricing.originalPrice = price;
          break;
        }
      }
    }

    // Try structured data
    const jsonLd = this.extractJsonLd($);
    if (jsonLd?.offers?.price) {
      pricing.currentPrice = parseFloat(jsonLd.offers.price);
    }

    return pricing;
  }

  private parsePrice(priceText: string): number | null {
    // Remove common currency symbols and text
    const cleanPrice = priceText
      .replace(/[£$€¥₹]/g, '')
      .replace(/[,\s]/g, '')
      .replace(/from|starting at|was|now/gi, '')
      .trim();

    const match = cleanPrice.match(/(\d+\.?\d*)/);
    return match ? parseFloat(match[1]) : null;
  }

  private extractDescription($: cheerio.CheerioAPI): string | null {
    for (const selector of this.commonSelectors.description) {
      const element = $(selector).first();
      if (element.length) {
        // Get text content and clean it up
        const text = element.text().trim();
        if (text.length > 10) {
          return text;
        }
      }
    }

    // Try structured data
    const jsonLd = this.extractJsonLd($);
    if (jsonLd?.description) return jsonLd.description;

    return null;
  }

  private extractBrand($: cheerio.CheerioAPI): string | null {
    for (const selector of this.commonSelectors.brand) {
      const brandText = $(selector).first().text().trim();
      if (brandText) {
        return brandText;
      }
    }

    // Try structured data
    const jsonLd = this.extractJsonLd($);
    if (jsonLd?.brand?.name) return jsonLd.brand.name;

    return null;
  }

  private extractCategory($: cheerio.CheerioAPI): any {
    const categoryPath: string[] = [];

    for (const selector of this.commonSelectors.category) {
      $(selector).each((_, element) => {
        const text = $(element).text().trim();
        if (text && text.toLowerCase() !== 'home') {
          categoryPath.push(text);
        }
      });
    }

    if (categoryPath.length > 0) {
      return {
        main: categoryPath[categoryPath.length - 1],
        sub: categoryPath.length > 1 ? categoryPath[categoryPath.length - 2] : undefined,
        path: categoryPath
      };
    }

    return null;
  }

  private extractRating($: cheerio.CheerioAPI): {score?: number, count?: number} | null {
    for (const selector of this.commonSelectors.rating) {
      const ratingElement = $(selector).first();
      if (ratingElement.length) {
        // Try to extract numeric rating
        const ratingText = ratingElement.text();
        const ratingMatch = ratingText.match(/(\d+\.?\d*)/);

        if (ratingMatch) {
          const score = parseFloat(ratingMatch[1]);

          // Try to extract count
          const countMatch = ratingText.match(/(\d+)\s*(reviews?|ratings?)/i);
          const count = countMatch ? parseInt(countMatch[1]) : undefined;

          return { score, count };
        }

        // Try data attributes
        const dataRating = ratingElement.attr('data-rating');
        if (dataRating) {
          return { score: parseFloat(dataRating) };
        }

        // Count stars
        const stars = ratingElement.find('.star, .filled, .active').length;
        if (stars > 0) {
          return { score: stars };
        }
      }
    }

    return null;
  }

  private extractImages($: cheerio.CheerioAPI, baseUrl: string): ExtractedImage[] {
    const images: ExtractedImage[] = [];
    const seenUrls = new Set<string>();

    for (const selector of this.commonSelectors.images) {
      $(selector).each((_, element) => {
        const img = $(element);
        let src = img.attr('src') || img.attr('data-src') || img.attr('data-lazy');

        if (src) {
          // Make URL absolute
          if (src.startsWith('//')) {
            src = 'https:' + src;
          } else if (src.startsWith('/')) {
            const baseUrlObj = new URL(baseUrl);
            src = baseUrlObj.origin + src;
          }

          // Skip duplicates and small images
          if (!seenUrls.has(src) && !src.includes('placeholder') && !src.includes('loading')) {
            seenUrls.add(src);

            const alt = img.attr('alt') || '';
            let type: ExtractedImage['type'] = 'main';

            // Determine image type from context
            const parent = img.parent();
            const classes = (img.attr('class') || '') + ' ' + (parent.attr('class') || '');

            if (classes.includes('thumb')) type = 'thumbnail';
            else if (classes.includes('zoom')) type = 'zoom';
            else if (classes.includes('lifestyle')) type = 'lifestyle';
            else if (classes.includes('detail')) type = 'detail';
            else if (classes.includes('variant')) type = 'variant';

            images.push({
              url: src,
              alt,
              type
            });
          }
        }
      });
    }

    return images.slice(0, 20); // Limit to 20 images
  }

  private extractReviews($: cheerio.CheerioAPI): ExtractedReview[] {
    const reviews: ExtractedReview[] = [];

    for (const selector of this.commonSelectors.reviews) {
      $(selector).each((_, element) => {
        const reviewElement = $(element);

        const ratingElement = reviewElement.find('[data-rating], .rating, .stars');
        let rating = 0;

        if (ratingElement.length) {
          const ratingAttr = ratingElement.attr('data-rating');
          if (ratingAttr) {
            rating = parseFloat(ratingAttr);
          } else {
            // Count filled stars
            rating = ratingElement.find('.filled, .star-filled, .active').length;
          }
        }

        const title = reviewElement.find('.review-title, .title').first().text().trim();
        const text = reviewElement.find('.review-text, .review-body, .text').first().text().trim();
        const author = reviewElement.find('.review-author, .author, .name').first().text().trim();

        if (rating > 0 || text) {
          reviews.push({
            rating,
            title: title || undefined,
            text,
            author: author || undefined
          });
        }
      });
    }

    return reviews.slice(0, 50); // Limit to 50 reviews
  }

  private extractTechnicalSpecs($: cheerio.CheerioAPI): Record<string, string> {
    const specs: Record<string, string> = {};

    // Look for common spec table patterns
    const specSelectors = [
      '.product-specs',
      '.specifications',
      '.tech-specs',
      '.product-attributes',
      '.details-table'
    ];

    for (const selector of specSelectors) {
      $(selector).find('tr, .spec-row').each((_, element) => {
        const row = $(element);
        const label = row.find('td:first-child, .spec-label, .label').first().text().trim();
        const value = row.find('td:last-child, .spec-value, .value').first().text().trim();

        if (label && value) {
          specs[label] = value;
        }
      });
    }

    // Look for definition lists
    $('dl').each((_, element) => {
      const dl = $(element);
      const dts = dl.find('dt');
      const dds = dl.find('dd');

      dts.each((index, dt) => {
        const label = $(dt).text().trim();
        const value = $(dds[index]).text().trim();
        if (label && value) {
          specs[label] = value;
        }
      });
    });

    return specs;
  }

  private extractSizingInfo($: cheerio.CheerioAPI): SizingInfo {
    const sizingInfo: SizingInfo = {
      availableSizes: []
    };

    // Extract available sizes
    for (const selector of this.commonSelectors.sizes) {
      $(selector).each((_, element) => {
        const size = $(element).text().trim() || $(element).attr('value')?.trim();
        if (size && !sizingInfo.availableSizes.includes(size)) {
          sizingInfo.availableSizes.push(size);
        }
      });
    }

    // Look for size chart
    const sizeChart = $('.size-chart, .sizing-chart, .size-guide');
    if (sizeChart.length) {
      const measurements: Record<string, Record<string, string>> = {};

      sizeChart.find('table tr').each((_, row) => {
        const cells = $(row).find('td, th');
        if (cells.length > 1) {
          const size = $(cells[0]).text().trim();
          if (size && size !== 'Size') {
            measurements[size] = {};

            cells.slice(1).each((index, cell) => {
              const header = sizeChart.find('thead th, .header').eq(index + 1).text().trim();
              const value = $(cell).text().trim();
              if (header && value) {
                measurements[size][header] = value;
              }
            });
          }
        }
      });

      if (Object.keys(measurements).length > 0) {
        sizingInfo.sizeChart = {
          measurements,
          units: 'inches' // Default, could be extracted
        };
      }
    }

    return sizingInfo;
  }

  private extractRelatedProducts($: cheerio.CheerioAPI, baseUrl: string): RelatedProduct[] {
    const relatedProducts: RelatedProduct[] = [];

    // Look for related product sections
    const relatedSelectors = [
      '.related-products',
      '.similar-products',
      '.recommended-products',
      '.you-might-like',
      '.product-recommendations'
    ];

    for (const selector of relatedSelectors) {
      $(selector).find('a').each((_, element) => {
        const link = $(element);
        const href = link.attr('href');
        const name = link.find('.product-name, .title, h3, h4').text().trim() ||
                    link.attr('title') ||
                    link.text().trim();

        if (href && name) {
          let url = href;
          if (url.startsWith('/')) {
            const baseUrlObj = new URL(baseUrl);
            url = baseUrlObj.origin + url;
          }

          const image = link.find('img').attr('src');
          const priceText = link.find('.price').text().trim();
          const price = priceText ? this.parsePrice(priceText) : undefined;

          let relationship: RelatedProduct['relationship'] = 'similar';
          if (selector.includes('recommended')) relationship = 'upsell';
          else if (selector.includes('bundle')) relationship = 'bundle';

          relatedProducts.push({
            name,
            url,
            price: price || undefined,
            image,
            relationship
          });
        }
      });
    }

    return relatedProducts.slice(0, 20);
  }

  private extractAvailability($: cheerio.CheerioAPI): boolean {
    const availabilitySelectors = [
      '.availability',
      '.in-stock',
      '.out-of-stock',
      '[data-testid="availability"]'
    ];

    for (const selector of availabilitySelectors) {
      const element = $(selector).first();
      if (element.length) {
        const text = element.text().toLowerCase();
        return !text.includes('out of stock') && !text.includes('unavailable');
      }
    }

    // Check for disabled add to cart button
    const addToCartButton = $('button[data-testid="add-to-cart"], .add-to-cart, .add-to-bag');
    if (addToCartButton.length) {
      return !addToCartButton.is(':disabled') && !addToCartButton.hasClass('disabled');
    }

    return true; // Default to available
  }

  private extractJsonLd($: cheerio.CheerioAPI): any {
    try {
      const jsonLdScript = $('script[type="application/ld+json"]').first();
      if (jsonLdScript.length) {
        const jsonLd = JSON.parse(jsonLdScript.html() || '');

        // Handle arrays of structured data
        if (Array.isArray(jsonLd)) {
          return jsonLd.find(item => item['@type'] === 'Product') || jsonLd[0];
        }

        return jsonLd;
      }
    } catch (error) {
      logger.warn('Failed to parse JSON-LD:', error);
    }

    return null;
  }

  async extractFromMultiplePages(htmlPages: Array<{html: string, url: string}>): Promise<ProductExtractionResult[]> {
    const results: ProductExtractionResult[] = [];

    for (const page of htmlPages) {
      try {
        const result = await this.extractProduct(page.html, page.url);
        results.push(result);
      } catch (error) {
        logger.error(`Failed to extract from ${page.url}:`, error);
      }
    }

    return results;
  }
}