pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '3'))
        disableConcurrentBuilds()
    }

    environment {
        COMPOSE_PROJECT_NAME = 's'
        DOCKER_BUILDKIT = '1'
        IMAGE_TAG = "${env.BUILD_NUMBER}" 
        DISCORD_WEBHOOK_URL = credentials('discord-webhook-url')
        
        // Tracking variables for Discord
        LINT_STATUS = "⏳ Pending"
        SECURITY_STATUS = "⏳ Pending"
        DEPLOY_STATUS = "⏳ Pending"
    }

    parameters {
        string(name: 'REPLICAS', defaultValue: '3', description: 'Number of web containers')
        string(name: 'REPO_URL', defaultValue: 'https://github.com/code6yte/Airbnb', description: 'App Git URL')
    }

    stages {
        stage('Checkout & Prep') {
            steps {
                script {
                    checkout scm
                    sh 'rm -rf docker/web/app'
                    sh "git clone ${params.REPO_URL} docker/web/app"
                }
            }
        }

        stage('Quality Check (Lint)') {
            steps {
                script {
                    try {
                        echo "Building builder for linting..."
                        sh "docker build --target builder -t s-web-builder:${IMAGE_TAG} docker/web"
                        sh "docker run --rm s-web-builder:${IMAGE_TAG} npm run lint"
                        env.LINT_STATUS = "✅ Passed"
                    } catch (Exception e) {
                        env.LINT_STATUS = "❌ Failed"
                        error "Linting failed"
                    }
                }
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                script {
                    try {
                        echo "Building production image for scanning..."
                        sh "IMAGE_TAG=${IMAGE_TAG} docker compose build web"
                        
                        // Run Trivy (Standard Docker command)
                        sh "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity CRITICAL --exit-code 1 s-web:${IMAGE_TAG}"
                        env.SECURITY_STATUS = "✅ No Critical CVEs"
                    } catch (Exception e) {
                        env.SECURITY_STATUS = "🚨 Critical Vulnerabilities Found"
                        error "Security scan failed"
                    }
                }
            }
        }

        stage('Zero-Downtime Deploy') {
            steps {
                script {
                    try {
                        echo "Deploying version ${IMAGE_TAG}..."
                        sh "IMAGE_TAG=${IMAGE_TAG} REPLICAS=${params.REPLICAS} docker compose up -d --scale web=${params.REPLICAS} --no-deps web"
                        env.DEPLOY_STATUS = "🚀 Success (Rolling Update)"
                    } catch (Exception e) {
                        env.DEPLOY_STATUS = "❌ Deployment Failed"
                        error "Deploy failed"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                def color = (currentBuild.currentResult == 'SUCCESS') ? 5763719 : 15548997
                def title = (currentBuild.currentResult == 'SUCCESS') ? "🟢 Pipeline Build Successful" : "🔴 Pipeline Build Failed"
                def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
                
                def payload = """
                {
                    "embeds": [{
                        "title": "${title}",
                        "description": "Results for build **#${env.BUILD_NUMBER}** of **${env.JOB_NAME}**",
                        "color": ${color},
                        "fields": [
                            { "name": "📦 Artifact Version", "value": "`${IMAGE_TAG}`", "inline": true },
                            { "name": "👥 Replicas", "value": "`${params.REPLICAS}`", "inline": true },
                            { "name": "🔍 Lint Check", "value": "${env.LINT_STATUS}", "inline": false },
                            { "name": "🛡️ Security (Trivy)", "value": "${env.SECURITY_STATUS}", "inline": false },
                            { "name": "🚀 Deployment", "value": "${env.DEPLOY_STATUS}", "inline": false },
                            { "name": "🔗 Repository", "value": "[View Code](${params.REPO_URL})", "inline": false }
                        ],
                        "footer": { "text": "Jenkins Local Docker Pipeline" },
                        "timestamp": "${timestamp}"
                    }]
                }
                """
                writeFile file: 'discord_report.json', text: payload
                sh "curl -H 'Content-Type: application/json' -X POST -d @discord_report.json ${DISCORD_WEBHOOK_URL}"
                
                // Cleanup
                sh "docker rmi s-web-builder:${IMAGE_TAG} || true"
                sh "rm discord_report.json"
            }
        }
    }
}