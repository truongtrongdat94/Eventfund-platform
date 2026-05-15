# syntax=docker/dockerfile:1.4

# ─── Stage 1: Install production dependencies ────────────────────────────────
FROM node:20.19.0-alpine AS deps

WORKDIR /app/backend

# Copy package manifests
COPY backend/package.json backend/package-lock.json ./

# Install production deps with cache mount for faster builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev --ignore-scripts

# ─── Stage 2: Production image ───────────────────────────────────────────────
FROM node:20.19.0-alpine AS production

# Security: non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app/backend

# Copy backend source and manifests
COPY --chown=appuser:appgroup backend/src ./src
COPY --chown=appuser:appgroup backend/package.json backend/package-lock.json ./

# Copy installed node_modules from deps stage
COPY --from=deps --chown=appuser:appgroup /app/backend/node_modules ./node_modules

# Create logs directory with correct permissions
RUN mkdir -p logs && chown -R appuser:appgroup logs

USER appuser

# Port metadata for documentation
EXPOSE 4000

STOPSIGNAL SIGTERM

CMD ["node", "src/server.js"]
