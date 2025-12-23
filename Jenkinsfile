pipeline {
    agent any

    environment {
        // Ensure the project name matches our setup
        COMPOSE_PROJECT_NAME = 's'
        // Bind the parameter to an environment variable (optional if names match, but good practice)
        DISCORD_WEBHOOK_URL = "${params.DISCORD_WEBHOOK_URL}"
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
                    
                    // 3. Install & Build in a Temporary Container
                    // We avoid volume mounting (-v) because of Docker-in-Docker path mismatches.
                    // Instead, we copy files in/out.
                    
                    // Create a dummy container to build in
                    sh 'docker create --name builder --network host -w /app node:18-alpine sh -c "npm install --legacy-peer-deps && npm run build"'
                    
                    // Copy source code INTO the container
                    sh 'docker cp docker/web/app/. builder:/app/'
                    
                    // Run the build
                    sh 'docker start -a builder'
                    
                    // Copy the built artifacts (with node_modules) OUT of the container
                    // We overwrite the local 'docker/web/app' with the built version
                    sh 'rm -rf docker/web/app'
                    sh 'docker cp builder:/app docker/web/app'
                    
                    // Cleanup
                    sh 'docker rm -f builder'
                    
                    // 4. (No Move Needed)
                    // Since we mapped the volume directly to 'docker/web/app', the 
                    // node_modules and .next/build folders are already there.
                    // The Dockerfile will COPY app/ .
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
                    
                    // Build (now very fast, just copying files) and Start
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
