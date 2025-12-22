#!/bin/bash
# Healing script to be run by Jenkins

echo "Starting self-healing process..."

# Run the Ansible playbook
docker exec ansible-control ansible-playbook /ansible/playbook.yml

echo "Self-healing completed."