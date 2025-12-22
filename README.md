# Self-Healing Web Server with Docker, Ansible, and Jenkins

## Project Structure
```
.
├── docker-compose.yml          # Main orchestration file with Jenkins
├── Jenkinsfile                 # Jenkins pipeline for build/deploy
├── Jenkinsfile.heal            # Jenkins pipeline for healing
├── jenkins-heal.sh             # Healing script for Jenkins
├── ansible/
│   ├── inventory              # Ansible inventory (local execution)
│   ├── playbook.yml           # Self-healing playbook
│   └── ansible.cfg            # Ansible configuration
├── docker/
│   ├── ansible/
│   │   └── Dockerfile         # Ansible control node with Docker CLI
│   ├── web/
│   │   └── Dockerfile         # NGINX web server
│   └── backup/
│       └── Dockerfile         # Backup container
├── heal.sh                    # Quick healing script
└── test-healing.sh            # Test self-healing mechanism
```

## Quick Start Commands

### 1. Build and Start All Containers (including Jenkins)
```bash
docker compose build
docker compose up -d
```

### 2. Access Jenkins
- Open http://localhost:8081
- Get initial admin password: `docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
- Install suggested plugins
- **Alternative: Use the automated setup script:**
  ```bash
  chmod +x setup-jenkins-jobs.sh
  ./setup-jenkins-jobs.sh
  ```

### 3. Create Jenkins Jobs (Manual Method)
If not using the script, create jobs manually:

**DevOp Job (Build & Deploy):**
- New Item → Pipeline
- Name: `devop`
- Pipeline: Pipeline script from SCM
- SCM: Git, Repository URL: `.` (current directory)
- Script Path: `Jenkinsfile`

**Heal Job (Self-Healing):**
- New Item → Pipeline
- Name: `heal`
- Pipeline: Pipeline script from SCM
- SCM: Git, Repository URL: `.`
- Script Path: `Jenkinsfile.heal`

### 4. Run Build Pipeline in Jenkins
- Trigger the "devop" job to build images and deploy

### 4. Verify All Containers are Running
```bash
docker compose ps
```

### 5. Check Website
```bash
curl http://localhost:8080
# Or open in browser: http://localhost:8080
```

### 6. Run Self-Healing Manually (via Jenkins)
- Trigger the "heal" job in Jenkins
# Or directly:
docker exec ansible-control ansible-playbook /ansible/playbook.yml

### 5. Test Self-Healing (Full Test)
```bash
chmod +x test-healing.sh
./test-healing.sh
```

## Manual Testing Steps

### Test 1: Delete Website Files
```bash
# Delete index.html
docker exec web-server rm -f /usr/share/nginx/html/index.html

# Verify site is broken
curl http://localhost:8080

# Run healing
docker exec ansible-control ansible-playbook /ansible/playbook.yml

# Verify site is restored
curl http://localhost:8080
```

### Test 2: Check Backups
```bash
# View backup container contents
docker exec backup-server ls -lah /backup/web/
docker exec backup-server ls -lah /backup/storage/
```

### Test 3: Interactive Ansible Shell
```bash
# Enter Ansible container
docker exec -it ansible-control bash

# Inside container, run:
ansible-playbook /ansible/playbook.yml
ansible localhost -m ping
```

## Monitoring and Logs

### View Container Logs
```bash
docker compose logs web
docker compose logs ansible
docker compose logs backup
docker compose logs jenkins
```

### Follow Logs in Real-Time
```bash
docker compose logs -f
```

### Check NGINX Status
```bash
docker exec web-server nginx -t
docker exec web-server ps aux
```

## Automated Healing (via Jenkins)

The authealer service monitors Docker events and triggers the Jenkins "heal" job when containers are destroyed. The healing is now controlled through Jenkins pipelines.

To set up:
1. In Jenkins, create API token for admin user
2. Set the token as environment variable in authealer service (or hardcode for local)
3. The authealer will trigger the healing job automatically on container destroy events

## Cleanup

### Stop All Containers
```bash
docker compose down
```

### Remove Everything (including volumes)
```bash
docker compose down -v
```

### Rebuild from Scratch
```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

## Troubleshooting

### Container Won't Start
```bash
docker compose logs <container-name>
docker compose ps
```

### Port 8080 Already in Use
```bash
# Check what's using port 8080
sudo lsof -i :8080
# Or change port in docker-compose.yml
```

### Ansible Playbook Fails
```bash
# Check Ansible container has Docker CLI
docker exec ansible-control docker ps

# Run playbook with verbose output
docker exec ansible-control ansible-playbook /ansible/playbook.yml -vvv

# Or trigger via Jenkins heal job
```

### Jenkins Issues
```bash
# Check Jenkins logs
docker compose logs jenkins

# Access Jenkins UI at http://localhost:8081
# Ensure Docker socket permissions are correct
ls -l /var/run/docker.sock
```

### Permission Issues
```bash
# Ensure docker.sock has correct permissions
ls -l /var/run/docker.sock
# Add current user to docker group if needed
sudo usermod -aG docker $USER
```
