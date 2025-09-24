# Use Node.js 18 LTS as base image for better stability
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create config/secret directory and set permissions
RUN mkdir -p config/secret && \
    chown -R node:node /app

# Switch to non-root user for security
USER node

# Expose port 8000
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8000/ || exit 1

# Start the application
CMD ["npm", "start"]
