# syntax=docker/dockerfile:1

# ===== Stage 1: Dependencies =====
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# ===== Stage 2: Production =====
FROM node:20-alpine

WORKDIR /app

# Copy node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy backend source code
COPY src ./src
COPY package.json ./

# Copy contract artifacts (will be copied by CI/CD before build)
# CI/CD copies: contracts/artifacts/contracts -> backend/contracts/artifacts/contracts
COPY contracts/artifacts/contracts ./contracts/artifacts/contracts

# Security: Run as non-root user
USER node

# Expose backend port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:4000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start the application
CMD ["node", "src/server.js"]

