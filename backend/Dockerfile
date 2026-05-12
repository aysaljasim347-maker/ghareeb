# ── Stage 1: Build ──
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY jest.config.js ./
COPY src/ ./src/
COPY tests/ ./tests/
RUN npm run build

# ── Stage 2: Runtime with Dev Deps ──
FROM node:20-alpine
WORKDIR /app

RUN addgroup -g 1001 -S appgroup && \
  adduser -S appuser -u 1001 -G appgroup

COPY package*.json ./
RUN npm ci

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src ./src
COPY --from=builder /app/tests ./tests
COPY --from=builder /app/jest.config.js ./jest.config.js
COPY --from=builder /app/tsconfig.json ./tsconfig.json

USER appuser
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

CMD ["npm", "run", "dev"]