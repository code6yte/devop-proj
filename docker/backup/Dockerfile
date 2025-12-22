FROM alpine

# Install rsync and bash for backup operations
RUN apk add --no-cache rsync bash tar

# Create backup directory
RUN mkdir -p /backup/web

# Keep container running
CMD ["sleep", "infinity"]
