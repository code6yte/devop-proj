pipeline {
  agent any
  options { timestamps() }
  parameters {
    booleanParam(name: 'CLEANUP', defaultValue: false, description: 'Bring down compose and remove watcher')
  }
  environment {
    COMPOSE_PROJECT_NAME = 'devop2'
    COMPOSE_FILE = 'docker-compose.yml'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build Images') {
      steps {
        sh '''
set -euo pipefail
# Use "docker compose" (v2) or "docker-compose" (v1)
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  COMPOSE_CMD="docker compose"
fi
echo "Using $COMPOSE_CMD"

# Build all services including authealer and ansible
$COMPOSE_CMD build --parallel --no-cache
'''
      }
    }

    stage('Deploy Stack') {
      steps {
        sh '''
set -euo pipefail
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  COMPOSE_CMD="docker compose"
fi

echo "Deploying services with scale web=3..."
# Ensure we use the same project name 'devop2' so Ansible matches
$COMPOSE_CMD -p $COMPOSE_PROJECT_NAME up -d --scale web=3 --remove-orphans --force-recreate

echo "Current containers:"
$COMPOSE_CMD -p $COMPOSE_PROJECT_NAME ps
'''
      }
    }

    stage('Smoke Tests') {
      steps {
        sh '''
set -euo pipefail
echo "Running smoke tests for web replicas (ports 8090-8092)"

# Function to test a port
test_port() {
  local port=$1
  for i in $(seq 1 20); do
    if curl -sSf http://localhost:$port >/dev/null 2>&1; then
      echo "Web replica on port $port is responding."
      return 0
    fi
    echo "Waiting for port $port... ($i)"
    sleep 3
  done
  echo "Port $port did not respond." >&2
  return 1
}

test_port 8090
test_port 8091
test_port 8092

echo "All replicas operational."
'''
      }
    }
    
    stage('Verify Self-Healing') {
        steps {
            echo "Verifying that the authealer is running..."
            sh 'docker ps --filter "name=authealer" | grep authealer'
        }
    }
  }

  post {
    failure {
      sh '''
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  COMPOSE_CMD="docker compose"
fi
echo "=== Last logs ==="
$COMPOSE_CMD -p $COMPOSE_PROJECT_NAME logs --tail=100 || true
'''
    }
    always {
      script {
        if (params.CLEANUP) {
          sh '''
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  COMPOSE_CMD="docker compose"
fi
echo "Cleaning up..."
$COMPOSE_CMD -p $COMPOSE_PROJECT_NAME down -v --remove-orphans || true
'''
        }
      }
    }
  }
}
