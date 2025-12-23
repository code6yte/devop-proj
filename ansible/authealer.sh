#!/bin/sh
set -eu

LOG=/var/log/authealer.log
mkdir -p /var/log

echo "[authealer] starting, listening for container destroy events" | tee -a "$LOG"

# Use docker events to watch for container removal or destroy events
# When an event occurs, trigger Jenkins healing job

docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' | while read -r ev; do
  echo "[authealer] event: $ev" | tee -a "$LOG"
  echo "[authealer] triggering Ansible healing locally" | tee -a "$LOG"
  
  # Trigger Ansible playbook directly in the ansible-control container
  # We use tee to show output in docker logs AND save to file
  if docker exec ansible-control ansible-playbook /ansible/playbook.yml 2>&1 | tee -a "$LOG"; then
    echo "[authealer] Ansible healing triggered successfully" | tee -a "$LOG"
  else
    echo "[authealer] Failed to trigger Ansible healing (exit code $?)" | tee -a "$LOG"
  fi
done
