# Use pre-built base image with Docker CLI, jq, and Compose already installed
FROM ansible-control:base

# Copy static config files
COPY ansible/ansible.cfg /ansible/ansible.cfg
COPY ansible/inventory /ansible/inventory

# Copy playbooks and scripts (only this layer rebuilds on playbook changes)
COPY ansible/authealer.sh /ansible/authealer.sh
COPY ansible/playbook.yml /ansible/playbook.yml
COPY ansible/inner_heal.yml /ansible/inner_heal.yml
RUN chmod +x /ansible/authealer.sh

# Run the authealer script as the main process
CMD ["/ansible/authealer.sh"]
