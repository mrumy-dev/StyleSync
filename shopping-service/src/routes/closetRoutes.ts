import { Router, Request, Response } from 'express';
import { ClosetDashboardController } from '../ui/ClosetDashboard';
import { ClosetOrganizationAI } from '../ai/ClosetOrganizationAI';
import { DigitalTwinEngine } from '../visualization/DigitalTwinEngine';
import { MaintenanceTracker } from '../maintenance/MaintenanceTracker';
import { InventoryManager } from '../inventory/InventoryManager';
import { SmartClosetFeatures } from '../smart/SmartClosetFeatures';
import { SmartHomeIntegration } from '../integrations/SmartHomeIntegration';

const router = Router();

// Middleware for user authentication
const authenticateUser = (req: Request, res: Response, next: any) => {
  const userId = req.headers['x-user-id'] as string;
  if (!userId) {
    return res.status(401).json({ error: 'User authentication required' });
  }
  req.userId = userId;
  next();
};

// Apply authentication to all routes
router.use(authenticateUser);

// Dashboard endpoints
router.get('/dashboard', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    const data = await controller.getDashboardData(req.userId);
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/dashboard/widgets', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    const data = await controller.getDashboardData(req.userId);
    res.json(data.widgets);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/dashboard/widgets/layout', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    await controller.updateWidgetLayout(req.userId, req.body.layout);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/dashboard/widgets', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    const widget = await controller.addWidget(req.userId, req.body);
    res.json(widget);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.delete('/dashboard/widgets/:widgetId', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    await controller.removeWidget(req.userId, req.params.widgetId);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Closet management endpoints
router.get('/', async (req: Request, res: Response) => {
  try {
    // Get user's closets
    res.json([]);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/', async (req: Request, res: Response) => {
  try {
    // Create new closet
    const closet = { id: `closet_${Date.now()}`, ...req.body };
    res.status(201).json(closet);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/:closetId', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    const data = await controller.getClosetView(req.userId, req.params.closetId);
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.put('/:closetId', async (req: Request, res: Response) => {
  try {
    // Update closet
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.delete('/:closetId', async (req: Request, res: Response) => {
  try {
    // Delete closet
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// AI Organization endpoints
router.post('/:closetId/organize', async (req: Request, res: Response) => {
  try {
    const organizationAI = req.app.get('organizationAI') as ClosetOrganizationAI;
    const { strategy, preferences } = req.body;

    // Mock implementation
    const plan = {
      strategy,
      sections: [],
      recommendations: ['Organize by frequency', 'Group similar colors'],
      efficiency: 0.85
    };

    res.json(plan);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/:closetId/analyze', async (req: Request, res: Response) => {
  try {
    const organizationAI = req.app.get('organizationAI') as ClosetOrganizationAI;
    // Mock analysis
    const analysis = {
      utilization: 0.78,
      efficiency: 0.82,
      gaps: ['business_shirts', 'winter_coats'],
      duplicates: [],
      recommendations: ['Consider adding versatile pieces', 'Remove unused items']
    };

    res.json(analysis);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Digital Twin endpoints
router.get('/:closetId/digital-twin', async (req: Request, res: Response) => {
  try {
    const digitalTwin = req.app.get('digitalTwinEngine') as DigitalTwinEngine;
    // Return digital twin data
    res.json({
      available: true,
      lastUpdated: new Date(),
      modelUrl: `/api/closets/${req.params.closetId}/3d-model`,
      vrUrl: `/api/closets/${req.params.closetId}/vr-tour`
    });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/:closetId/digital-twin/create', async (req: Request, res: Response) => {
  try {
    const digitalTwin = req.app.get('digitalTwinEngine') as DigitalTwinEngine;
    // Create digital twin
    const twin = {
      id: `twin_${req.params.closetId}`,
      status: 'creating',
      estimatedTime: 300
    };

    res.json(twin);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/:closetId/digital-twin/3d-model', async (req: Request, res: Response) => {
  try {
    // Return 3D model data
    res.setHeader('Content-Type', 'model/gltf+json');
    res.json({ mock: '3D model data' });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.get('/:closetId/digital-twin/vr-tour', async (req: Request, res: Response) => {
  try {
    const digitalTwin = req.app.get('digitalTwinEngine') as DigitalTwinEngine;
    // Return VR tour data
    res.json({
      id: `tour_${req.params.closetId}`,
      waypoints: [],
      navigation: 'http://localhost:3000/vr-viewer'
    });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Space optimization endpoints
router.post('/:closetId/optimize', async (req: Request, res: Response) => {
  try {
    const digitalTwin = req.app.get('digitalTwinEngine') as DigitalTwinEngine;
    const { constraints } = req.body;

    const optimization = {
      optimizedLayout: [],
      improvements: [
        {
          type: 'add',
          target: 'upper_shelf',
          description: 'Add upper shelf for seasonal storage',
          benefit: 'Increase storage capacity by 30%'
        }
      ],
      efficiency: 0.92
    };

    res.json(optimization);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Quick actions endpoints
router.post('/quick-actions/:actionId', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    const result = await controller.executeQuickAction(req.userId, req.params.actionId, req.body);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

// Notification endpoints
router.get('/notifications', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    const data = await controller.getDashboardData(req.userId);
    res.json(data.notifications);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.put('/notifications/:notificationId/read', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    await controller.markNotificationRead(req.userId, req.params.notificationId);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.delete('/notifications/:notificationId', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    await controller.dismissNotification(req.userId, req.params.notificationId);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

router.post('/notifications/:notificationId/actions/:actionId', async (req: Request, res: Response) => {
  try {
    const controller = req.app.get('dashboardController') as ClosetDashboardController;
    const result = await controller.executeNotificationAction(
      req.userId,
      req.params.notificationId,
      req.params.actionId
    );
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
  }
});

export default router;

// Extend Request interface for TypeScript
declare global {
  namespace Express {
    interface Request {
      userId: string;
    }
  }
}