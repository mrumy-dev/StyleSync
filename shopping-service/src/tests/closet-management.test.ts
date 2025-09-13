import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { ClosetOrganizationAI } from '../ai/ClosetOrganizationAI';
import { DigitalTwinEngine } from '../visualization/DigitalTwinEngine';
import { MaintenanceTracker } from '../maintenance/MaintenanceTracker';
import { InventoryManager } from '../inventory/InventoryManager';
import { SmartClosetFeatures } from '../smart/SmartClosetFeatures';
import { SmartHomeIntegration } from '../integrations/SmartHomeIntegration';
import { ClosetDashboardController } from '../ui/ClosetDashboard';
import { ItemManagementController } from '../ui/ItemManagement';
import { IClothingItem } from '../models/ClothingItem';
import { ICloset } from '../models/Closet';

// Mock services
jest.mock('../realtime/NotificationService');

describe('Closet Management System', () => {
  let organizationAI: ClosetOrganizationAI;
  let digitalTwinEngine: DigitalTwinEngine;
  let maintenanceTracker: MaintenanceTracker;
  let inventoryManager: InventoryManager;
  let smartFeatures: SmartClosetFeatures;
  let smartHomeIntegration: SmartHomeIntegration;
  let dashboardController: ClosetDashboardController;
  let itemController: ItemManagementController;

  const mockItem: IClothingItem = {
    id: 'item_test_123',
    name: 'Test T-Shirt',
    brand: 'Test Brand',
    category: {
      main: 'tops',
      sub: 'tshirt',
      type: 'casual_tee',
      season: ['spring', 'summer'],
      occasion: ['casual'],
      formality: 'casual'
    },
    colors: {
      primary: 'blue',
      secondary: [],
      colorCodes: { blue: '#0066CC' },
      colorFamily: 'blue'
    },
    materials: {
      primary: 'cotton',
      composition: { cotton: 100 },
      careInstructions: ['machine_wash'],
      sustainability: {
        recyclable: true
      }
    },
    size: {
      label: 'M',
      fit: 'regular'
    },
    condition: {
      status: 'excellent'
    },
    purchase: {
      date: new Date('2023-01-01'),
      price: 25,
      currency: 'USD'
    },
    valuation: {
      current: 20,
      original: 25
    },
    images: {
      main: '/images/test-tshirt.jpg',
      gallery: []
    },
    tags: ['basic', 'everyday'],
    metadata: {
      addedAt: new Date('2023-01-01'),
      wearCount: 5,
      lastUpdated: new Date(),
      source: 'manual'
    }
  };

  const mockCloset: ICloset = {
    id: 'closet_test_123',
    userId: 'user_test_456',
    name: 'Main Closet',
    spaces: [],
    items: ['item_test_123'],
    organization: {
      strategy: 'frequency_based',
      autoOrganize: true,
      lastOrganized: new Date(),
      rules: []
    },
    digitalTwin: {
      enabled: false
    },
    analytics: {
      totalItems: 1,
      categories: { tops: 1 },
      brands: { 'Test Brand': 1 },
      colors: { blue: 1 },
      utilizationRate: 0.8,
      averageWearFrequency: 5,
      lastAnalyzed: new Date()
    },
    preferences: {
      seasonalRotation: true,
      capsuleWardrobe: false,
      sustainabilityFocus: true,
      budgetTracking: true,
      notifications: {
        maintenance: true,
        organization: true,
        seasonal: true,
        purchases: true
      }
    },
    metadata: {
      createdAt: new Date('2023-01-01'),
      lastUpdated: new Date(),
      version: 1,
      isActive: true
    }
  };

  beforeEach(() => {
    // Initialize services with mocked dependencies
    const mockNotificationService = {
      sendNotification: jest.fn(),
      addWebSocketConnection: jest.fn(),
      getNotificationHistory: jest.fn(),
      markAsRead: jest.fn(),
      getUnreadCount: jest.fn(),
      shutdown: jest.fn()
    };

    organizationAI = new ClosetOrganizationAI();
    digitalTwinEngine = new DigitalTwinEngine();
    maintenanceTracker = new MaintenanceTracker(mockNotificationService as any);
    inventoryManager = new InventoryManager();
    smartFeatures = new SmartClosetFeatures();
    smartHomeIntegration = new SmartHomeIntegration();

    dashboardController = new ClosetDashboardController(
      inventoryManager,
      maintenanceTracker,
      organizationAI
    );

    itemController = new ItemManagementController(
      inventoryManager,
      maintenanceTracker
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Closet Organization AI', () => {
    it('should analyze closet utilization and efficiency', async () => {
      const result = await organizationAI.analyzeCloset(mockCloset, [mockItem]);

      expect(result).toHaveProperty('utilization');
      expect(result).toHaveProperty('efficiency');
      expect(result).toHaveProperty('gaps');
      expect(result).toHaveProperty('duplicates');
      expect(result).toHaveProperty('recommendations');

      expect(typeof result.utilization).toBe('number');
      expect(typeof result.efficiency).toBe('number');
      expect(Array.isArray(result.gaps)).toBe(true);
      expect(Array.isArray(result.duplicates)).toBe(true);
      expect(Array.isArray(result.recommendations)).toBe(true);
    });

    it('should organize closet by frequency', async () => {
      const plan = await organizationAI.organizeByFrequency([mockItem], mockCloset);

      expect(plan).toHaveProperty('strategy', 'frequency_based');
      expect(plan).toHaveProperty('sections');
      expect(plan).toHaveProperty('recommendations');
      expect(plan).toHaveProperty('efficiency');

      expect(Array.isArray(plan.sections)).toBe(true);
      expect(Array.isArray(plan.recommendations)).toBe(true);
      expect(typeof plan.efficiency).toBe('number');
    });

    it('should organize closet by color coordination', async () => {
      const result = await organizationAI.organizeByColor([mockItem], mockCloset);

      expect(result).toHaveProperty('groups');
      expect(result).toHaveProperty('transitions');

      expect(Array.isArray(result.groups)).toBe(true);
      expect(Array.isArray(result.transitions)).toBe(true);

      if (result.groups.length > 0) {
        expect(result.groups[0]).toHaveProperty('colorFamily');
        expect(result.groups[0]).toHaveProperty('items');
        expect(result.groups[0]).toHaveProperty('harmony');
        expect(result.groups[0]).toHaveProperty('position');
      }
    });

    it('should create seasonal rotation plan', async () => {
      const plan = await organizationAI.createSeasonalRotation([mockItem], 'US');

      expect(plan).toHaveProperty('currentSeason');
      expect(plan).toHaveProperty('activeItems');
      expect(plan).toHaveProperty('storageItems');
      expect(plan).toHaveProperty('transitionItems');
      expect(plan).toHaveProperty('rotationDate');
      expect(plan).toHaveProperty('climate');

      expect(Array.isArray(plan.activeItems)).toBe(true);
      expect(Array.isArray(plan.storageItems)).toBe(true);
      expect(Array.isArray(plan.transitionItems)).toBe(true);
      expect(plan.rotationDate instanceof Date).toBe(true);
    });

    it('should create capsule wardrobe', async () => {
      const preferences = { maxPieces: 30, seasons: ['spring', 'summer'] };
      const result = await organizationAI.createCapsuleWardrobe([mockItem], preferences);

      expect(result).toHaveProperty('capsule');
      expect(result).toHaveProperty('essentials');
      expect(result).toHaveProperty('seasonal');
      expect(result).toHaveProperty('versatilityScores');
      expect(result).toHaveProperty('combinations');

      expect(Array.isArray(result.capsule)).toBe(true);
      expect(Array.isArray(result.essentials)).toBe(true);
      expect(Array.isArray(result.seasonal)).toBe(true);
      expect(typeof result.versatilityScores).toBe('object');
      expect(typeof result.combinations).toBe('number');
    });
  });

  describe('Digital Twin Engine', () => {
    it('should create digital twin for closet', async () => {
      const twin = await digitalTwinEngine.createDigitalTwin(mockCloset, [mockItem]);

      expect(twin).toHaveProperty('id');
      expect(twin).toHaveProperty('closetId', mockCloset.id);
      expect(twin).toHaveProperty('model');
      expect(twin).toHaveProperty('spaces');
      expect(twin).toHaveProperty('items');
      expect(twin).toHaveProperty('lighting');
      expect(twin).toHaveProperty('camera');
      expect(twin).toHaveProperty('metadata');

      expect(Array.isArray(twin.spaces)).toBe(true);
      expect(Array.isArray(twin.items)).toBe(true);
      expect(twin.metadata.createdAt instanceof Date).toBe(true);
    });

    it('should generate virtual tour', async () => {
      const twin = await digitalTwinEngine.createDigitalTwin(mockCloset, [mockItem]);
      const tour = await digitalTwinEngine.generateVirtualTour(twin);

      expect(tour).toHaveProperty('id');
      expect(tour).toHaveProperty('name');
      expect(tour).toHaveProperty('waypoints');
      expect(tour).toHaveProperty('transitions');

      expect(Array.isArray(tour.waypoints)).toBe(true);
      expect(Array.isArray(tour.transitions)).toBe(true);

      if (tour.waypoints.length > 0) {
        expect(tour.waypoints[0]).toHaveProperty('position');
        expect(tour.waypoints[0]).toHaveProperty('rotation');
        expect(tour.waypoints[0]).toHaveProperty('fov');
        expect(tour.waypoints[0]).toHaveProperty('description');
        expect(tour.waypoints[0]).toHaveProperty('hotspots');
      }
    });

    it('should create AR overlay', async () => {
      const twin = await digitalTwinEngine.createDigitalTwin(mockCloset, [mockItem]);
      const arOverlay = await digitalTwinEngine.createAROverlay(twin);

      expect(arOverlay).toHaveProperty('id');
      expect(arOverlay).toHaveProperty('markers');
      expect(arOverlay).toHaveProperty('objects');
      expect(arOverlay).toHaveProperty('tracking');
      expect(arOverlay).toHaveProperty('occlusion');
      expect(arOverlay).toHaveProperty('lighting');

      expect(Array.isArray(arOverlay.markers)).toBe(true);
      expect(Array.isArray(arOverlay.objects)).toBe(true);
      expect(typeof arOverlay.tracking).toBe('object');
    });

    it('should export 3D model in different formats', async () => {
      const twin = await digitalTwinEngine.createDigitalTwin(mockCloset, [mockItem]);

      const formats = ['gltf', 'fbx', 'obj', 'usdz'] as const;
      for (const format of formats) {
        const result = await digitalTwinEngine.exportModel(twin, format);

        expect(result).toHaveProperty('data');
        expect(result).toHaveProperty('metadata');
        expect(result).toHaveProperty('preview');

        expect(result.data instanceof ArrayBuffer).toBe(true);
        expect(typeof result.metadata).toBe('object');
        expect(typeof result.preview).toBe('string');
      }
    });
  });

  describe('Maintenance Tracker', () => {
    it('should schedule maintenance task', async () => {
      const dueDate = new Date(Date.now() + 7 * 86400000); // 7 days from now
      const record = await maintenanceTracker.scheduleMaintenanceTask(
        'user_test_456',
        'item_test_123',
        'cleaning',
        dueDate,
        { priority: 'medium', estimatedCost: 15 }
      );

      expect(record).toHaveProperty('id');
      expect(record).toHaveProperty('userId', 'user_test_456');
      expect(record).toHaveProperty('itemId', 'item_test_123');
      expect(record).toHaveProperty('type', 'cleaning');
      expect(record).toHaveProperty('status', 'scheduled');
      expect(record).toHaveProperty('priority', 'medium');
      expect(record.scheduling.dueDate).toEqual(dueDate);
    });

    it('should create cleaning schedule for items', async () => {
      const schedules = await maintenanceTracker.createCleaningSchedule('user_test_456', [mockItem]);

      expect(Array.isArray(schedules)).toBe(true);
      expect(schedules.length).toBe(1);

      const schedule = schedules[0];
      expect(schedule).toHaveProperty('itemId', mockItem.id);
      expect(schedule).toHaveProperty('frequency');
      expect(schedule).toHaveProperty('nextDue');
      expect(schedule).toHaveProperty('cleaningType');
      expect(schedule).toHaveProperty('estimatedCost');

      expect(typeof schedule.frequency).toBe('number');
      expect(schedule.nextDue instanceof Date).toBe(true);
      expect(typeof schedule.estimatedCost).toBe('number');
    });

    it('should track repair issues', async () => {
      const tracker = await maintenanceTracker.trackRepairs('user_test_456', 'item_test_123');

      expect(tracker).toHaveProperty('itemId', 'item_test_123');
      expect(tracker).toHaveProperty('issues');
      expect(tracker).toHaveProperty('history');

      expect(Array.isArray(tracker.issues)).toBe(true);
      expect(Array.isArray(tracker.history)).toBe(true);
    });

    it('should implement moth prevention plan', async () => {
      const prevention = await maintenanceTracker.implementMothPrevention(
        'user_test_456',
        [mockItem],
        'closet_test_123'
      );

      expect(prevention).toHaveProperty('riskLevel');
      expect(prevention).toHaveProperty('vulnerableItems');
      expect(prevention).toHaveProperty('preventiveMeasures');
      expect(prevention).toHaveProperty('inspectionSchedule');
      expect(prevention).toHaveProperty('treatments');

      expect(['low', 'medium', 'high', 'critical']).toContain(prevention.riskLevel);
      expect(Array.isArray(prevention.vulnerableItems)).toBe(true);
      expect(Array.isArray(prevention.preventiveMeasures)).toBe(true);
      expect(Array.isArray(prevention.inspectionSchedule)).toBe(true);
      expect(Array.isArray(prevention.treatments)).toBe(true);
    });

    it('should get due maintenance tasks', async () => {
      // First schedule a task
      const dueDate = new Date(Date.now() - 86400000); // Yesterday (overdue)
      await maintenanceTracker.scheduleMaintenanceTask(
        'user_test_456',
        'item_test_123',
        'cleaning',
        dueDate,
        { priority: 'high' }
      );

      const alerts = await maintenanceTracker.getDueMaintenanceTasks('user_test_456');

      expect(Array.isArray(alerts)).toBe(true);
      if (alerts.length > 0) {
        const alert = alerts[0];
        expect(alert).toHaveProperty('itemId');
        expect(alert).toHaveProperty('type');
        expect(alert).toHaveProperty('priority');
        expect(alert).toHaveProperty('message');
        expect(alert).toHaveProperty('dueDate');
        expect(alert).toHaveProperty('actions');
      }
    });
  });

  describe('Inventory Manager', () => {
    it('should add item to inventory', async () => {
      const location = {
        closetId: 'closet_test_123',
        spaceId: 'space_main',
        sectionId: 'section_1'
      };

      const entry = await inventoryManager.addItem('user_test_456', mockItem, location, {
        generateBarcode: true,
        assignRFID: true,
        autoValuation: true
      });

      expect(entry).toHaveProperty('id');
      expect(entry).toHaveProperty('itemId', mockItem.id);
      expect(entry).toHaveProperty('location');
      expect(entry).toHaveProperty('status', 'available');
      expect(entry).toHaveProperty('lastSeen');
      expect(entry).toHaveProperty('checkInHistory');
      expect(entry).toHaveProperty('valuation');
      expect(entry).toHaveProperty('metadata');

      expect(entry.location.closetId).toBe(location.closetId);
      expect(entry.lastSeen instanceof Date).toBe(true);
      expect(Array.isArray(entry.checkInHistory)).toBe(true);
    });

    it('should scan barcode and return item data', async () => {
      const barcode = '1234567890123';
      const result = await inventoryManager.scanBarcode(barcode);

      expect(result).toHaveProperty('item', undefined); // No existing item for this test
      expect(result).toHaveProperty('suggestions');

      if (result.suggestions) {
        expect(Array.isArray(result.suggestions)).toBe(true);
      }
    });

    it('should track item valuation', async () => {
      const analytics = await inventoryManager.trackValuation('user_test_456');

      expect(analytics).toHaveProperty('totalValue');
      expect(analytics).toHaveProperty('appreciation');
      expect(analytics).toHaveProperty('depreciation');
      expect(analytics).toHaveProperty('recommendations');

      expect(typeof analytics.totalValue).toBe('number');
      expect(Array.isArray(analytics.appreciation)).toBe(true);
      expect(Array.isArray(analytics.depreciation)).toBe(true);
      expect(Array.isArray(analytics.recommendations)).toBe(true);
    });

    it('should detect missing items', async () => {
      const missingItems = await inventoryManager.detectMissingItems('user_test_456');

      expect(Array.isArray(missingItems)).toBe(true);

      if (missingItems.length > 0) {
        const item = missingItems[0];
        expect(item).toHaveProperty('itemId');
        expect(item).toHaveProperty('lastSeen');
        expect(item).toHaveProperty('expectedLocation');
        expect(item).toHaveProperty('searchSuggestions');
        expect(item).toHaveProperty('priority');
        expect(item).toHaveProperty('autoGenerated');
      }
    });

    it('should export inventory data', async () => {
      const formats = ['csv', 'xlsx', 'pdf', 'json'] as const;

      for (const format of formats) {
        const result = await inventoryManager.exportInventory('user_test_456', format, {
          includePhotos: true,
          includeValuation: true
        });

        expect(result).toHaveProperty('data');
        expect(result).toHaveProperty('filename');
        expect(result).toHaveProperty('metadata');

        expect(typeof result.filename).toBe('string');
        expect(result.filename).toContain(format);
        expect(typeof result.metadata).toBe('object');
        expect(result.metadata).toHaveProperty('totalItems');
        expect(result.metadata).toHaveProperty('exportDate');
      }
    });
  });

  describe('Smart Closet Features', () => {
    it('should prepare outfit for occasion', async () => {
      const weather = {
        temperature: { min: 15, max: 22 },
        conditions: ['partly_cloudy'],
        humidity: 65,
        windSpeed: 10
      };

      const location = {
        venue: 'office',
        indoor: true,
        formality: 'business_casual'
      };

      const preparation = await smartFeatures.prepareOutfit(
        'user_test_456',
        'business_meeting',
        new Date(Date.now() + 86400000), // Tomorrow
        weather,
        location
      );

      expect(preparation).toHaveProperty('id');
      expect(preparation).toHaveProperty('userId', 'user_test_456');
      expect(preparation).toHaveProperty('occasion', 'business_meeting');
      expect(preparation).toHaveProperty('weather');
      expect(preparation).toHaveProperty('location');
      expect(preparation).toHaveProperty('suggestions');
      expect(preparation).toHaveProperty('preparation');
      expect(preparation).toHaveProperty('status', 'planned');

      expect(Array.isArray(preparation.suggestions)).toBe(true);
      expect(preparation.preparation).toHaveProperty('timeNeeded');
      expect(preparation.preparation).toHaveProperty('steps');
      expect(preparation.preparation).toHaveProperty('reminders');
    });

    it('should create packing plan for trip', async () => {
      const tripDetails = {
        destination: 'Paris',
        startDate: new Date(Date.now() + 7 * 86400000), // Next week
        endDate: new Date(Date.now() + 14 * 86400000), // Two weeks
        activities: ['sightseeing', 'dining', 'business_meeting'],
        climate: 'temperate'
      };

      const packingPlan = await smartFeatures.createPackingPlan('user_test_456', tripDetails);

      expect(packingPlan).toHaveProperty('id');
      expect(packingPlan).toHaveProperty('userId', 'user_test_456');
      expect(packingPlan).toHaveProperty('destination');
      expect(packingPlan).toHaveProperty('outfits');
      expect(packingPlan).toHaveProperty('essentials');
      expect(packingPlan).toHaveProperty('packing');
      expect(packingPlan).toHaveProperty('checklist');
      expect(packingPlan).toHaveProperty('status', 'planning');

      expect(packingPlan.destination.location).toBe('Paris');
      expect(Array.isArray(packingPlan.outfits)).toBe(true);
      expect(Array.isArray(packingPlan.checklist)).toBe(true);
    });

    it('should track lending of items', async () => {
      const borrower = {
        name: 'John Doe',
        contact: 'john@example.com',
        relationship: 'friend'
      };

      const expectedReturn = new Date(Date.now() + 14 * 86400000); // Two weeks

      const lendingRecord = await smartFeatures.trackLending(
        'user_test_456',
        'item_test_123',
        borrower,
        expectedReturn
      );

      expect(lendingRecord).toHaveProperty('id');
      expect(lendingRecord).toHaveProperty('userId', 'user_test_456');
      expect(lendingRecord).toHaveProperty('itemId', 'item_test_123');
      expect(lendingRecord).toHaveProperty('borrower');
      expect(lendingRecord).toHaveProperty('lentDate');
      expect(lendingRecord).toHaveProperty('expectedReturn');
      expect(lendingRecord).toHaveProperty('status', 'active');

      expect(lendingRecord.borrower.name).toBe(borrower.name);
      expect(lendingRecord.expectedReturn).toEqual(expectedReturn);
    });

    it('should analyze gaps in wardrobe', async () => {
      const gapAnalysis = await smartFeatures.analyzeGaps('user_test_456');

      expect(gapAnalysis).toHaveProperty('category');
      expect(gapAnalysis).toHaveProperty('missing');
      expect(gapAnalysis).toHaveProperty('oversupplied');
      expect(gapAnalysis).toHaveProperty('recommendations');

      expect(Array.isArray(gapAnalysis.missing)).toBe(true);
      expect(Array.isArray(gapAnalysis.oversupplied)).toBe(true);
      expect(Array.isArray(gapAnalysis.recommendations)).toBe(true);

      if (gapAnalysis.missing.length > 0) {
        const gap = gapAnalysis.missing[0];
        expect(gap).toHaveProperty('type');
        expect(gap).toHaveProperty('priority');
        expect(gap).toHaveProperty('reason');
        expect(gap).toHaveProperty('estimatedCost');
      }
    });

    it('should generate purchase suggestions', async () => {
      const budget = 500;
      const preferences = {
        priorities: ['work_clothes', 'casual_wear'],
        excludeCategories: ['formal_wear'],
        maxItems: 5
      };

      const suggestions = await smartFeatures.generatePurchaseSuggestions(
        'user_test_456',
        budget,
        preferences
      );

      expect(Array.isArray(suggestions)).toBe(true);

      if (suggestions.length > 0) {
        const suggestion = suggestions[0];
        expect(suggestion).toHaveProperty('id');
        expect(suggestion).toHaveProperty('category');
        expect(suggestion).toHaveProperty('priority');
        expect(suggestion).toHaveProperty('reasoning');
        expect(suggestion).toHaveProperty('budget');
        expect(suggestion).toHaveProperty('specifications');
        expect(suggestion).toHaveProperty('versatility');

        expect(Array.isArray(suggestion.reasoning)).toBe(true);
        expect(typeof suggestion.budget).toBe('object');
        expect(typeof suggestion.versatility).toBe('number');
      }
    });

    it('should identify donation candidates', async () => {
      const candidates = await smartFeatures.identifyDonationCandidates('user_test_456');

      expect(Array.isArray(candidates)).toBe(true);

      if (candidates.length > 0) {
        const candidate = candidates[0];
        expect(candidate).toHaveProperty('itemId');
        expect(candidate).toHaveProperty('reasons');
        expect(candidate).toHaveProperty('confidence');
        expect(candidate).toHaveProperty('value');
        expect(candidate).toHaveProperty('recipient');
        expect(candidate).toHaveProperty('preparation');

        expect(Array.isArray(candidate.reasons)).toBe(true);
        expect(typeof candidate.confidence).toBe('number');
        expect(candidate.confidence).toBeGreaterThanOrEqual(0);
        expect(candidate.confidence).toBeLessThanOrEqual(1);
      }
    });
  });

  describe('Smart Home Integration', () => {
    it('should connect smart home device', async () => {
      const deviceConfig = {
        type: 'light',
        brand: 'Philips',
        model: 'Hue White',
        ipAddress: '192.168.1.100'
      };

      const device = await smartHomeIntegration.connectDevice(deviceConfig);

      expect(device).toHaveProperty('id');
      expect(device).toHaveProperty('name');
      expect(device).toHaveProperty('type', 'light');
      expect(device).toHaveProperty('brand', 'Philips');
      expect(device).toHaveProperty('model', 'Hue White');
      expect(device).toHaveProperty('capabilities');
      expect(device).toHaveProperty('status', 'online');
      expect(device).toHaveProperty('configuration');

      expect(Array.isArray(device.capabilities)).toBe(true);
    });

    it('should setup IoT sensors in closet', async () => {
      const sensorConfig = {
        temperature: { count: 2, positions: [{ x: 0, y: 100, z: 0 }, { x: 200, y: 100, z: 60 }] },
        humidity: { count: 1, positions: [{ x: 100, y: 150, z: 30 }] },
        motion: { count: 1, positions: [{ x: 100, y: 50, z: 0 }] },
        light: { count: 1, positions: [{ x: 100, y: 200, z: 30 }] }
      };

      const sensors = await smartHomeIntegration.setupIoTSensors('closet_test_123', sensorConfig);

      expect(Array.isArray(sensors)).toBe(true);
      expect(sensors.length).toBe(5); // 2 + 1 + 1 + 1

      const temperatureSensors = sensors.filter(s => s.type === 'temperature');
      expect(temperatureSensors.length).toBe(2);

      if (sensors.length > 0) {
        const sensor = sensors[0];
        expect(sensor).toHaveProperty('id');
        expect(sensor).toHaveProperty('type');
        expect(sensor).toHaveProperty('location');
        expect(sensor).toHaveProperty('readings');
        expect(sensor).toHaveProperty('alerts');
        expect(sensor).toHaveProperty('battery');

        expect(sensor.location.closetId).toBe('closet_test_123');
        expect(Array.isArray(sensor.readings)).toBe(true);
      }
    });

    it('should process voice commands', async () => {
      const command = 'show me outfit suggestions for today';
      const context = {
        userId: 'user_test_456',
        deviceId: 'alexa_echo_1',
        timestamp: new Date()
      };

      const result = await smartHomeIntegration.processVoiceCommand(command, context);

      expect(result).toHaveProperty('understood');
      expect(result).toHaveProperty('response');

      if (result.understood) {
        expect(result).toHaveProperty('action');
        expect(typeof result.response).toBe('string');
      }
    });

    it('should setup climate monitoring', async () => {
      const preferences = {
        tempRange: { min: 18, max: 24 },
        humidityRange: { min: 40, max: 60 },
        autoControl: true
      };

      const monitoring = await smartHomeIntegration.setupClimateMonitoring(
        'closet_test_123',
        preferences
      );

      expect(monitoring).toHaveProperty('sensors');
      expect(monitoring).toHaveProperty('currentConditions');
      expect(monitoring).toHaveProperty('alerts');
      expect(monitoring).toHaveProperty('automation');
      expect(monitoring).toHaveProperty('history');

      expect(Array.isArray(monitoring.sensors)).toBe(true);
      expect(Array.isArray(monitoring.alerts)).toBe(true);
      expect(Array.isArray(monitoring.history)).toBe(true);
      expect(typeof monitoring.currentConditions).toBe('object');
      expect(typeof monitoring.automation).toBe('object');
    });
  });

  describe('Dashboard Controller', () => {
    it('should get dashboard data', async () => {
      const dashboardData = await dashboardController.getDashboardData('user_test_456');

      expect(dashboardData).toHaveProperty('closets');
      expect(dashboardData).toHaveProperty('analytics');
      expect(dashboardData).toHaveProperty('quickActions');
      expect(dashboardData).toHaveProperty('notifications');
      expect(dashboardData).toHaveProperty('widgets');

      expect(Array.isArray(dashboardData.closets)).toBe(true);
      expect(Array.isArray(dashboardData.quickActions)).toBe(true);
      expect(Array.isArray(dashboardData.notifications)).toBe(true);
      expect(Array.isArray(dashboardData.widgets)).toBe(true);

      expect(dashboardData.analytics).toHaveProperty('totalItems');
      expect(dashboardData.analytics).toHaveProperty('totalValue');
      expect(dashboardData.analytics).toHaveProperty('utilizationRate');
      expect(dashboardData.analytics).toHaveProperty('maintenanceDue');
      expect(dashboardData.analytics).toHaveProperty('recentActivity');
    });

    it('should execute quick actions', async () => {
      const actionIds = ['quick_add_item', 'organize_closet', 'scan_barcode', 'outfit_suggestion'];

      for (const actionId of actionIds) {
        const result = await dashboardController.executeQuickAction('user_test_456', actionId);

        expect(result).toHaveProperty('success');
        expect(result).toHaveProperty('message');
        expect(typeof result.success).toBe('boolean');
        expect(typeof result.message).toBe('string');

        if (result.success && result.data) {
          expect(typeof result.data).toBe('object');
        }
      }
    });
  });

  describe('Item Management Controller', () => {
    const mockFormData = {
      basic: {
        name: 'Test Item',
        brand: 'Test Brand',
        description: 'A test clothing item',
        tags: ['test', 'basic']
      },
      category: {
        main: 'tops',
        sub: 'shirt',
        type: 'button_down',
        season: ['spring', 'summer'],
        occasion: ['business', 'casual'],
        formality: 'business_casual'
      },
      physical: {
        colors: {
          primary: 'blue',
          secondary: [],
          colorCodes: { blue: '#0066CC' }
        },
        materials: {
          primary: 'cotton',
          composition: { cotton: 80, polyester: 20 },
          careInstructions: ['machine_wash', 'tumble_dry_low']
        },
        size: {
          label: 'L',
          fit: 'regular'
        }
      },
      purchase: {
        date: new Date('2023-06-01'),
        price: 59.99,
        store: 'Test Store'
      },
      images: {
        main: '/images/test-shirt.jpg',
        gallery: ['/images/test-shirt-front.jpg', '/images/test-shirt-back.jpg'],
        details: []
      },
      location: {
        closetId: 'closet_test_123',
        spaceId: 'space_main',
        sectionId: 'section_1'
      }
    };

    it('should create new item', async () => {
      const result = await itemController.createItem('user_test_456', mockFormData);

      expect(result).toHaveProperty('success');
      expect(typeof result.success).toBe('boolean');

      if (result.success) {
        expect(result).toHaveProperty('itemId');
        expect(typeof result.itemId).toBe('string');
      } else {
        expect(result).toHaveProperty('errors');
        expect(typeof result.errors).toBe('object');
      }
    });

    it('should get item list with filters and pagination', async () => {
      const options = {
        filters: {
          categories: ['tops'],
          colors: ['blue'],
          priceRange: { min: 0, max: 100 }
        },
        sorting: {
          field: 'name' as const,
          direction: 'asc' as const
        },
        pagination: {
          page: 1,
          limit: 10
        },
        search: 'shirt'
      };

      const result = await itemController.getItemList('user_test_456', options);

      expect(result).toHaveProperty('items');
      expect(result).toHaveProperty('filters');
      expect(result).toHaveProperty('sorting');
      expect(result).toHaveProperty('grouping');
      expect(result).toHaveProperty('pagination');

      expect(Array.isArray(result.items)).toBe(true);
      expect(typeof result.filters).toBe('object');
      expect(typeof result.sorting).toBe('object');
      expect(typeof result.pagination).toBe('object');

      expect(result.pagination).toHaveProperty('page', 1);
      expect(result.pagination).toHaveProperty('limit', 10);
      expect(result.pagination).toHaveProperty('total');
      expect(result.pagination).toHaveProperty('hasNext');
      expect(result.pagination).toHaveProperty('hasPrev');
    });

    it('should perform bulk operations', async () => {
      const itemIds = ['item_1', 'item_2', 'item_3'];
      const action = 'add_tags';
      const parameters = { tags: ['bulk_test', 'updated'] };

      const result = await itemController.bulkUpdate(itemIds, action, parameters);

      expect(result).toHaveProperty('success');
      expect(result).toHaveProperty('results');
      expect(result).toHaveProperty('summary');

      expect(Array.isArray(result.results)).toBe(true);
      expect(result.results.length).toBe(itemIds.length);

      expect(result.summary).toHaveProperty('successful');
      expect(result.summary).toHaveProperty('failed');
      expect(result.summary).toHaveProperty('total', itemIds.length);

      result.results.forEach(res => {
        expect(res).toHaveProperty('itemId');
        expect(res).toHaveProperty('success');
        expect(itemIds).toContain(res.itemId);
      });
    });

    it('should export items in different formats', async () => {
      const itemIds = ['item_test_123'];
      const formats = ['csv', 'json', 'pdf'] as const;

      for (const format of formats) {
        const result = await itemController.exportItems(itemIds, format, {
          includeImages: true,
          includeAnalytics: true
        });

        expect(result).toHaveProperty('data');
        expect(result).toHaveProperty('filename');
        expect(result).toHaveProperty('contentType');

        expect(result.filename).toContain(format);
        expect(typeof result.contentType).toBe('string');

        if (format === 'json') {
          expect(typeof result.data).toBe('string');
        } else {
          expect(result.data instanceof ArrayBuffer).toBe(true);
        }
      }
    });
  });

  describe('Error Handling', () => {
    it('should handle invalid data gracefully', async () => {
      const invalidFormData = {
        basic: {
          name: '', // Empty name should cause validation error
          tags: []
        },
        category: {
          main: '',
          sub: '',
          type: '',
          season: [],
          occasion: [],
          formality: 'invalid' as any
        },
        physical: {},
        images: {},
        location: {}
      } as any;

      const result = await itemController.createItem('user_test_456', invalidFormData);

      expect(result.success).toBe(false);
      expect(result).toHaveProperty('errors');
      expect(typeof result.errors).toBe('object');
    });

    it('should handle missing user gracefully', async () => {
      const result = await dashboardController.getDashboardData('');

      // Should still return data structure even for invalid user
      expect(result).toHaveProperty('closets');
      expect(result).toHaveProperty('analytics');
      expect(result).toHaveProperty('quickActions');
      expect(result).toHaveProperty('notifications');
      expect(result).toHaveProperty('widgets');
    });
  });

  describe('Integration Tests', () => {
    it('should create complete closet workflow', async () => {
      const userId = 'user_integration_test';

      // 1. Create item
      const itemResult = await itemController.createItem(userId, mockFormData);
      expect(itemResult.success).toBe(true);

      // 2. Add to inventory
      const location = {
        closetId: 'closet_test_123',
        spaceId: 'space_main',
        sectionId: 'section_1'
      };
      const inventoryEntry = await inventoryManager.addItem(userId, mockItem, location);
      expect(inventoryEntry).toHaveProperty('id');

      // 3. Schedule maintenance
      const dueDate = new Date(Date.now() + 30 * 86400000);
      const maintenanceRecord = await maintenanceTracker.scheduleMaintenanceTask(
        userId,
        mockItem.id,
        'cleaning',
        dueDate,
        { priority: 'medium' }
      );
      expect(maintenanceRecord).toHaveProperty('id');

      // 4. Analyze closet
      const analysis = await organizationAI.analyzeCloset(mockCloset, [mockItem]);
      expect(analysis).toHaveProperty('efficiency');

      // 5. Get dashboard data
      const dashboard = await dashboardController.getDashboardData(userId);
      expect(dashboard).toHaveProperty('analytics');
      expect(dashboard.analytics.totalItems).toBeGreaterThanOrEqual(0);
    });
  });
});

// Export test utilities for other test files
export {
  mockItem,
  mockCloset
};