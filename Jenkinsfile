pipeline {
  agent any
  options { timestamps() }
  parameters {
    booleanParam(name: 'CLEANUP', defaultValue: false, description: 'Bring down compose and remove watcher')
  }
  environment {
    COMPOSE_FILE = 'docker-compose.yml'
    WATCHER_NAME = 'authealer-watcher'
    JENKINS_API_TOKEN = credentials('jenkins_api_token')
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build Images') {
      steps {
        sh '''
set -euo pipefail
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=docker-compose
else
  COMPOSE_CMD="docker compose"
fi
echo "Using $COMPOSE_CMD"

# build only the app images we care about
$COMPOSE_CMD build --parallel web backup ansible || $COMPOSE_CMD build --parallel
'''
      }
    }

    stage('Deploy Services') {
      steps {
        sh '''
set -euo pipefail
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=docker-compose
else
  COMPOSE_CMD="docker compose"
fi

echo "Bringing up web, backup, ansible"
$COMPOSE_CMD up -d web backup ansible

echo "Current containers:"
$COMPOSE_CMD ps || true
'''
      }
    }

    stage('Start Watchdog (authealer)') {
      steps {
        sh '''
set -euo pipefail
WORKDIR=$(pwd)
echo "Starting authealer watcher container"
docker rm -f "$WATCHER_NAME" >/dev/null 2>&1 || true
docker run -d --name "$WATCHER_NAME" --network devops-net \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$WORKDIR/ansible":/ansible \
  -e JENKINS_API_TOKEN="$JENKINS_API_TOKEN" \
  alpine:3.18 sh -c "apk add --no-cache docker-cli bash curl jq >/dev/null 2>&1 && /ansible/authealer.sh" \
  || true
docker ps --filter name="$WATCHER_NAME" --no-trunc || true
'''
      }
    }

    stage('Smoke Tests') {
      steps {
        sh '''
set -euo pipefail
echo "Running smoke tests for web"
for i in $(seq 1 20); do
  if curl -sSf http://localhost:8080 >/dev/null 2>&1; then
    echo "web is responding"
    exit 0
  fi
  echo "waiting... ($i)"
  sleep 3
done
echo "web did not respond after timeout" >&2
exit 1
'''
      }
    }
  }

  post {
    failure {
      sh '''
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=docker-compose
else
  COMPOSE_CMD="docker compose"
fi
echo "=== Last logs (tail 200) ==="
$COMPOSE_CMD logs --tail=200 || true
docker logs --tail 200 ${WATCHER_NAME} || true
'''
    }
    always {
      script {
        if (params.CLEANUP) {
          sh '''
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=docker-compose
else
  COMPOSE_CMD="docker compose"
fi
echo "Tearing down compose-managed services and watcher"
$COMPOSE_CMD down -v --remove-orphans || true
docker rm -f ${WATCHER_NAME} || true
'''
        }
      }
    }
  }
}