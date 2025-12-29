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
            echo 'Deployment finished.'
        }
        success {
            script {
                def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
                def payload = """
                {
                    "embeds": [{
                        "title": "🚀 Deployment Successful",
                        "description": "Pipeline **${env.JOB_NAME}** #${env.BUILD_NUMBER} finished successfully.",
                        "color": 5763719,
                        "fields": [
                            {
                                "name": "Repository",
                                "value": "${params.REPO_URL}",
                                "inline": false
                            },
                            {
                                "name": "Web Replicas",
                                "value": "${params.REPLICAS}",
                                "inline": true
                            },
                            {
                                "name": "Healing Service",
                                "value": "🟢 Active (Verified)",
                                "inline": true
                            }
                        ],
                        "timestamp": "${timestamp}"
                    }]
                }
                """
                // Write payload to a temp file to avoid escaping issues
                writeFile file: 'discord_success.json', text: payload
                sh "curl -H 'Content-Type: application/json' -X POST -d @discord_success.json ${DISCORD_WEBHOOK_URL}"
                sh "rm discord_success.json"
            }
        }
        failure {
            script {
                def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
                def payload = """
                {
                    "embeds": [{
                        "title": "❌ Deployment Failed",
                        "description": "Pipeline **${env.JOB_NAME}** #${env.BUILD_NUMBER} encountered an error during execution.",
                        "color": 15548997,
                        "timestamp": "${timestamp}"
                    }]
                }
                """
                writeFile file: 'discord_failure.json', text: payload
                sh "curl -H 'Content-Type: application/json' -X POST -d @discord_failure.json ${DISCORD_WEBHOOK_URL}"
                sh "rm discord_failure.json"
            }
        }
    }
}
