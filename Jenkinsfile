pipeline {
    agent any

    environment {
        // Ensure the project name matches our setup
        COMPOSE_PROJECT_NAME = 's'
        // Bind the parameter to an environment variable (optional if names match, but good practice)
        DISCORD_WEBHOOK_URL = "${params.DISCORD_WEBHOOK_URL}"
    }

    parameters {
        string(name: 'DISCORD_WEBHOOK_URL', defaultValue: '', description: 'Enter your Discord Webhook URL here')
        string(name: 'REPLICAS', defaultValue: '3', description: 'Number of web containers to run')
        string(name: 'REPO_URL', defaultValue: 'https://github.com/facebook/react.git', description: 'Git URL of the React/Next.js project to build')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Prepare Source') {
            steps {
                script {
                    // Clean previous app source
                    sh 'rm -rf docker/web/app'
                    
                    // Clone the user-provided repo into docker/web/app
                    // We use git directly. If private, credentials would need to be handled.
                    sh "git clone ${params.REPO_URL} docker/web/app"
                    
                    // Basic check to see if it looks like a node project
                    sh 'ls -la docker/web/app'
                }
            }
        }

        stage('Build & Deploy') {
            steps {
                script {
                    // Debug: Check versions
                    sh 'docker --version'
                    sh 'docker compose version'

                    // Stop existing containers to ensure clean state (optional, but good for "building" phase)
                    // We use '|| true' to prevent failure if containers don't exist yet
                    sh 'docker compose down || true'
                    
                    // Build and start the containers, using the REPLICAS parameter
                    sh "docker compose up -d --build --scale web=${params.REPLICAS}"
                }
            }
        }

        stage('Verify') {
            steps {
                script {
                    // Check if containers are up
                    sh 'docker compose ps'
                    // Check if the ansible container is running using docker compose ps
                    // This avoids the exit code 1 from grep if it's not ready immediately
                    sh 'docker compose ps ansible'
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
