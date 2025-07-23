# FameFit Push Notification Service

A robust backend service for handling Apple Push Notifications (APNS) for the FameFit fitness app ecosystem.

## Features

- **CloudKit Integration**: Listens to real-time database changes
- **APNS Communication**: Reliable push notification delivery
- **Intelligent Batching**: Optimized notification grouping and rate limiting
- **Device Token Management**: Automatic token validation and cleanup
- **Comprehensive Monitoring**: Metrics, health checks, and alerting
- **Scalable Architecture**: Redis-backed queuing with horizontal scaling support

## Quick Start

### Prerequisites

- Node.js 16+ 
- Redis server
- Apple Developer Account with APNS certificates
- CloudKit container with API access

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd backend/push-service
```

2. Install dependencies:
```bash
npm install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Add your APNS certificate:
```bash
mkdir certs
# Copy your AuthKey_<KeyID>.p8 file to certs/AuthKey.p8
```

### Development

Start the service in development mode:
```bash
npm run dev
```

The service will be available at `http://localhost:3000`

### Production Deployment

#### Using Docker Compose (Recommended)

1. Set up environment variables:
```bash
cp .env.example .env
# Fill in production values
```

2. Start the services:
```bash
docker-compose up -d
```

3. Monitor logs:
```bash
docker-compose logs -f push-service
```

#### Manual Deployment

1. Build the application:
```bash
npm run build
```

2. Start the production server:
```bash
NODE_ENV=production npm start
```

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `CLOUDKIT_API_TOKEN` | CloudKit Server-to-Server API token | ✓ |
| `APNS_KEY_ID` | Apple Push Notification service key ID | ✓ |
| `APNS_TEAM_ID` | Apple Developer Team ID | ✓ |
| `REDIS_HOST` | Redis server hostname | ✓ |
| `REDIS_PASSWORD` | Redis authentication password | ✓ |
| `NODE_ENV` | Environment (development/production) | ✓ |

See `.env.example` for complete configuration options.

### Apple Setup

1. **Generate APNS Authentication Key**:
   - Go to Apple Developer Portal
   - Certificates, Identifiers & Profiles → Keys
   - Create new key with Apple Push Notifications service enabled
   - Download and save as `certs/AuthKey.p8`

2. **CloudKit Setup**:
   - Enable CloudKit for your app
   - Generate Server-to-Server token
   - Configure record types with proper permissions

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS Apps      │    │  CloudKit       │    │  Push Service   │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Device Tokens│ │───▶│ │Record Changes│ │───▶│ │Notification │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ │Processing   │ │
│                 │    │                 │    │ └─────────────┘ │
│ ┌─────────────┐ │◀───│                 │    │ ┌─────────────┐ │
│ │Push Received│ │    │                 │    │ │APNS Client  │ │
│ └─────────────┘ │    │                 │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌─────────────────┐             │
                       │  Redis Queue    │◀────────────┘
                       │                 │
                       │ ┌─────────────┐ │
                       │ │Notification │ │
                       │ │Queue        │ │
                       │ └─────────────┘ │
                       │                 │
                       │ ┌─────────────┐ │
                       │ │Rate Limiting│ │
                       │ └─────────────┘ │
                       └─────────────────┘
```

## Notification Types

The service handles various notification types:

### Workout Notifications
- **Workout Completed**: Sent to followers when user completes workout
- **XP Milestone**: Triggered when user reaches XP milestones
- **Level Up**: Sent when user reaches new fitness level

### Social Notifications
- **New Follower**: When someone starts following the user
- **Workout Kudos**: When someone gives kudos to a workout
- **Workout Comment**: When someone comments on a workout
- **Mention**: When user is mentioned in comments

### Group Workout Notifications
- **Workout Starting**: Reminder 15 minutes before group workout
- **Participant Joined**: When someone joins your group workout
- **Workout Cancelled**: When host cancels a group workout

## API Endpoints

### Health Check
```http
GET /health
```
Returns service health status and component availability.

### Metrics
```http
GET /metrics
```
Returns performance metrics and statistics.

## Monitoring

### Health Checks
The service provides comprehensive health monitoring:
- CloudKit connectivity
- APNS connection status  
- Redis queue health
- Processing latency metrics

### Metrics Collection
Key metrics tracked:
- Notifications sent/failed
- Processing latency
- Queue depth
- Device token health
- APNS feedback processing

### Logging
Structured JSON logging with configurable levels:
- Error logs: Critical issues requiring attention
- Info logs: General service operations
- Debug logs: Detailed processing information

## Development

### Running Tests
```bash
npm test
```

### Linting
```bash
npm run lint
```

### Debug Mode
```bash
DEBUG=* npm run dev
```

## Scaling

### Horizontal Scaling
The service supports horizontal scaling:

1. **Multiple Instances**: Run multiple service instances behind a load balancer
2. **Queue Distribution**: Redis queues automatically distribute work
3. **Database Sharding**: CloudKit handles data distribution

### Performance Optimization
- **Batching**: Notifications are batched for efficiency
- **Rate Limiting**: Prevents APNS throttling
- **Caching**: Device tokens and user preferences cached
- **Connection Pooling**: Persistent APNS connections

## Security

### Authentication
- APNS authentication via P8 key files
- CloudKit Server-to-Server authentication
- Redis password authentication

### Data Privacy
- Minimal PII in notification payloads
- Secure device token handling
- Audit logging for compliance

### Network Security
- TLS encryption for all external communication
- VPC deployment recommended for production
- Firewall rules for Redis access

## Troubleshooting

### Common Issues

**APNS Authentication Failures**
```bash
# Verify key file format and permissions
openssl pkcs8 -in AuthKey.p8 -nocrypt -out key.pem
```

**CloudKit Connection Issues**
```bash
# Check API token validity
curl -H "Authorization: Bearer <token>" \
  "https://api.apple-cloudkit.com/database/1/<container>/development/records/list"
```

**Redis Connection Problems**
```bash
# Test Redis connectivity
redis-cli -h <host> -p <port> -a <password> ping
```

### Debugging

Enable debug logging:
```bash
LOG_LEVEL=debug npm start
```

Monitor queue status:
```bash
# Access Redis Commander at http://localhost:8081
docker-compose --profile monitoring up -d
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Check the troubleshooting guide above
- Review service logs for error details
- Open an issue with reproduction steps

---

**Production Checklist**

Before deploying to production:

- [ ] APNS certificates configured correctly
- [ ] CloudKit API token has proper permissions
- [ ] Redis secured with strong password
- [ ] Environment variables configured
- [ ] Log aggregation configured
- [ ] Monitoring/alerting set up
- [ ] Backup/recovery plan in place
- [ ] Load testing completed
- [ ] Security review completed