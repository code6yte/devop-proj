#!/bin/sh
set -eu

LOG=/var/log/authealer.log
mkdir -p /var/log

echo "[authealer] starting, listening for container destroy events" | tee -a "$LOG"

# Send Startup Notification
if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
  curl -H "Content-Type: application/json" \
       -d '{"content": "🟢 **Self-Healing Node Online**\nMonitoring started for project `s`."}' \
       "$DISCORD_WEBHOOK_URL" || true
fi

# Use docker events to watch for container removal or destroy events
# When an event occurs, trigger Jenkins healing job

docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' | while read -r ev; do
  echo "[authealer] event: $ev" | tee -a "$LOG"
  echo "[authealer] triggering Ansible healing locally" | tee -a "$LOG"

  # 1. Notify IMMEDIATE TRIGGER (Event Detected)
  if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
    curl -H "Content-Type: application/json" \
         -d '{"content": "🚨 **Healing Event Triggered!**\nDetected a container destruction event. Starting healing process..."}' \
         "$DISCORD_WEBHOOK_URL" || true
  fi
  
  # Trigger Ansible playbook directly (we are now INSIDE the ansible container)
  if ansible-playbook /ansible/playbook.yml 2>&1 | tee -a "$LOG"; then
    echo "[authealer] Ansible healing triggered successfully" | tee -a "$LOG"
    
    # 2. Notify POST-HEALING (Status Check after 1 minute)
    if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
      (
        sleep 60
        STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}")
        # Escape newlines for JSON
        STATUS_ESCAPED=$(echo "$STATUS" | awk '{printf "%s\\n", $0}')
        
        curl -H "Content-Type: application/json" \
             -d "{\"content\": \"✅ **Health Check (1 min later)**\ncurrent cluster status:\n\`\`\`\n$STATUS_ESCAPED\n\`\`\`\"}" \
             "$DISCORD_WEBHOOK_URL"
      ) &
    fi

  else
    echo "[authealer] Failed to trigger Ansible healing (exit code $?)" | tee -a "$LOG"
  fi
done
