<div align="center">

# 🚑 Self-Healing DevOps Infrastructure

### Jenkins · Docker · Ansible · Trivy · Discord

[![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-D24939?style=for-the-badge&logo=jenkins&logoColor=white)](https://www.jenkins.io/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Ansible](https://img.shields.io/badge/Ansible-Self--Healing-EE0000?style=for-the-badge&logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Trivy](https://img.shields.io/badge/Trivy-Security%20Scan-1904DA?style=for-the-badge&logo=aquasecurity&logoColor=white)](https://trivy.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-18--alpine-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org/)
[![Next.js](https://img.shields.io/badge/Next.js-App%20Target-000000?style=for-the-badge&logo=next.js&logoColor=white)](https://nextjs.org/)
[![Discord](https://img.shields.io/badge/Discord-Alerts-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.com/)

> **A production-grade, fully-automated infrastructure that deploys any Next.js / React application, guards it with a live Ansible watchdog, scans every image for CVEs, and streams rich observability events straight to Discord — all driven by a single Jenkins pipeline.**

</div>

---

## 📋 Table of Contents

- [✨ Highlights](#-highlights)
- [🏗️ Architecture](#️-architecture)
- [🔄 Pipeline Stages](#-pipeline-stages)
- [🩹 Self-Healing Engine](#-self-healing-engine)
- [🛡️ Security Scanning](#️-security-scanning)
- [🔔 Discord Observability](#-discord-observability)
- [📂 Project Structure](#-project-structure)
- [🚀 Getting Started](#-getting-started)
- [⚙️ Configuration Reference](#️-configuration-reference)
- [🧪 Testing Self-Healing](#-testing-self-healing)
- [📜 License](#-license)

---

## ✨ Highlights

| Feature | Detail |
| :--- | :--- |
| 🤖 **Autonomous Self-Healing** | Ansible sidecar streams Docker `destroy` events and instantly restores missing containers from a locked backup image — no human intervention needed |
| 🚀 **Dynamic CI/CD** | One Jenkins pipeline deploys *any* Git-hosted Next.js / React app by simply changing a build parameter |
| ⚡ **BuildKit Cache Mounts** | `--mount=type=cache` on `npm install` makes repeat builds near-instant by persisting `node_modules` across container lifecycles |
| 🛡️ **Integrated CVE Scanning** | Trivy scans every produced image for `CRITICAL` and `HIGH` vulnerabilities across OS packages, library dependencies, secrets, and misconfigurations |
| 📊 **Rich Discord Notifications** | Every pipeline event — start, lint result, security summary, deploy outcome, container destruction, and recovery confirmation — is pushed as a formatted Discord embed |
| 🏗️ **Infrastructure as Code** | Every service, playbook, Dockerfile, and pipeline stage is version-controlled; the entire environment is reproducible from a single `git clone` |
| 🔒 **Zero-Downtime Deployments** | The deploy stage stops only the Ansible sidecar before rolling out new containers, keeping the web cluster live throughout the update |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Jenkins Host                               │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     Jenkins Pipeline                         │  │
│  │  Clone Repo → Lint → Build Image → Trivy Scan → Deploy      │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                         │ docker compose up --scale web=N          │
└─────────────────────────┼───────────────────────────────────────────┘
                          │
          ┌───────────────▼────────────────────────┐
          │          Docker Network (bridge)        │
          │                                         │
          │  ┌──────────┐  ┌──────────┐  ┌───────┐ │
          │  │  s-web-1 │  │  s-web-2 │  │ s-web │ │  ← N replicas
          │  │ :3000    │  │ :3000    │  │ :3000 │ │    (ports 8090-8099)
          │  └────┬─────┘  └──────────┘  └───────┘ │
          │       │ destroy event                   │
          │  ┌────▼──────────────────────────────┐  │
          │  │       Ansible Watchdog (sidecar)   │  │
          │  │  authealer.sh                      │  │
          │  │  docker events ──► playbook.yml    │  │
          │  │  • restore from s-web-backup:latest│  │
          │  │  • notify Discord                  │  │
          │  └───────────────────────────────────┘  │
          │                                         │
          │  ┌──────────────────────────────────┐   │
          │  │   Trivy Scanner (persistent)     │   │
          │  │   scans s-web:<BUILD_NUMBER>     │   │
          │  └──────────────────────────────────┘   │
          └─────────────────────────────────────────┘
                          │
                 ┌────────▼──────────┐
                 │   Discord Webhook │
                 │  rich embed alerts│
                 └───────────────────┘
```

### Component Roles

| Component | Role |
| :--- | :--- |
| **Jenkins** | Orchestrates the full lifecycle: clone → lint → build → scan → deploy |
| **`s-web` (N replicas)** | Containerised Next.js app; ports `8090–8099` forwarded to internal `3000` |
| **Ansible Watchdog** | Streams Docker events; triggers `playbook.yml` on every container destruction |
| **`s-web-backup:latest`** | Immutable snapshot of the last good image — used exclusively by the watchdog to restore containers without re-building |
| **Trivy Scanner** | Long-lived container that scans images for CVEs, secrets, and config issues |

---

## 🔄 Pipeline Stages

```
┌───────────┐    ┌─────────────────┐    ┌──────────────────┐    ┌────────────────────┐    ┌──────────────────────┐
│Initialize │───►│ Checkout & Prep │───►│ Quality Check    │───►│ Security Scan      │───►│ Zero-Downtime Deploy │
│           │    │                 │    │ (Lint)           │    │ (Trivy)            │    │                      │
│• Trivy up │    │• checkout scm   │    │• docker build    │    │• build prod image  │    │• stop ansible        │
│• Discord  │    │• git clone app  │    │  --target builder│    │• trivy image scan  │    │• compose up --scale  │
│  start msg│    │  repo           │    │• npm run lint    │    │  CRITICAL,HIGH     │    │• tag backup image    │
└───────────┘    └─────────────────┘    │  (non-blocking)  │    │• generate .md      │    │• restart ansible     │
                                        └──────────────────┘    │  report on failure │    │• Discord result msg  │
                                                                 └────────────────────┘    └──────────────────────┘
```

### Stage Details

#### 1 · Initialize
- Verifies the persistent **Trivy scanner container** is running (creates it if not).
- Sends a **"Build Started"** embed to Discord with triggering user, job name, and target repository.

#### 2 · Checkout & Prep
- Checks out this infrastructure repo via `checkout scm`.
- Clones the application source (`REPO_URL`) into `docker/web/app` so the Dockerfile can access it.

#### 3 · Quality Check (Lint) — *non-blocking*
- Builds only the `builder` stage of the multi-stage Dockerfile to avoid a full image build.
- Runs `npm run lint` inside the builder container and captures output.
- A lint failure sets the status to `⚠️ Failed` but **does not abort the pipeline**, allowing deployments of apps with lint warnings.

#### 4 · Security Scan (Trivy)
- Builds the **full production image** (`s-web:<BUILD_NUMBER>`).
- Executes Trivy inside the persistent scanner container, scanning for:
  - OS-level and library vulnerabilities (`CRITICAL`, `HIGH`)
  - Embedded secrets
  - Dockerfile/config misconfigurations
- If vulnerabilities are found, a `security_report.md` is generated and sent as a Discord file attachment.

#### 5 · Zero-Downtime Deploy
1. Stops and removes only the **Ansible container** (prevents false-positive self-healing triggers during rollout).
2. Runs `docker compose up -d --scale web=<REPLICAS>` to roll out new containers.
3. Tags the new image as `s-web-backup:latest` — the watchdog's recovery source.
4. Rebuilds and restarts the **Ansible container** with the latest playbooks.

---

## 🩹 Self-Healing Engine

The self-healing system is entirely event-driven. It does not poll — it **reacts**.

### Detection (`authealer.sh`)

```sh
docker events --filter 'type=container' --filter 'event=destroy' --format '{{json .}}' \
  | while read -r ev; do
      # filter for containers matching "^s-web"
      # compare CURRENT_COUNT vs TARGET_REPLICAS
      # if deficit → ansible-playbook /ansible/playbook.yml
    done
```

The script:
1. Streams all container `destroy` events from the Docker daemon.
2. Filters for containers whose name starts with `s-web` (project-scoped).
3. Compares live container count against `$TARGET_REPLICAS`.
4. Only triggers a playbook run when a **deficit** actually exists (ignores planned teardowns).
5. Applies a **5-second cooldown** after healing to prevent cascade re-triggers.

### Restoration (`playbook.yml`)

| Task | What it does |
| :--- | :--- |
| **Count** | Queries Docker labels to get the exact running count |
| **Calculate deficit** | `desired_replicas − current_count` |
| **Restore** | Launches `N` new containers from `s-web-backup:latest` with correct Compose labels so `docker compose` recognises them |
| **Remove excess** | Removes any containers above the desired count (handles over-provision edge cases) |
| **Notify** | POSTs a structured Discord embed with before/after counts and the backup image tag used |

### Startup Health Check

Before sending the *"System Online"* notification, `authealer.sh` waits in a background subshell until all `TARGET_REPLICAS` containers are in a `running` state (up to 10 minutes), then fires the Discord embed showing a live container status table.

---

## 🛡️ Security Scanning

Trivy runs as a **persistent, pre-warmed container** (`trivy-scanner`) to avoid pulling the scanner image on every build.

```
Scan scope:
  --severity      CRITICAL, HIGH
  --scanners      vuln, secret, config
  --vuln-type     os, library
  --timeout       10m
```

**Pipeline behaviour:**
- `Total: 0` → status badge set to `✅ Clean`, no report generated.
- Vulnerabilities found → status badge set to `🚨 Vulnerabilities Found`, full report attached to Discord.
- The pipeline **continues to deploy** regardless; the security status is surfaced in the final notification so the team can act with full context.

---

## 🔔 Discord Observability

Every significant event in the system produces a rich Discord embed:

| Trigger | Colour | Sent by | Fields included |
| :--- | :--- | :--- | :--- |
| **Build Started** | 🔵 Blue | Jenkins | Triggered by, project, repository |
| **Build Finished (Success)** | 🟢 Green | Jenkins | Lint, security, deploy status; duration; replicas; version |
| **Build Finished (Failed)** | 🔴 Red | Jenkins | Same as above + error snippet |
| **Vulnerabilities Found** | 🟠 Orange | Jenkins | Security overview + attached `security_report.md` |
| **Self-Healer Online** | 🟢 Green | Ansible | Live container status table |
| **Healing Triggered** | 🔴 Red | Ansible | Container name, current vs desired count |
| **Containers Restored** | 🟢 Green | Ansible | Previous count, target count, restored count, backup image |
| **Excess Containers Removed** | 🟡 Yellow | Ansible | Previous count, target count |
| **Post-Healing Health Check** | 🟢 Green | Ansible | Live container status table after recovery |

---

## 📂 Project Structure

```
devop-proj/
├── ansible/
│   ├── ansible.cfg          # Ansible configuration (local connection, no host key check)
│   ├── authealer.sh         # Event-driven self-healing script (main watchdog loop)
│   ├── inventory            # Localhost inventory for Ansible
│   ├── playbook.yml         # State-enforcement playbook (restore/remove containers)
│   └── inner_heal.yml       # Inner healing tasks (modular, called by playbook)
├── docker/
│   ├── ansible/
│   │   ├── Dockerfile       # Fast-rebuild image (copies playbooks on top of base)
│   │   └── Dockerfile.base  # Heavy base image: Ansible + Docker CLI + jq + Compose
│   ├── backup/
│   │   └── Dockerfile       # Backup/storage service
│   └── web/
│       ├── Dockerfile        # Multi-stage Node.js 18 build (BuildKit cache mount)
│       └── .dockerignore
├── .env                     # Environment variables (not committed — see below)
├── docker-compose.yml       # Service definitions: web, ansible
├── Jenkinsfile              # Declarative pipeline (5 stages + Discord notifications)
└── test-healing.sh          # Manual test script for self-healing validation
```

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Notes |
| :--- | :--- | :--- |
| Docker Engine | 24+ | With `docker.sock` accessible |
| Docker Compose | V2 (`compose` plugin) | `docker compose` (no hyphen) |
| Jenkins | 2.400+ | Pipeline + Credentials plugins |
| Discord Webhook | — | Channel → Edit → Integrations → Webhooks |

### 1 · Clone & Configure

```bash
git clone https://github.com/code6yte/devop-proj.git
cd devop-proj
```

Create your `.env` file:

```ini
COMPOSE_PROJECT_NAME=s
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN
REPLICAS=3
```

> **Never commit `.env`.** It is listed in `.gitignore`.

### 2 · Store Jenkins Credentials

In Jenkins → **Manage Jenkins → Credentials**, add a new **Secret text** credential:

| ID | Value |
| :--- | :--- |
| `discord-webhook-url` | Your Discord webhook URL |

### 3 · Create the Jenkins Pipeline

1. **New Item → Pipeline**
2. Under *Pipeline*, select **Pipeline script from SCM**
3. Set the repository URL to this repo
4. Script path: `Jenkinsfile`
5. Save and click **Build with Parameters**

### 4 · Build Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `REPO_URL` | `https://github.com/code6yte/Airbnb` | Git URL of any Next.js / React app to deploy |
| `REPLICAS` | `3` | Number of web container replicas to maintain |

### 5 · First Run

The first build will:
1. Pull the Trivy scanner image (~100 MB, cached on subsequent runs).
2. Build the Ansible base image (`ansible-control:base`) — a one-time ~2–3 minute operation.
3. Build the application image (subsequent runs are fast thanks to BuildKit cache mounts).
4. Deploy `N` web containers and start the Ansible watchdog.

---

## ⚙️ Configuration Reference

### Environment Variables

| Variable | Required | Default | Description |
| :--- | :---: | :--- | :--- |
| `COMPOSE_PROJECT_NAME` | ✅ | `s` | Docker Compose project prefix; must match label filters in `authealer.sh` |
| `DISCORD_WEBHOOK_URL` | ✅ | — | Discord incoming webhook for all notifications |
| `REPLICAS` | ❌ | `3` | Desired replica count (overridden by Jenkins parameter at runtime) |
| `IMAGE_TAG` | auto | `${BUILD_NUMBER}` | Set by Jenkins; tags each build's image uniquely |

### Ports

| Host Port Range | Container Port | Service |
| :--- | :--- | :--- |
| `8090–8099` | `3000` | Next.js web application |

### Key Docker Images

| Image | Purpose |
| :--- | :--- |
| `s-web:<BUILD_NUMBER>` | Freshly built application image for the current deploy |
| `s-web-backup:latest` | Immutable snapshot of last successful deploy; used by self-healer |
| `ansible-control:base` | Heavy base (Ansible + Docker CLI + jq) — built once and reused |
| `ansible-control:local` | Thin layer on top of base with current playbooks — rebuilt on every deploy |
| `trivy-scanner` | Persistent Trivy container; pre-warmed to avoid startup delays |

---

## 🧪 Testing Self-Healing

A helper script is included for manual validation:

```bash
# Verify backup image exists, rebuild ansible, and run playbook manually
./test-healing.sh
```

To simulate a container failure and watch the watchdog respond:

```bash
# 1. Check current containers
docker ps --filter "label=com.docker.compose.project=s"

# 2. Kill one web container
docker rm -f s-web-1

# 3. Watch the Ansible sidecar logs — it should detect the destroy event
#    and restore the container within seconds
docker logs -f ansible
```

You should see output similar to:

```
[authealer] Web container destroyed: s-web-1
[authealer] Healing needed: 2/3 containers
[authealer] Running ansible playbook to restore containers...
PLAY [Self-Healing Web Server Playbook] ***
...
[authealer] Ansible playbook completed successfully (exit code: 0)
```

A confirmation embed will also appear in your Discord channel.

---

## 📜 License

This project is open-source. Feel free to fork, adapt, and build on it.