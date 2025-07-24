# FameFit Push Notification Service
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Install dependencies first (for better caching)
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/
COPY certs/ ./certs/ 

# Create logs directory
RUN mkdir -p logs

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S pushservice -u 1001

# Set permissions
RUN chown -R pushservice:nodejs /app
USER pushservice

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

# Expose port
EXPOSE 3000

# Start the service
CMD ["node", "src/index.js"]