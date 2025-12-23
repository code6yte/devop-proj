pipeline {
    agent any

    environment {
        // Ensure the project name matches our setup
        COMPOSE_PROJECT_NAME = 's'
    }

    stages {
        stage('Checkout') {
            steps {
                // Checkout the code from the configured SCM (Git)
                checkout scm
            }
        }

        stage('Build & Deploy') {
            steps {
                script {
                    // Stop existing containers to ensure clean state (optional, but good for "building" phase)
                    // We use '|| true' to prevent failure if containers don't exist yet
                    sh 'docker compose down || true'
                    
                    // Build and start the containers, scaling the web service to 3
                    sh 'docker compose up -d --build --scale web=3'
                }
            }
        }

        stage('Verify') {
            steps {
                script {
                    // Check if containers are up
                    sh 'docker compose ps'
                    // specific check to see if the healer is running
                    sh 'docker ps | grep ansible'
                }
            }
        }
    }

    post {
        always {
            // Clean up workspace if needed, or leave artifacts for debugging
            echo 'Deployment finished.'
        }
        failure {
            echo 'Deployment failed.'
        }
    }
}
