#!/bin/sh
set -eu

LOG=/var/log/authealer.log
# Lock file location on the shared volume
LOCK_FILE="/project/.healing_lock"
# Persistent PID tracker for the debouncer
DEBOUNCE_PID_FILE="/tmp/authealer_timer.pid"
mkdir -p /var/log

echo "[authealer] starting, listening for container destroy events" | tee -a "$LOG"

# Delayed Startup Notification (60s after boot)
(
  sleep 60
  if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
    WEB_STATUS=$(docker ps --filter "name=s-web" --format "table {{.Names}}\t{{.Status}}")
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
) &

docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' | while read -r ev; do
  # 1. Skip if deployment lock is active (Jenkins is updating)
  if [ -f "$LOCK_FILE" ]; then
    echo "[authealer] Deployment in progress. Ignoring event." >> "$LOG"
    continue
  fi

  echo "[authealer] event detected: $ev" | tee -a "$LOG"

  # 2. Kill any existing timer process to prevent multiple notifications
  if [ -f "$DEBOUNCE_PID_FILE" ]; then
    OLD_PID=$(cat "$DEBOUNCE_PID_FILE")
    kill "$OLD_PID" 2>/dev/null || true
    rm -f "$DEBOUNCE_PID_FILE"
  fi

  # 3. Immediate Alert (Only if this is the first event in a burst)
  # (Check if Ansible is already running via a simple lock file or similar)
  if [ ! -f "/tmp/ansible_running" ]; then
    touch "/tmp/ansible_running"
    if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
      curl -s -H "Content-Type: application/json" \
           -d "{\"embeds\": [{\"title\": \"🚨 Healing Event Triggered\", \"description\": \"Unexpected container destruction. Restoring state...\", \"color\": 15548997}]}" \
           "$DISCORD_WEBHOOK_URL" > /dev/null || true
    fi
  fi

  # 4. Execute Restoration
  ansible-playbook /ansible/playbook.yml >> "$LOG" 2>&1 || echo "[authealer] Ansible failed" >> "$LOG"
  rm -f "/tmp/ansible_running"

  # 5. Consolidated Health Check (Wait 60s after the LAST event)
  (
    sleep 60
    
    # Check lock again (safety)
    if [ -f "$LOCK_FILE" ]; then exit 0; fi

    echo "[authealer] Cluster stabilized. Sending report..." >> "$LOG"
    STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}")
    PAYLOAD=$(jq -n \
              --arg title "✅ Post-Healing Health Check" \
              --arg desc "Recovery complete. Current status:"
              --arg color "3066993" \
              --arg f_name "Container Statuses" \
              --arg f_val "$STATUS" \
              --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')
    
    curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null || true
    rm -f "$DEBOUNCE_PID_FILE"
  ) &
  echo $! > "$DEBOUNCE_PID_FILE"
done