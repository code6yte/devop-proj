#!/bin/sh
set -eu

LOG=/var/log/authealer.log
# Note: LOCK_FILE is no longer actively checked here, as Jenkins will stop/start this script directly.
mkdir -p /var/log

echo "[authealer] starting..." | tee -a "$LOG"

# Wait for web containers to be healthy before reporting "Online"
(
  REPLICAS="${TARGET_REPLICAS:-3}" # Get target replicas from env, default to 3
  echo "[authealer] Waiting for ${REPLICAS} web containers to be healthy..." >> "$LOG"
  
  ATTEMPTS=0
  MAX_ATTEMPTS=60 # Wait up to 10 minutes (60 * 10s)
  while [ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ]; do
    HEALTHY_COUNT=$(docker ps --filter "name=s-web" --filter "status=running" --format "{{.ID}}" | wc -l)
    
    if [ "$HEALTHY_COUNT" -ge "$REPLICAS" ]; then
      echo "[authealer] Detected ${HEALTHY_COUNT}/${REPLICAS} healthy web containers. Sending startup notification." >> "$LOG"
      if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
        WEB_STATUS=$(docker ps --filter "name=s-web" --format "table {{.Names}}	{{.Status}}")
        PAYLOAD=$(jq -n \
                  --arg title "🟢 Self-Healing Node Online" \
                  --arg desc "The auto-healing monitor is now guarding the cluster." \
                  --arg color "5763719" \
                  --arg f_name "Active Web Containers" \
                  --arg f_val "$WEB_STATUS" \
                  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                  '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')

        curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null || true
      fi
      break # Success, exit loop
    fi
    echo "[authealer] Only ${HEALTHY_COUNT}/${REPLICAS} healthy web containers found. Retrying in 10s..." >> "$LOG"
    sleep 10
    ATTEMPTS=$((ATTEMPTS+1))
  done
  
  if [ "$ATTEMPTS" -eq "$MAX_ATTEMPTS" ]; then
      echo "[authealer] Timeout waiting for web containers to become healthy. Startup notification skipped." >> "$LOG"
  fi
) &

# Now start monitoring for unexpected events
docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' | while read -r ev; do
  echo "[authealer] unexpected destroy event detected: $ev" | tee -a "$LOG"

  # Immediate Alert
  if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
    curl -s -H "Content-Type: application/json" \
         -d "{\"embeds\": [{\"title\": \"🚨 Healing Event Triggered\", \"description\": \"Unexpected container destruction. Restoring state...\", \"color\": 15548997}]}" \
         "$DISCORD_WEBHOOK_URL" > /dev/null || true
  fi

  # Execute Restoration
  PLAYBOOK="${PLAYBOOK_FILE:-/ansible/playbook.yml}"
  ansible-playbook "$PLAYBOOK" >> "$LOG" 2>&1 || echo "[authealer] Ansible failed" >> "$LOG"

  # Post-Healing Health Check
  (
    sleep 60
    echo "[authealer] Cluster stabilized. Sending report..." >> "$LOG"
    STATUS=$(docker ps --filter "name=s-web" --format "table {{.Names}}	{{.Status}}")
    PAYLOAD=$(jq -n \
              --arg title "✅ Post-Healing Health Check" \
              --arg desc "Recovery complete. Current status:"
              --arg color "3066993" \
              --arg f_name "Container Statuses" \
              --arg f_val "$STATUS" \
              --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')
    
    curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null || true
  ) &
done