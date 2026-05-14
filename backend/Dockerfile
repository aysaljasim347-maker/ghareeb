# ── Stage 1: Build ──
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# ── Stage 2: Runtime ──
FROM node:20-alpine
WORKDIR /app

# Non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Only production dependencies
COPY package*.json ./
RUN npm ci --omit=dev

# Copy compiled files
COPY --from=builder /app/dist ./dist

# Required for some runtime node_modules if they expect src (rare, but keeping for safety if needed, 
# though normally dist/ is enough. Based on current setup, let's stick to dist/)

USER appuser
EXPOSE 3000

# IPv6 ready healthcheck (using 127.0.0.1 as per core mandate)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/api/health || exit 1

CMD ["node", "dist/index.js"]
