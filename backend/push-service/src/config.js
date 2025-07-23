/**
 * Configuration management for FameFit Push Service
 */

module.exports = {
  // Environment
  NODE_ENV: process.env.NODE_ENV || 'development',
  LOG_LEVEL: process.env.LOG_LEVEL || 'info',

  // CloudKit Configuration
  cloudKit: {
    containerIdentifier: process.env.CLOUDKIT_CONTAINER_ID || 'iCloud.com.jimmypocock.FameFit',
    apiToken: process.env.CLOUDKIT_API_TOKEN,
    environment: process.env.CLOUDKIT_ENVIRONMENT || 'development',
    subscriptions: [
      'WorkoutHistory',
      'UserRelationships', 
      'WorkoutComments',
      'WorkoutKudos',
      'GroupWorkouts',
      'Users'
    ]
  },

  // APNS Configuration
  apns: {
    keyId: process.env.APNS_KEY_ID,
    teamId: process.env.APNS_TEAM_ID,
    bundleId: process.env.APNS_BUNDLE_ID || 'com.jimmypocock.FameFit',
    keyPath: process.env.APNS_KEY_PATH || './certs/AuthKey.p8',
    production: process.env.APNS_PRODUCTION === 'true',
    
    // Rate limiting (per second)
    rateLimit: {
      perSecond: 100,
      burstLimit: 500
    }
  },

  // Redis Configuration (for queues and caching)
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT) || 6379,
    password: process.env.REDIS_PASSWORD,
    db: parseInt(process.env.REDIS_DB) || 0,
    
    // Connection pool
    maxRetriesPerRequest: 3,
    retryDelayOnFailover: 100,
    lazyConnect: true
  },

  // Notification Processing
  notifications: {
    // Batch processing settings
    batchSize: 100,
    batchInterval: 5000, // 5 seconds
    
    // Rate limiting per user
    userRateLimit: {
      maxPerHour: 50,
      maxPerDay: 200
    },
    
    // Retry settings
    maxRetries: 3,
    retryDelay: 2000, // 2 seconds
    
    // Notification preferences
    defaultPreferences: {
      workoutCompleted: true,
      newFollower: true,
      workoutKudos: true,
      workoutComment: true,
      groupWorkoutInvite: true,
      groupWorkoutStarting: true,
      xpMilestone: true,
      levelUp: true
    }
  },

  // Device Token Management
  deviceTokens: {
    // How often to validate tokens with APNS
    validationInterval: 24 * 60 * 60 * 1000, // 24 hours
    
    // When to consider a token stale
    staleThreshold: 7 * 24 * 60 * 60 * 1000, // 7 days
    
    // When to remove inactive tokens
    cleanupThreshold: 30 * 24 * 60 * 60 * 1000, // 30 days
  },

  // Health Check Settings
  healthCheck: {
    timeout: 5000, // 5 seconds
    checkInterval: 30000, // 30 seconds
  },

  // Metrics Collection
  metrics: {
    enabled: process.env.METRICS_ENABLED !== 'false',
    retentionDays: 30,
    
    // What to track
    track: {
      notificationsSent: true,
      notificationsFailed: true,
      processingLatency: true,
      queueDepth: true,
      deviceTokenHealth: true
    }
  }
};