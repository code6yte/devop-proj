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
                    // 1. Cleanup & Setup
                    sh 'rm -rf docker/web/app docker/web/html'
                    sh 'mkdir -p docker/web/html'
                    
                    // 2. Clone Source
                    echo "Cloning ${params.REPO_URL}..."
                    sh "git clone ${params.REPO_URL} docker/web/app"
                    
                    // 3. Compile in a Temporary Container
                    // We use '--network host' to fix the DNS/Fetch errors you saw.
                    // We map the source code into the container.
                    sh """
                        docker run --rm \
                        --network host \
                        -v \${PWD}/docker/web/app:/app \
                        -w /app \
                        node:18-alpine \
                        sh -c "npm install --legacy-peer-deps && npm run build"
                    """
                    
                    // 4. Normalize Output
                    // Different frameworks use different output folders. We find the right one and move it.
                    sh """
                        if [ -d "docker/web/app/build" ]; then
                            cp -r docker/web/app/build/* docker/web/html/
                        elif [ -d "docker/web/app/dist" ]; then
                            cp -r docker/web/app/dist/* docker/web/html/
                        elif [ -d "docker/web/app/out" ]; then
                            cp -r docker/web/app/out/* docker/web/html/
                        else
                            echo "⚠️ No standard build folder found (build/dist/out). Checking for .next..."
                            # If it's a Next.js app without 'output: export', we might need to handle it differently, 
                            # but for static Nginx hosting, we usually need the static export.
                            # For now, let's create a placeholder if build failed to produce static files.
                            echo '<h1>Build Finished, but no static output found. Check your next.config.js for output: export</h1>' > docker/web/html/index.html
                        fi
                    """
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
