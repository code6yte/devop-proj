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
  # Extract container name and check if it's a web container
  CONTAINER_NAME=$(echo "$ev" | jq -r '.Actor.Attributes.name // empty')
  
  # Only heal if it's a web container from our compose project
  if echo "$CONTAINER_NAME" | grep -q "^s-web"; then
    echo "[authealer] Web container destroyed: $CONTAINER_NAME" | tee -a "$LOG"
    
    # Check current count vs desired
    CURRENT_COUNT=$(docker ps --filter "label=com.docker.compose.project=s" --filter "label=com.docker.compose.service=web" --format "{{.ID}}" | wc -l)
    DESIRED_COUNT="${TARGET_REPLICAS:-3}"
    
    if [ "$CURRENT_COUNT" -lt "$DESIRED_COUNT" ]; then
      echo "[authealer] Healing needed: $CURRENT_COUNT/$DESIRED_COUNT containers" | tee -a "$LOG"
      
      # Check if backup image exists
      if ! docker image inspect s-web-backup:latest > /dev/null 2>&1; then
        echo "[authealer] ERROR: Backup image s-web-backup:latest not found! Cannot restore containers." | tee -a "$LOG"
        if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
          curl -s -H "Content-Type: application/json" \
               -d "{\"embeds\": [{\"title\": \"❌ Healing Failed\", \"description\": \"Backup image not found. Run pipeline to create backup image.\", \"color\": 15548997}]}" \
               "$DISCORD_WEBHOOK_URL" > /dev/null || true
        fi
        continue
      fi
      
      # Immediate Alert
      if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
        curl -s -H "Content-Type: application/json" \
             -d "{\"embeds\": [{\"title\": \"🚨 Healing Event Triggered\", \"description\": \"Container $CONTAINER_NAME destroyed. Restoring state ($CURRENT_COUNT/$DESIRED_COUNT)...\", \"color\": 15548997}]}" \
             "$DISCORD_WEBHOOK_URL" > /dev/null || true
      fi

      # Execute Restoration
      echo "[authealer] Running ansible playbook to restore containers..." | tee -a "$LOG"
      echo "[authealer] Playbook output:" | tee -a "$LOG"
      
      ansible-playbook /ansible/playbook.yml -vv 2>&1 | tee -a "$LOG"
      ANSIBLE_EXIT_CODE=${PIPESTATUS[0]}
      
      if [ $ANSIBLE_EXIT_CODE -ne 0 ]; then
        echo "[authealer] ERROR: Ansible playbook failed with exit code $ANSIBLE_EXIT_CODE" | tee -a "$LOG"
      else
        echo "[authealer] Ansible playbook completed successfully (exit code: $ANSIBLE_EXIT_CODE)" | tee -a "$LOG"
      fi

      # Post-Healing Health Check
      (
        sleep 10
        echo "[authealer] Cluster stabilized. Sending report..." >> "$LOG"
        FINAL_COUNT=$(docker ps --filter "label=com.docker.compose.project=s" --filter "label=com.docker.compose.service=web" --format "table {{.Names}}\t{{.Status}}")
        PAYLOAD=$(jq -n \
                  --arg title "✅ Post-Healing Health Check" \
                  --arg desc "Recovery complete. Cluster state restored." \
                  --arg color "3066993" \
                  --arg f_name "Container Statuses" \
                  --arg f_val "$FINAL_COUNT" \
                  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                  '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')
        
        curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null || true
      ) &
      
      # Cooldown to prevent rapid re-triggering
      sleep 5
    else
      echo "[authealer] Cluster healthy: $CURRENT_COUNT/$DESIRED_COUNT containers. No action needed." >> "$LOG"
    fi
  fi
done