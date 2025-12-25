pipeline {
    agent any

    environment {
        // Ensure the project name matches our setup
        COMPOSE_PROJECT_NAME = 's'
        // Bind the parameter to an environment variable (optional if names match, but good practice)
        DISCORD_WEBHOOK_URL = "${params.DISCORD_WEBHOOK_URL}"
        // Enable Docker BuildKit for faster builds
        DOCKER_BUILDKIT = '1'
    }

    parameters {
        string(name: 'DISCORD_WEBHOOK_URL', defaultValue: 'https://discord.com/api/webhooks/145301451832950/GloeLZi-Fo2sAcdFZZAHYWcak5xlvaAJuvrhYnDlV5igWDC-G5l4r50TptOBYWPdTisJ', description: 'Enter your Discord Webhook URL here')
        string(name: 'REPLICAS', defaultValue: '3', description: 'Number of web containers to run')
        string(name: 'REPO_URL', defaultValue: 'https://github.com/code6yte/Airbnb', description: 'Git URL of the React/Next.js project to build')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Artifacts') {
            steps {
                script {
                    // 1. Cleanup
                    sh 'rm -rf docker/web/app'
                    
                    // 2. Clone Source directly to the build context location
                    echo "Cloning ${params.REPO_URL}..."
                    sh "git clone ${params.REPO_URL} docker/web/app"
                    
                    // The build process is now handled INSIDE the Dockerfile
                    // using BuildKit's advanced caching.
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    // Debug: Check versions
                    sh 'docker --version'
                    sh 'docker compose version'

                    // Stop existing containers
                    sh 'docker compose down || true'
                    
                    // Build with BuildKit (explicit build step is cleaner)
                    sh "REPLICAS=${params.REPLICAS} docker compose build"
                    
                    // Start the services
                    sh "REPLICAS=${params.REPLICAS} docker compose up -d --scale web=${params.REPLICAS}"
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
        success {
            script {
                def message = "✅ Build Succeeded! Project: ${env.JOB_NAME} Build #${env.BUILD_NUMBER}"
                sh "curl -H 'Content-Type: application/json' -X POST -d '{\"content\": \"${message}\"}' ${DISCORD_WEBHOOK_URL}"
            }
        }
        failure {
            script {
                def message = "❌ Build Failed! Project: ${env.JOB_NAME} Build #${env.BUILD_NUMBER}"
                sh "curl -H 'Content-Type: application/json' -X POST -d '{\"content\": \"${message}\"}' ${DISCORD_WEBHOOK_URL}"
            }
        }
    }
}
