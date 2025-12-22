pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                // Since it's local, we can use the workspace
                echo 'Using local workspace'
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    // Build all images
                    sh 'docker build -t ansible-control:local ./docker/ansible'
                    sh 'docker build -t web-server:local ./docker/web'
                    sh 'docker build -t backup-server:local ./docker/backup'
                }
            }
        }

        stage('Deploy with Docker Compose') {
            steps {
                script {
                    // Stop existing containers
                    sh 'docker compose down || true'
                    // Start all services
                    sh 'docker compose up -d'
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    // Wait a bit and check if services are running
                    sh 'sleep 10'
                    sh 'docker compose ps'
                    sh 'curl -f http://localhost:8080 || echo "Web server not ready yet"'
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment successful!'
        }
        failure {
            echo 'Deployment failed!'
        }
    }
}