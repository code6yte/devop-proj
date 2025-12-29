# 🚑 Self-Healing DevOps Infrastructure with Jenkins & Ansible

A robust, automated infrastructure project that deploys Node.js applications (React/Next.js) using Jenkins, orchestrates them with Docker Compose, and maintains high availability through an Ansible-based self-healing sidecar.

## 🌟 Key Features

*   **Autonomous Self-Healing:** An `ansible` container monitors the Docker socket for `destroy` events and immediately restores the cluster to its desired state (defined by replicas).
*   **Dynamic CI/CD:** A Jenkins pipeline capable of cloning, building, and deploying *any* provided Git repository (React/Next.js) via build parameters.
*   **Advanced Image Building:** Uses multi-stage Docker builds with BuildKit caching (`--mount=type=cache`) to drastically reduce dependency installation times.
*   **Infrastructure as Code:** Entire environment, including networking and recovery logic, is version-controlled.
*   **Real-time Observability:** Integrated Discord notifications for deployment status, healing triggers, and post-recovery health checks using rich embeds.

---

## 🏗️ System Architecture

1.  **Jenkins:** The orchestrator. It handles the lifecycle of the application—from fetching source code to building production-ready images and managing the Docker Compose deployment.
2.  **Web Cluster (N Replicas):** Multiple containers running the Node.js application. Port range `8090-8092` is mapped to internal port `3000`.
3.  **Ansible Watchdog:** A specialized sidecar running `authealer.sh` that:
    *   Streams Docker events looking for container destruction.
    *   Triggers an Ansible Playbook locally to enforce state.
    *   Uses `jq` for reliable JSON payload generation for alerts.
4.  **Backup Service:** A dedicated container for data persistence and volume management, ensuring `web-v` data remains available.

---

## 🚀 Getting Started

### Prerequisites
*   Docker & Docker Compose (V2)
*   Jenkins (with access to `/var/run/docker.sock`)
*   Discord Webhook URL for alerts

### 1. Environment Configuration
Create a `.env` file in the root directory:
```ini
COMPOSE_PROJECT_NAME=s
DISCORD_WEBHOOK_URL=your_webhook_url_here
REPLICAS=3
```

### 2. Jenkins Pipeline Setup
Create a **Pipeline** job and point it to the repository's `Jenkinsfile`.

**Build Parameters:**
| Parameter | Default | Description |
| :--- | :--- | :--- |
| `REPO_URL` | `https://github.com/code6yte/Airbnb` | The Next.js/React repo to deploy. |
| `REPLICAS` | `3` | Number of web containers to maintain. |
| `DISCORD_WEBHOOK_URL` | `...` | Target for system notifications. |

---

## 🛠️ Deep Dive: How It Works

### The Deployment Flow
1.  **Artifact Preparation:** Jenkins clones the `REPO_URL` into `docker/web/app`.
2.  **Optimized Build:** The `web` Dockerfile uses a multi-stage process. The builder stage leverages `npm install` caching to skip redundant downloads if `package.json` hasn't changed.
3.  **State Enforcement:** Jenkins runs `docker compose up -d --scale web=${REPLICAS}`, ensuring the specific number of containers are running.

### The Self-Healing Logic
1.  **Monitoring:** `authealer.sh` runs `docker events --filter 'event=destroy'`.
2.  **Reaction:** Upon a container exit/removal, it triggers `ansible-playbook /ansible/playbook.yml`.
3.  **Healing Task:**
    *   Ansible executes `docker compose up -d --scale web=N --no-recreate`.
    *   `--no-recreate` ensures that only the missing container is started, preventing downtime for healthy nodes.
4.  **Verification:** Ansible waits for the application to respond on Port 3000 inside the container before reporting success.

---

## 📂 Project Structure

```text
.
├── ansible/
│   ├── authealer.sh      # Event listener & logic trigger
│   ├── playbook.yml      # Ansible logic for state enforcement
│   └── inventory         # Local inventory for Ansible
├── docker/
│   ├── ansible/          # Dockerfile with Ansible + Docker CLI + jq
│   ├── web/              # Multi-stage Node.js Dockerfile
│   └── backup/           # Storage/Backup service definition
├── docker-compose.yml    # Service orchestration
└── Jenkinsfile           # Dynamic CI/CD pipeline
```

---

## 🔔 Notification Matrix

| Event | Color | Channel | Description |
| :--- | :--- | :--- | :--- |
| **System Online** | 🟢 Green | Discord | Sent when the Ansible sidecar starts. |
| **Deployment Success** | 🔵 Blue | Jenkins | Sent when a new build is successfully deployed. |
| **Healing Triggered** | 🔴 Red | Discord | Immediate alert when a container is destroyed. |
| **Healing Action** | 🟢 Green | Discord | Confirmation that Ansible has recreated the container. |
| **Health Warning** | 🟠 Orange | Discord | Alert if a container fails HTTP health checks after recovery. |

---

## 📜 License
This project is open-source. Feel free to modify and expand!