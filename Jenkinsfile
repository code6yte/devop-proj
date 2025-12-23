pipeline {
  agent any
  options { timestamps() }
  parameters {
    booleanParam(name: 'CLEANUP', defaultValue: false, description: 'Bring down compose and remove watcher')
  }
  environment {
    COMPOSE_PROJECT_NAME = 'devop_healing'
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
echo "Running smoke tests from inside ansible-control network..."

# Function to test a URL using Python (available in ansible-control)
test_url() {
  local url=$1
  echo "Testing $url..."
  for i in $(seq 1 20); do
    if docker exec ansible-control python3 -c "import urllib.request; print(urllib.request.urlopen('$url').getcode())" | grep 200 >/dev/null 2>&1; then
      echo "$url responded with 200 OK"
      return 0
    fi
    echo "Waiting for $url... ($i)"
    sleep 3
  done
  echo "$url did not respond." >&2
  return 1
}

# Test the replicas by their internal container names/aliases
# Compose V2 with project 'devop_healing' creates: devop_healing-web-1, devop_healing-web-2, devop_healing-web-3
test_url "http://devop_healing-web-1:80"
test_url "http://devop_healing-web-2:80"
test_url "http://devop_healing-web-3:80"

echo "All replicas operational."
'''
      }
    }
    
    stage('Verify Self-Healing') {
        steps {
            echo "Verifying that the ansible controller is running..."
            sh 'docker ps --filter "name=ansible-control" | grep ansible-control'
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
