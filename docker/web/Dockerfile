# Stage 1: Runtime
FROM node:18-alpine

WORKDIR /app

# Copy the entire application code (including node_modules from the Jenkins build)
COPY app/ .

# Expose the default Next.js/React port
EXPOSE 3000

# Start the application
# We use 'npm start' which is standard for production servers
CMD ["npm", "start"]