FROM nginx:alpine

# Create initial website content
RUN echo '<html><head><title>Self-Healing Web Server</title></head><body><h1>Self-Healing Web Server</h1><p>This server is managed by Ansible and will auto-heal if files are deleted.</p><p>Timestamp: '$(date)'</p></body></html>' > /usr/share/nginx/html/index.html

# Expose port 80 (mapped to 8080 via docker compose)
EXPOSE 80
