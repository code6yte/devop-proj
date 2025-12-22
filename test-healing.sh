#!/bin/bash
# Test self-healing by deleting files

echo "=== Testing Self-Healing Mechanism ==="
echo ""
echo "Step 1: Checking current website status..."
curl -s http://localhost:8080 | head -n 5
echo ""

echo "Step 2: Deleting index.html from web container..."
docker exec web-server rm -f /usr/share/nginx/html/index.html
echo "File deleted!"
echo ""

echo "Step 3: Verifying website is broken..."
sleep 1
curl -s http://localhost:8080 || echo "Website is down (expected)"
echo ""

echo "Step 4: Running self-healing playbook..."
docker exec ansible-control ansible-playbook /ansible/playbook.yml
echo ""

echo "Step 5: Verifying website is restored..."
sleep 2
curl -s http://localhost:8080 | head -n 5
echo ""
echo "=== Self-Healing Test Complete ==="
