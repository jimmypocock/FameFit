/**
 * FameFit Push Notification Service
 * 
 * Main entry point for the backend push notification service.
 * Handles CloudKit subscriptions, notification processing, and APNS communication.
 */

require('dotenv').config();

const express = require('express');
const winston = require('winston');
const PushNotificationService = require('./services/PushNotificationService');
const CloudKitService = require('./services/CloudKitService');
const APNSService = require('./services/APNSService');
const NotificationQueue = require('./services/NotificationQueue');
const config = require('./config');

// Configure logging
const logger = winston.createLogger({
  level: config.LOG_LEVEL,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

async function main() {
  try {
    logger.info('Starting FameFit Push Notification Service...');

    // Initialize services
    const cloudKitService = new CloudKitService(config.cloudKit, logger);
    const apnsService = new APNSService(config.apns, logger);
    const notificationQueue = new NotificationQueue(config.redis, logger);
    
    const pushService = new PushNotificationService({
      cloudKit: cloudKitService,
      apns: apnsService,
      queue: notificationQueue,
      logger
    });

    // Initialize all services
    await cloudKitService.initialize();
    await apnsService.initialize();
    await notificationQueue.initialize();
    await pushService.initialize();

    // Set up health check endpoint
    const app = express();
    app.use(express.json());

    app.get('/health', (req, res) => {
      res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        services: {
          cloudKit: cloudKitService.isHealthy(),
          apns: apnsService.isHealthy(),
          queue: notificationQueue.isHealthy()
        }
      });
    });

    app.get('/metrics', async (req, res) => {
      const metrics = await pushService.getMetrics();
      res.json(metrics);
    });

    // Start HTTP server for health checks and metrics
    const port = process.env.PORT || 3000;
    app.listen(port, () => {
      logger.info(`Push service HTTP server listening on port ${port}`);
    });

    logger.info('FameFit Push Notification Service started successfully');

    // Graceful shutdown handling
    process.on('SIGINT', async () => {
      logger.info('Received SIGINT, shutting down gracefully...');
      
      try {
        await pushService.shutdown();
        await notificationQueue.shutdown();
        await cloudKitService.shutdown();
        await apnsService.shutdown();
        
        logger.info('Shutdown complete');
        process.exit(0);
      } catch (error) {
        logger.error('Error during shutdown:', error);
        process.exit(1);
      }
    });

  } catch (error) {
    logger.error('Failed to start push service:', error);
    process.exit(1);
  }
}

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

main();