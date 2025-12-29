#!/bin/sh
set -eu

LOG=/var/log/authealer.log
# Lock file location INSIDE this container
LOCK_FILE="/tmp/healing.lock"
mkdir -p /var/log

echo "[authealer] starting, listening for container destroy events" | tee -a "$LOG"

# Initial Startup Notification
if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
  WEB_STATUS=$(docker ps --filter "name=s-web" --format "table {{.Names}}\t{{.Status}}")
  PAYLOAD=$(jq -n \
            --arg title "🟢 Self-Healing Node Online" \
            --arg desc "The auto-healing monitor has started successfully."
            --arg color "5763719"
            --arg f_name "Managed Web Containers"
            --arg f_val "$WEB_STATUS" \
            --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')

  curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null || true
fi

# Track the PID of the pending health check to allow debouncing
CHECK_PID=""

docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' | while read -r ev; do
  # 1. Check if a deployment is in progress (Check local container filesystem)
  if [ -f "$LOCK_FILE" ]; then
    echo "[authealer] Deployment in progress (internal lock detected). Skipping event: $ev" >> "$LOG"
    continue
  fi

  echo "[authealer] event detected: $ev" | tee -a "$LOG"

  # 2. Immediate Alert (Only once per burst)
  if [ -z "$CHECK_PID" ] || ! kill -0 "$CHECK_PID" 2>/dev/null; then
    if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
      curl -s -H "Content-Type: application/json" \
           -d "{\"embeds\": [{\"title\": \"🚨 Healing Event Triggered\", \"description\": \"Container destruction detected. Ansible is enforcing state...\", \"color\": 15548997}]}" \
           "$DISCORD_WEBHOOK_URL" > /dev/null || true
    fi
  fi

  # 3. Execute Ansible
  ansible-playbook /ansible/playbook.yml >> "$LOG" 2>&1 || echo "[authealer] Ansible failed" >> "$LOG"

  # 4. Consolidated Health Check (Wait 60s after the LAST event)
  if [ ! -z "$CHECK_PID" ] && kill -0 "$CHECK_PID" 2>/dev/null; then
    kill "$CHECK_PID" 2>/dev/null || true
  fi

  (
    sleep 60
    # Final check: Don't notify if we are in the middle of a new deployment that started AFTER the heal
    if [ -f "$LOCK_FILE" ]; then exit 0; fi

    echo "[authealer] Running consolidated post-healing check..." >> "$LOG"
    STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}")
    PAYLOAD=$(jq -n \
              --arg title "✅ Post-Healing Health Check" \
              --arg desc "Cluster stabilized. Current status:"
              --arg color "3066993"
              --arg f_name "Container Statuses"
              --arg f_val "$STATUS" \
              --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')
    
    curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null || true
  ) &
  CHECK_PID=$!
done