# Simple Nginx Image
FROM nginx:alpine

# Copy the pre-built 'html' folder from the build context
# Jenkins will ensure this folder exists and contains the built site
COPY html /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
