pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '3'))
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        COMPOSE_PROJECT_NAME = 's'
        DOCKER_BUILDKIT = '1'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        DISCORD_WEBHOOK_URL = credentials('discord-webhook-url')
        
        // Use env variables for global persistence across stages
        LINT_STATUS = "⚪ Skipped"
        SECURITY_STATUS = "⏳ Pending"
        DEPLOY_STATUS = "⏳ Pending"
        SECURITY_DETAILS = ""
        START_TIME = "${System.currentTimeMillis()}"
    }

    parameters {
        string(name: 'REPLICAS', defaultValue: '3', description: 'Number of web containers')
        string(name: 'REPO_URL', defaultValue: 'https://github.com/code6yte/Airbnb', description: 'App Git URL')
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
                    def startPayload = """
                    {
                        "embeds": [{
                            "title": "🏗️ Build Pipeline Started",
                            "description": "Deployment process for build **#${env.BUILD_NUMBER}** of project **${env.JOB_NAME}**.",
                            "color": 3447003,
                            "fields": [
                                { "name": "👤 Triggered By", "value": "${currentBuild.getBuildCauses()[0].shortDescription}", "inline": true },
                                { "name": "📋 Project", "value": "`${env.JOB_NAME}`", "inline": true },
                                { "name": "🔗 Source Repository", "value": "${params.REPO_URL}", "inline": false }
                            ],
                            "timestamp": "${timestamp}"
                        }]
                    }
                    """
                    writeFile file: 'discord_start.json', text: startPayload
                    sh 'curl -H "Content-Type: application/json" -X POST -d @discord_start.json $DISCORD_WEBHOOK_URL'
                    sh "rm discord_start.json"
                }
            }
        }

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
                        echo "Running Linting..."
                        sh "docker build --target builder -t s-web-builder:${IMAGE_TAG} docker/web"
                        sh "docker run --rm s-web-builder:${IMAGE_TAG} npm run lint"
                        env.LINT_STATUS = "✅ **Passed**"
                    } catch (Exception e) {
                        env.LINT_STATUS = "⚠️ **Failed**"
                    }
                }
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                script {
                    echo "Building production image for scanning..."
                    sh "IMAGE_TAG=${IMAGE_TAG} docker compose build web"
                    
                    // Run Trivy and capture report
                    sh """
docker run --rm \
-v /var/run/docker.sock:/var/run/docker.sock \
-v trivy-cache:/root/.cache/ \
aquasec/trivy image \
--severity CRITICAL,HIGH \
--format table \
--no-progress \
s-web:${IMAGE_TAG} > trivy_report.txt 2>&1 || true
"""
                    
                    def report = readFile('trivy_report.txt').trim()
                    
                    if (report.contains("Total: 0") || !report.contains("Total:")) {
                        env.SECURITY_STATUS = "✅ **Clean**"
                        env.SECURITY_DETAILS = ""
                    } else {
                        env.SECURITY_STATUS = "🚨 **Vulnerabilities Found**"
                        // Extract the summary table and limit to 800 characters for Discord safety
                        def table = sh(returnStdout: true, script: "grep -A 20 'Total:' trivy_report.txt | head -c 800").trim()
                        env.SECURITY_DETAILS = "```text\n${table}...\n```"
                    }
                }
            }
        }

        stage('Zero-Downtime Deploy') {
            steps {
                script {
                    try {
                        echo "Deploying with Auto-Healing..."
                        // LOCKING: Prevent Ansible from healing during the update
                        sh "touch .healing_lock"
                        
                        sh "IMAGE_TAG=${IMAGE_TAG} REPLICAS=${params.REPLICAS} docker compose up -d --scale web=${params.REPLICAS}"
                        env.DEPLOY_STATUS = "✅ **Deployed**"
                    } catch (Exception e) {
                        env.DEPLOY_STATUS = "❌ **Failed**"
                        error "Deployment failed"
                    } finally {
                        // UNLOCKING: Re-enable auto-healing after deployment
                        sh "rm -f .healing_lock"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Duration calculation
                long endTime = System.currentTimeMillis()
                long durationSeconds = (endTime - env.START_TIME.toLong()) / 1000
                def duration = "${(int)(durationSeconds / 60)}m ${durationSeconds % 60}s"

                // Logic for Result Color
                def resultColor = (currentBuild.currentResult == 'SUCCESS') ? 5763719 : 15548997
                if (env.SECURITY_STATUS.contains('🚨')) resultColor = 16761095
                
                def resultTitle = (currentBuild.currentResult == 'SUCCESS') ? "🏁 Deployment Successful" : "❌ Deployment Failed"
                def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
                
                // Constructing multiline string manually to ensure formatting
                def statusText = "🏗️ **Lint:** ${env.LINT_STATUS}\n🛡️ **Security:** ${env.SECURITY_STATUS}\n🚀 **Deploy:** ${env.DEPLOY_STATUS}"

                def payload = """
                {
                    "embeds": [{
                        "title": "${resultTitle}",
                        "description": "Final report for build **#${env.BUILD_NUMBER}** of **${env.JOB_NAME}**",
                        "color": ${resultColor},
                        "fields": [
                            { "name": "📊 Execution Summary", "value": "${statusText}", "inline": false },
                            ${ env.SECURITY_DETAILS ? "{\"name\": \"🛡️ Security Report\", \"value\": ${env.SECURITY_DETAILS.inspect()}, \"inline\": false}," : "" }
                            { "name": "⏱️ Duration", "value": "`${duration}`", "inline": true },
                            { "name": "👥 Replicas", "value": "`${params.REPLICAS}`", "inline": true },
                            { "name": "📦 Version", "value": "`${IMAGE_TAG}`", "inline": true },
                            { "name": "🔗 Repository", "value": "${params.REPO_URL}", "inline": false }
                        ],
                        "footer": { "text": "Jenkins • Self-Healing Infrastructure • ${timestamp}" }
                    }]
                }
                """
                
                writeFile file: 'discord_final.json', text: payload
                sh 'curl -H "Content-Type: application/json" -X POST -d @discord_final.json $DISCORD_WEBHOOK_URL'
                
                // Cleanup
                sh "docker rmi s-web-builder:${IMAGE_TAG} || true"
                sh "rm discord_final.json trivy_report.txt || true"
            }
        }
    }
}
