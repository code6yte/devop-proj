#!/bin/sh
set -eu

LOG=/var/log/authealer.log
mkdir -p /var/log

echo "[authealer] starting, listening for container destroy events" | tee -a "$LOG"

# Send Startup Notification using jq for safety
if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
  # Get Web Container Status
  WEB_STATUS=$(docker ps --filter "name=s-web" --format "table {{.Names}}\t{{.Status}}")
  
  # Build JSON with jq to ensure proper escaping of newlines and values
  PAYLOAD=$(jq -n \
            --arg title "🟢 Self-Healing Node Online" \
            --arg desc "The auto-healing monitor has started successfully." \
            --arg color "5763719" \
            --arg f_name "Managed Web Containers" \
            --arg f_val "$WEB_STATUS" \
            --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')

  curl -H "Content-Type: application/json" \
       -d "$PAYLOAD" \
       "$DISCORD_WEBHOOK_URL" || true
fi

# Use docker events to watch for container removal or destroy events
docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' | while read -r ev; do
  echo "[authealer] event: $ev" | tee -a "$LOG"
  echo "[authealer] triggering Ansible healing locally" | tee -a "$LOG"

  # 1. Notify IMMEDIATE TRIGGER (Event Detected)
  if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
    # Fixed timestamp quoting
    curl -H "Content-Type: application/json" \
         -d '{
          "embeds": [{
            "title": "🚨 Healing Event Triggered",
            "description": "Detected a container destruction event. Initiating Ansible healing sequence...",
            "color": 15548997,
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
          }]
         }' \
         "$DISCORD_WEBHOOK_URL" || true
  fi
  
  # Trigger Ansible playbook directly
  if ansible-playbook /ansible/playbook.yml 2>&1 | tee -a "$LOG"; then
    echo "[authealer] Ansible healing triggered successfully" | tee -a "$LOG"
    
    # 2. Notify POST-HEALING (Status Check after 1 minute)
    if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
      (
        echo "[authealer] Waiting 60s for post-healing check..." >> "$LOG"
        sleep 60
        echo "[authealer] Running post-healing check..." >> "$LOG"
        
        STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}")
        # Build JSON with jq for the post-healing check as well to be safe
        PAYLOAD=$(jq -n \
                  --arg title "✅ Post-Healing Health Check" \
                  --arg desc "Current cluster status after 60s stabilization:" \
                  --arg color "3066993" \
                  --arg f_name "Container Statuses" \
                  --arg f_val "$STATUS" \
                  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                  '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')
        
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL")
        echo "[authealer] Post-healing notification sent. HTTP Code: $RESPONSE" >> "$LOG"
      ) &
    fi

  else
    echo "[authealer] Failed to trigger Ansible healing (exit code $?)" | tee -a "$LOG"
  fi
done