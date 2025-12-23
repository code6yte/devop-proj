# Stage 1: Builder
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files first for caching
COPY app/package*.json ./

# Install dependencies (ignoring scripts to speed up/avoid issues)
RUN npm install --legacy-peer-deps

# Copy the rest of the application code
COPY app/ .

# Build the application
# We try standard build commands. If 'build' fails, we try 'export' (common for Next.js static)
RUN npm run build || npm run export

# Detect output directory and move to /output
# React uses 'build', Vite uses 'dist', Next.js static export uses 'out'
RUN mkdir /output && \
    if [ -d "build" ]; then cp -r build/* /output/; \
    elif [ -d "dist" ]; then cp -r dist/* /output/; \
    elif [ -d "out" ]; then cp -r out/* /output/; \
    else echo "Error: No build output folder (build, dist, out) found!" && exit 1; \
    fi

# Stage 2: Production Server
FROM nginx:alpine

# Copy build artifacts from builder stage
COPY --from=builder /output /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]