#!/bin/bash
# Test script to debug self-healing

echo "=== Current Web Containers ==="
docker ps --filter "label=com.docker.compose.project=s" --filter "label=com.docker.compose.service=web"

echo -e "\n=== Checking backup image ==="
docker image inspect s-web-backup:latest > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Backup image exists"
else
    echo "❌ Backup image NOT found - run pipeline first!"
    exit 1
fi

echo -e "\n=== Rebuilding Ansible container with latest playbook ==="
docker compose build ansible --no-cache

echo -e "\n=== Starting Ansible container ==="
docker compose up -d ansible

echo -e "\n=== Waiting for Ansible to start ==="
sleep 3

echo -e "\n=== Testing playbook manually ==="
docker exec ansible ansible-playbook /ansible/playbook.yml -vv

echo -e "\n=== Final Web Container Count ==="
docker ps --filter "label=com.docker.compose.project=s" --filter "label=com.docker.compose.service=web"

echo -e "\n=== Ansible Logs ==="
docker logs ansible --tail 50
