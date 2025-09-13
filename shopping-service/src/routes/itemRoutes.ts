import { Router, Request, Response } from 'express';
import { ItemManagementController } from '../ui/ItemManagement';
import { InventoryManager } from '../inventory/InventoryManager';
import { MaintenanceTracker } from '../maintenance/MaintenanceTracker';
import multer from 'multer';

const router = Router();
const upload = multer({
  dest: 'uploads/',
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// Middleware for user authentication
const authenticateUser = (req: Request, res: Response, next: any) => {
  const userId = req.headers['x-user-id'] as string;
  if (!userId) {
    return res.status(401).json({ error: 'User authentication required' });
  }
  req.userId = userId;
  next();
};

router.use(authenticateUser);

// Item list and search endpoints
router.get('/', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;
    const options = {
      filters: req.query.filters ? JSON.parse(req.query.filters as string) : undefined,
      sorting: req.query.sort ? JSON.parse(req.query.sort as string) : undefined,
      grouping: req.query.group ? JSON.parse(req.query.group as string) : undefined,
      pagination: {
        page: parseInt(req.query.page as string) || 1,
        limit: parseInt(req.query.limit as string) || 20
      },
      search: req.query.search as string
    };

    const data = await controller.getItemList(req.userId, options);
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Item details endpoints
router.get('/:itemId', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;
    const data = await controller.getItemDetails(req.params.itemId);
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Item creation endpoint
router.post('/', upload.array('images', 10), async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;

    // Process uploaded images
    const images = req.files as Express.Multer.File[];
    const imageUrls = images?.map(file => `/uploads/${file.filename}`) || [];

    const formData = {
      ...req.body,
      images: {
        main: imageUrls[0] || '',
        gallery: imageUrls,
        details: []
      }
    };

    const result = await controller.createItem(req.userId, formData);

    if (result.success) {
      res.status(201).json({ itemId: result.itemId });
    } else {
      res.status(400).json({ errors: result.errors });
    }
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Item update endpoint
router.put('/:itemId', upload.array('images', 10), async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;

    const images = req.files as Express.Multer.File[];
    let updates = { ...req.body };

    if (images && images.length > 0) {
      const imageUrls = images.map(file => `/uploads/${file.filename}`);
      updates.images = {
        ...updates.images,
        gallery: [...(updates.images?.gallery || []), ...imageUrls]
      };
    }

    const result = await controller.updateItem(req.params.itemId, updates);

    if (result.success) {
      res.json({ success: true });
    } else {
      res.status(400).json({ errors: result.errors });
    }
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Item deletion endpoint
router.delete('/:itemId', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;
    const options = {
      deleteImages: req.query.deleteImages === 'true',
      removeFromOutfits: req.query.removeFromOutfits === 'true',
      cancelMaintenance: req.query.cancelMaintenance === 'true'
    };

    const result = await controller.deleteItem(req.params.itemId, options);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Item duplication endpoint
router.post('/:itemId/duplicate', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;
    const result = await controller.duplicateItem(req.params.itemId, req.body.modifications);

    if (result.success) {
      res.status(201).json({ itemId: result.newItemId });
    } else {
      res.status(400).json({ errors: result.errors });
    }
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Item move endpoint
router.post('/:itemId/move', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;
    const result = await controller.moveItem(req.params.itemId, req.body.location);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Bulk operations endpoints
router.get('/bulk/actions', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;
    const itemIds = (req.query.items as string)?.split(',') || [];
    const actions = await controller.getAvailableBulkActions(itemIds);
    res.json(actions);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/bulk/:action', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;
    const { itemIds, parameters } = req.body;
    const result = await controller.bulkUpdate(itemIds, req.params.action, parameters);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Export endpoints
router.post('/export', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('itemController') as ItemManagementController;
    const { itemIds, format, options } = req.body;

    const result = await controller.exportItems(itemIds, format, options);

    res.setHeader('Content-Type', result.contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${result.filename}"`);

    if (typeof result.data === 'string') {
      res.send(result.data);
    } else {
      res.send(Buffer.from(result.data));
    }
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Inventory management endpoints
router.post('/:itemId/barcode/scan', async (req: Request, res: Response) => {
  try {
    const inventoryManager = req.app.get('inventoryManager') as InventoryManager;
    const result = await inventoryManager.scanBarcode(req.body.code);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/:itemId/rfid/read', async (req: Request, res: Response) => {
  try {
    const inventoryManager = req.app.get('inventoryManager') as InventoryManager;
    const result = await inventoryManager.readRFIDTag(req.body.tagId);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/quick-add', async (req: Request, res: Response) => {
  try {
    const inventoryManager = req.app.get('inventoryManager') as InventoryManager;
    const { closetId, mode } = req.body;
    const result = await inventoryManager.quickAddMode(req.userId, closetId, mode);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/bulk-import', upload.single('file'), async (req: Request, res: Response) => {
  try {
    const inventoryManager = req.app.get('inventoryManager') as InventoryManager;

    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    // Parse uploaded file based on format
    const format = req.body.format || 'csv';
    const data = []; // Parse file content here

    const result = await inventoryManager.bulkImport(req.userId, data, format);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Valuation and analytics endpoints
router.get('/analytics/valuation', async (req: Request, res: Response) => {
  try {
    const inventoryManager = req.app.get('inventoryManager') as InventoryManager;
    const result = await inventoryManager.trackValuation(req.userId);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/analytics/missing', async (req: Request, res: Response) => {
  try {
    const inventoryManager = req.app.get('inventoryManager') as InventoryManager;
    const result = await inventoryManager.detectMissingItems(req.userId);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/analytics/duplicates', async (req: Request, res: Response) => {
  try {
    const inventoryManager = req.app.get('inventoryManager') as InventoryManager;
    const result = await inventoryManager.createDuplicateDetection(req.userId);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Insurance documentation
router.post('/insurance/generate', async (req: Request, res: Response) => {
  try {
    const inventoryManager = req.app.get('inventoryManager') as InventoryManager;
    const result = await inventoryManager.generateInsuranceDocumentation(req.userId, req.body.coverage);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Maintenance endpoints
router.get('/:itemId/maintenance', async (req: Request, res: Response) => {
  try {
    const maintenanceTracker = req.app.get('maintenanceTracker') as MaintenanceTracker;
    const result = await maintenanceTracker.trackRepairs(req.userId, req.params.itemId);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/:itemId/maintenance/schedule', async (req: Request, res: Response) => {
  try {
    const maintenanceTracker = req.app.get('maintenanceTracker') as MaintenanceTracker;
    const { type, dueDate, options } = req.body;

    const result = await maintenanceTracker.scheduleMaintenanceTask(
      req.userId,
      req.params.itemId,
      type,
      new Date(dueDate),
      options
    );

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/:itemId/maintenance/issue', async (req: Request, res: Response) => {
  try {
    const maintenanceTracker = req.app.get('maintenanceTracker') as MaintenanceTracker;
    await maintenanceTracker.reportIssue(req.userId, req.params.itemId, req.body);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Item suggestions and recommendations
router.get('/:itemId/suggestions/outfits', async (req: Request, res: Response) => {
  try {
    // Get outfit suggestions for this item
    res.json({
      outfits: [
        { id: 'outfit1', name: 'Business Casual', confidence: 0.9 },
        { id: 'outfit2', name: 'Weekend Look', confidence: 0.8 }
      ]
    });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/:itemId/suggestions/alternatives', async (req: Request, res: Response) => {
  try {
    // Get alternative item suggestions
    res.json({
      alternatives: [
        { id: 'item1', name: 'Similar Black Blazer', similarity: 0.95 },
        { id: 'item2', name: 'Navy Alternative', similarity: 0.87 }
      ]
    });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/:itemId/suggestions/styling', async (req: Request, res: Response) => {
  try {
    // Get styling suggestions
    res.json({
      tips: [
        'Pairs well with light colors',
        'Try with statement jewelry',
        'Great for layering'
      ],
      occasions: ['business', 'smart_casual', 'date_night'],
      seasons: ['autumn', 'winter', 'spring']
    });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Image management endpoints
router.post('/:itemId/images', upload.array('images', 5), async (req: Request, res: Response) => {
  try {
    const images = req.files as Express.Multer.File[];
    const imageUrls = images?.map(file => `/uploads/${file.filename}`) || [];

    // Update item with new images
    res.json({ imageUrls });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.delete('/:itemId/images/:imageId', async (req: Request, res: Response) => {
  try {
    // Delete specific image
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

export default router;