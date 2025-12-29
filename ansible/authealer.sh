#!/bin/sh
set -eu

LOG=/var/log/authealer.log
LOCK_FILE="/tmp/healing.lock"
TIMER_FILE="/tmp/healing_timer"
mkdir -p /var/log

echo "[authealer] starting, listening for container destroy events" | tee -a "$LOG"

# Initial Startup Notification
if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
  WEB_STATUS=$(docker ps --filter "name=s-web" --format "table {{.Names}}\t{{.Status}}")
  PAYLOAD=$(jq -n \
            --arg title "🟢 Self-Healing Node Online" \
            --arg desc "The auto-healing monitor has started successfully."
            --arg color "5763719" \
            --arg f_name "Managed Web Containers" \
            --arg f_val "$WEB_STATUS" \
            --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')

  curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null || true
fi

# Clean up any stale timer file on start
rm -f "$TIMER_FILE"

docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' | while read -r ev; do
  # 1. Skip if deployment lock is active
  if [ -f "$LOCK_FILE" ]; then
    echo "[authealer] Deployment active. Ignoring event." >> "$LOG"
    continue
  fi

  echo "[authealer] event detected: $ev" | tee -a "$LOG"

  # 2. Immediate Alert (Only if no timer is currently active)
  if [ ! -f "$TIMER_FILE" ]; then
    touch "$TIMER_FILE"
    if [ ! -z "$DISCORD_WEBHOOK_URL" ]; then
      curl -s -H "Content-Type: application/json" \
           -d "{\"embeds\": [{\"title\": \"🚨 Healing Event Triggered\", \"description\": \"Cluster instability detected. Ansible is restoring state...\", \"color\": 15548997}]}" \
           "$DISCORD_WEBHOOK_URL" > /dev/null || true
    fi
  fi

  # 3. Execute Ansible
  ansible-playbook /ansible/playbook.yml >> "$LOG" 2>&1 || echo "[authealer] Ansible failed" >> "$LOG"

  # 4. Debounced Health Check (One final report 60s after the LAST destroy event)
  # We kill any existing 'sleep' process associated with this script to reset the timer
  pkill -f "sleep 60 --healing-check" || true
  
  (
    # The unique string allows pkill to find ONLY this timer
    sleep 60 --healing-check
    
    # Final check: Don't notify if a deployment started during our sleep
    if [ -f "$LOCK_FILE" ]; then 
      rm -f "$TIMER_FILE"
      exit 0
    fi

    echo "[authealer] Sending consolidated health report..." >> "$LOG"
    STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}")
    PAYLOAD=$(jq -n \
              --arg title "✅ Post-Healing Health Check" \
              --arg desc "Cluster stabilized. Status of all managed containers:"
              --arg color "3066993" \
              --arg f_name "Container Statuses" \
              --arg f_val "$STATUS" \
              --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '{embeds: [{title: $title, description: $desc, color: ($color|tonumber), fields: [{name: $f_name, value: ("```\n" + $f_val + "\n```")}], timestamp: $ts}]}')
    
    curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$DISCORD_WEBHOOK_URL" > /dev/null || true
    
    # Remove the timer file so the next burst can trigger a fresh alert
    rm -f "$TIMER_FILE"
  ) &
done
