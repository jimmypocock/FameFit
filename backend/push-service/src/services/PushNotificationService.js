/**
 * Main Push Notification Service
 * 
 * Orchestrates the entire push notification flow:
 * - Listens to CloudKit changes
 * - Processes notification triggers
 * - Manages batching and rate limiting
 * - Coordinates with APNS service
 */

const cron = require('node-cron');
const NotificationProcessor = require('./NotificationProcessor');
const MetricsCollector = require('./MetricsCollector');

class PushNotificationService {
  constructor({ cloudKit, apns, queue, logger }) {
    this.cloudKit = cloudKit;
    this.apns = apns;
    this.queue = queue;
    this.logger = logger;
    
    this.processor = new NotificationProcessor({ apns, logger });
    this.metrics = new MetricsCollector({ logger });
    
    this.isRunning = false;
    this.subscriptionCallbacks = new Map();
  }

  async initialize() {
    this.logger.info('Initializing Push Notification Service...');

    // Set up CloudKit change subscriptions
    await this.setupCloudKitSubscriptions();
    
    // Start notification processing worker
    await this.startNotificationWorker();
    
    // Start batch processing
    this.startBatchProcessor();
    
    // Start scheduled tasks
    this.startScheduledTasks();
    
    this.isRunning = true;
    this.logger.info('Push Notification Service initialized successfully');
  }

  async setupCloudKitSubscriptions() {
    const subscriptions = [
      { recordType: 'WorkoutHistory', handler: this.handleWorkoutChange.bind(this) },
      { recordType: 'UserRelationships', handler: this.handleRelationshipChange.bind(this) },
      { recordType: 'WorkoutComments', handler: this.handleCommentChange.bind(this) },
      { recordType: 'WorkoutKudos', handler: this.handleKudosChange.bind(this) },
      { recordType: 'GroupWorkouts', handler: this.handleGroupWorkoutChange.bind(this) },
      { recordType: 'Users', handler: this.handleUserChange.bind(this) }
    ];

    for (const { recordType, handler } of subscriptions) {
      try {
        await this.cloudKit.subscribe(recordType, handler);
        this.subscriptionCallbacks.set(recordType, handler);
        this.logger.info(`Subscribed to ${recordType} changes`);
      } catch (error) {
        this.logger.error(`Failed to subscribe to ${recordType}:`, error);
        throw error;
      }
    }
  }

  // CloudKit Change Handlers
  async handleWorkoutChange(change) {
    if (change.changeType !== 'CREATE') return;
    
    try {
      const workout = change.record;
      this.logger.debug(`Processing workout completion: ${workout.recordName}`);
      
      // Get workout owner's followers
      const followers = await this.getWorkoutFollowers(workout.fields.userId.value);
      
      // Queue notifications for all followers
      const notifications = followers.map(follower => ({
        userId: follower.userId,
        type: 'workout_completed',
        priority: 'normal',
        data: {
          workoutId: workout.recordName,
          ownerName: follower.ownerName,
          workoutType: workout.fields.workoutType?.value || 'Workout',
          xpEarned: workout.fields.xpEarned?.value || 0,
          duration: Math.floor((workout.fields.duration?.value || 0) / 60), // minutes
          calories: Math.floor(workout.fields.totalEnergyBurned?.value || 0)
        },
        scheduledFor: new Date()
      }));
      
      await this.queueNotifications(notifications);
      this.metrics.recordEvent('workout_notifications_queued', notifications.length);
      
    } catch (error) {
      this.logger.error('Error handling workout change:', error);
    }
  }

  async handleRelationshipChange(change) {
    if (change.changeType !== 'CREATE') return;
    
    try {
      const relationship = change.record;
      const followerID = relationship.fields.followerID?.value;
      const followingID = relationship.fields.followingID?.value;
      
      if (!followerID || !followingID) return;
      
      this.logger.debug(`Processing new follow: ${followerID} -> ${followingID}`);
      
      // Get follower's profile info
      const followerProfile = await this.getUserProfile(followerID);
      if (!followerProfile) return;
      
      const notification = {
        userId: followingID,
        type: 'new_follower',
        priority: 'high',
        data: {
          followerID: followerID,
          followerName: followerProfile.displayName,
          followerUsername: followerProfile.username,
          followerXP: followerProfile.totalXP
        },
        scheduledFor: new Date()
      };
      
      await this.queueNotifications([notification]);
      this.metrics.recordEvent('follow_notifications_queued', 1);
      
    } catch (error) {
      this.logger.error('Error handling relationship change:', error);
    }
  }

  async handleCommentChange(change) {
    if (change.changeType !== 'CREATE') return;
    
    try {
      const comment = change.record;
      const workoutOwnerId = comment.fields.workoutOwnerId?.value;
      const commenterId = comment.fields.userId?.value;
      const content = comment.fields.content?.value;
      
      if (!workoutOwnerId || !commenterId || workoutOwnerId === commenterId) return;
      
      this.logger.debug(`Processing workout comment: ${comment.recordName}`);
      
      // Get commenter's profile
      const commenterProfile = await this.getUserProfile(commenterId);
      if (!commenterProfile) return;
      
      const notification = {
        userId: workoutOwnerId,
        type: 'workout_comment',
        priority: 'high',
        data: {
          commentId: comment.recordName,
          workoutId: comment.fields.workoutId?.value,
          commenterName: commenterProfile.displayName,
          commenterUsername: commenterProfile.username,
          commentPreview: content ? content.substring(0, 50) + (content.length > 50 ? '...' : '') : ''
        },
        scheduledFor: new Date()
      };
      
      await this.queueNotifications([notification]);
      this.metrics.recordEvent('comment_notifications_queued', 1);
      
    } catch (error) {
      this.logger.error('Error handling comment change:', error);
    }
  }

  async handleKudosChange(change) {
    if (change.changeType !== 'CREATE') return;
    
    try {
      const kudos = change.record;
      const workoutOwnerId = kudos.fields.workoutOwnerId?.value;
      const giverId = kudos.fields.userId?.value;
      
      if (!workoutOwnerId || !giverId || workoutOwnerId === giverId) return;
      
      this.logger.debug(`Processing workout kudos: ${kudos.recordName}`);
      
      // Get kudos giver's profile
      const giverProfile = await this.getUserProfile(giverId);
      if (!giverProfile) return;
      
      const notification = {
        userId: workoutOwnerId,
        type: 'workout_kudos',
        priority: 'low', // Kudos are less urgent
        data: {
          kudosId: kudos.recordName,
          workoutId: kudos.fields.workoutId?.value,
          giverName: giverProfile.displayName,
          giverUsername: giverProfile.username
        },
        scheduledFor: new Date()
      };
      
      await this.queueNotifications([notification]);
      this.metrics.recordEvent('kudos_notifications_queued', 1);
      
    } catch (error) {
      this.logger.error('Error handling kudos change:', error);
    }
  }

  async handleGroupWorkoutChange(change) {
    // Handle group workout notifications (invites, starts, etc.)
    if (change.changeType === 'UPDATE') {
      const workout = change.record;
      const status = workout.fields.status?.value;
      
      if (status === 'active') {
        await this.handleGroupWorkoutStarted(workout);
      }
    }
  }

  async handleUserChange(change) {
    // Handle user-related notifications (level ups, milestones)
    if (change.changeType === 'UPDATE') {
      const user = change.record;
      const totalXP = user.fields.totalXP?.value;
      const previousXP = change.previousRecord?.fields?.totalXP?.value;
      
      if (totalXP && previousXP && totalXP > previousXP) {
        await this.checkXPMilestones(user.recordName, previousXP, totalXP);
      }
    }
  }

  // Notification Processing
  async startNotificationWorker() {
    this.logger.info('Starting notification worker...');
    
    // Process notifications from the queue
    this.queue.process('notification', async (job) => {
      const { notification } = job.data;
      
      try {
        await this.processor.processNotification(notification);
        this.metrics.recordEvent('notification_processed', 1);
        
        // Update job progress
        job.progress(100);
        
      } catch (error) {
        this.logger.error('Failed to process notification:', error);
        this.metrics.recordEvent('notification_failed', 1);
        throw error; // Let Bull handle retries
      }
    });
    
    this.logger.info('Notification worker started');
  }

  startBatchProcessor() {
    // Process batched notifications every 30 seconds
    cron.schedule('*/30 * * * * *', async () => {
      if (!this.isRunning) return;
      
      try {
        await this.processBatchedNotifications();
      } catch (error) {
        this.logger.error('Error in batch processor:', error);
      }
    });
    
    this.logger.info('Batch processor started');
  }

  startScheduledTasks() {
    // Clean up old device tokens daily
    cron.schedule('0 2 * * *', async () => {
      if (!this.isRunning) return;
      
      try {
        await this.cleanupDeviceTokens();
      } catch (error) {
        this.logger.error('Error in device token cleanup:', error);
      }
    });
    
    // Send scheduled notifications (like workout reminders)
    cron.schedule('* * * * *', async () => { // Every minute
      if (!this.isRunning) return;
      
      try {
        await this.processScheduledNotifications();
      } catch (error) {
        this.logger.error('Error processing scheduled notifications:', error);
      }
    });
    
    this.logger.info('Scheduled tasks started');
  }

  // Helper Methods
  async queueNotifications(notifications) {
    const jobs = notifications.map(notification => ({
      name: 'notification',
      data: { notification },
      opts: {
        priority: this.getPriority(notification.priority),
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 2000
        }
      }
    }));
    
    await this.queue.addBulk(jobs);
  }

  getPriority(priorityString) {
    const priorities = {
      'immediate': 10,
      'high': 5,
      'normal': 1,
      'low': -5
    };
    return priorities[priorityString] || 1;
  }

  async getWorkoutFollowers(userId) {
    // Implement CloudKit query to get user's followers
    // This is a simplified version
    return [];
  }

  async getUserProfile(userId) {
    // Implement CloudKit query to get user profile
    return null;
  }

  async processBatchedNotifications() {
    // Process low-priority notifications in batches
    this.logger.debug('Processing batched notifications...');
  }

  async processScheduledNotifications() {
    // Process notifications scheduled for this time
    this.logger.debug('Processing scheduled notifications...');
  }

  async cleanupDeviceTokens() {
    // Remove invalid/expired device tokens
    this.logger.debug('Cleaning up device tokens...');
  }

  async checkXPMilestones(userId, previousXP, currentXP) {
    // Check if user hit any XP milestones
    const milestones = [100, 500, 1000, 2500, 5000, 10000];
    
    for (const milestone of milestones) {
      if (previousXP < milestone && currentXP >= milestone) {
        const notification = {
          userId,
          type: 'xp_milestone',
          priority: 'high',
          data: {
            milestone,
            totalXP: currentXP
          },
          scheduledFor: new Date()
        };
        
        await this.queueNotifications([notification]);
        break; // Only notify for one milestone at a time
      }
    }
  }

  // Metrics and Monitoring
  async getMetrics() {
    return {
      notifications: {
        queued: await this.queue.getWaiting().length,
        processing: await this.queue.getActive().length,
        completed: await this.queue.getCompleted().length,
        failed: await this.queue.getFailed().length
      },
      apns: await this.apns.getMetrics(),
      uptime: process.uptime()
    };
  }

  // Shutdown
  async shutdown() {
    this.logger.info('Shutting down Push Notification Service...');
    
    this.isRunning = false;
    
    // Unsubscribe from CloudKit changes
    for (const [recordType, callback] of this.subscriptionCallbacks) {
      await this.cloudKit.unsubscribe(recordType, callback);
    }
    
    // Close the notification queue
    await this.queue.close();
    
    this.logger.info('Push Notification Service shutdown complete');
  }
}

module.exports = PushNotificationService;