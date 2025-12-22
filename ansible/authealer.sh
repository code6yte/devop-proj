#!/bin/sh
set -eu

LOG=/var/log/authealer.log
mkdir -p /var/log

echo "[authealer] starting, listening for container destroy events" | tee -a "$LOG"

# Use docker events to watch for container removal or destroy events
# When an event occurs, trigger Jenkins healing job

docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' | while read -r ev; do
  echo "[authealer] event: $ev" | tee -a "$LOG"
  echo "[authealer] triggering Jenkins healing job" | tee -a "$LOG"
  # Trigger Jenkins job; ignore failures but log them
  if curl -X POST http://jenkins:8080/job/heal/build --user admin:$JENKINS_API_TOKEN >> "$LOG" 2>&1; then
    echo "[authealer] Jenkins job triggered successfully" | tee -a "$LOG"
  else
    echo "[authealer] Failed to trigger Jenkins job - see log" | tee -a "$LOG"
  fi
done
