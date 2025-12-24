# Stage 1: Dependency Install & Build
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files for caching
# We expect the context to be 'docker/web/', and the source code in 'docker/web/app/'
COPY app/package.json app/package-lock.json* ./

# Install dependencies (cached if package.json doesn't change)
RUN npm install --legacy-peer-deps

# Copy the rest of the source code
COPY app/ .

# Build the Next.js application
RUN npm run build

# Stage 2: Production Runner
FROM node:18-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Copy everything from builder to ensure config files (next.config.js) are present
# This sacrifices some image size optimization for robustness across different Next.js projects
COPY --from=builder /app ./

EXPOSE 3000

CMD ["npm", "start"]