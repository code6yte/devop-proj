# syntax=docker/dockerfile:1
# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY app/package.json app/package-lock.json* ./

# Use BuildKit cache mount for node_modules
# This persists dependencies between builds even if the container is destroyed!
RUN --mount=type=cache,target=/root/.npm \
    npm install --legacy-peer-deps

# Copy source and build
COPY app/ .
RUN npm run build

# Stage 2: Runtime
FROM node:18-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production

# Copy only what is needed from the builder
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
# Copy next.config.js if it exists
COPY --from=builder /app/next.config.js ./next.config.js 2>/dev/null || :

EXPOSE 3000

CMD ["npm", "start"]
