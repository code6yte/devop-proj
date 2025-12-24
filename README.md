# 🚑 Self-Healing DevOps Infrastructure with Jenkins & Ansible

A robust, automated infrastructure project that deploys Node.js applications (React/Next.js) using Jenkins, orchestrates them with Docker Compose, and maintains high availability through an Ansible-based self-healing sidecar.

## 🌟 Key Features

*   **Self-Healing Architecture:** An autonomous `ansible` container watches for Docker `destroy` events and immediately restores missing containers to the desired state.
*   **Dynamic CI/CD:** A Jenkins pipeline that can clone, build, and deploy *any* provided Git repository (React/Next.js) dynamically.
*   **Scalability:** Scale the number of web replicas directly via Jenkins parameters.
*   **Rich Notifications:** Real-time, color-coded Discord alerts for system startup, healing events, and health checks.
*   **Robust Networking:** Uses host networking during build phases to eliminate Docker-in-Docker DNS/connectivity issues.

---

## 🏗️ System Architecture

1.  **Jenkins:** Orchestrates the pipeline. It clones source code, spins up ephemeral build containers, creates artifacts, and updates the Docker deployment.
2.  **Web Cluster:** Multiple replicas (`s-web-1`, `s-web-2`, ...) running the Node.js application.
3.  **Ansible Watchdog:** A specialized container running `authealer.sh` that:
    *   Listens to the Docker socket for event streams.
    *   Triggers an Ansible Playbook upon container destruction.
    *   Performs Health Checks (HTTP requests to Port 3000).
4.  **Discord Integration:** Sends rich embed notifications for visibility.

---

## 🚀 Getting Started

### Prerequisites
*   Docker & Docker Compose (V2) installed on the host.
*   Jenkins running as a Docker container (with access to the host Docker socket).
*   A Discord Webhook URL.

### 1. Environment Setup
Create a `.env` file in the project root:
```ini
COMPOSE_PROJECT_NAME=s
# Optional: Default Webhook (can be overridden in Jenkins)
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

### 2. Jenkins Configuration
Create a **Pipeline** job in Jenkins and point it to this repository (`Jenkinsfile`).

**Build Parameters:**
| Parameter | Default | Description |
| :--- | :--- | :--- |
| `DISCORD_WEBHOOK_URL` | *(Empty)* | The webhook URL for notifications. |
| `REPLICAS` | `3` | Number of web containers to maintain. |
| `REPO_URL` | `...` | Git URL of the Node.js/Next.js app to build. |

---

## 🛠️ How It Works

### The Deployment Pipeline
1.  **Clone:** Jenkins fetches the source code from `REPO_URL`.
2.  **Build Artifacts:**
    *   Spins up a temporary `node:18-alpine` container.
    *   Uses `docker cp` to inject source code (bypassing Volume mounting issues).
    *   Runs `npm install` and `npm run build`.
    *   Extracts the built artifacts back to the host.
3.  **Bake Image:** Builds a production Docker image using the artifacts.
4.  **Deploy:** Runs `docker compose up -d` with the specified `REPLICAS`.

### The Self-Healing Process
1.  **Monitoring:** The `ansible` container runs `authealer.sh`.
2.  **Trigger:** When you run `docker rm -f s-web-1`, the script catches the `destroy` event.
3.  **Alert:** Sends a 🚨 **Healing Event Triggered** notification to Discord.
4.  **Action:** Ansible runs `docker compose up` to enforce the state (filling the gap).
5.  **Notification:** Sends a 🛠️ **Healing Action Taken** notification (e.g., `s-web-1 Created`).
6.  **Verification:** Waits 60s, then sends a ✅ **Post-Healing Health Check** with the cluster status.

---

## 📂 Project Structure

```text
/
├── ansible/
│   ├── ansible.cfg       # Ansible configuration
│   ├── authealer.sh      # Main watchdog script (Event Listener)
│   ├── inventory         # Localhost inventory
│   └── playbook.yml      # The logic for healing and health checks
├── docker/
│   ├── ansible/          # Dockerfile for the control node (with jq, curl, docker-cli)
│   ├── backup/           # Dockerfile for backup storage service
│   └── web/              # Dockerfile for the Node.js application
├── docker-compose.yml    # Service definitions (web, ansible, backup)
└── Jenkinsfile           # CI/CD Pipeline definition
```

---

## 🔔 Notification Types

| Type | Color | Description |
| :--- | :--- | :--- |
| **System Online** | 🟢 Green | Sent when the Ansible container starts up. Lists managed containers. |
| **Healing Triggered** | 🔴 Red | Sent immediately when a container is deleted. |
| **Healing Action** | 🟢 Green | Sent when Ansible recreates a container. Shows "Name Created/Started". |
| **Health Check** | 🟢 Green | Sent 60s after healing to confirm cluster stability. |
| **Health Warning** | 🟠 Orange | Sent if a container fails to respond on Port 3000 after 60s. |

---

## 🔧 Troubleshooting

*   **Build fails on network:** The pipeline uses `--network host` during the build phase to resolve DNS issues inside Docker containers.
*   **No Notification:** Ensure `DISCORD_WEBHOOK_URL` is correct. Check `docker logs ansible` to see the `curl` response codes.
*   **"Connection Refused" in logs:** The application might be taking longer than 60s to start. Adjust the sleep timer in `ansible/playbook.yml`.

---

## 📜 License
This project is open-source. Feel free to modify and expand!
