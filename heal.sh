#!/bin/bash
# Self-healing script to run Ansible playbook

echo "Running self-healing playbook..."
docker exec ansible-control ansible-playbook /ansible/playbook.yml
