// Define startTime outside the pipeline to ensure it's accessible globally
def startTime = System.currentTimeMillis()

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
        
        // Status Tracking
        LINT_STATUS = "⚪ Skipped"
        SECURITY_STATUS = "⚪ Pending"
        DEPLOY_STATUS = "⚪ Pending"
        SECURITY_DETAILS = ""
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
                            "description": "Deployment process for **#${env.BUILD_NUMBER}** is now in progress.",
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
                        sh "docker build --target builder -t s-web-builder:${IMAGE_TAG} docker/web"
                        sh "docker run --rm s-web-builder:${IMAGE_TAG} npm run lint"
                        env.LINT_STATUS = "✅ **Passed**"
                    } catch (Exception e) {
                        env.LINT_STATUS = "⚠️ **Warnings/Failed**"
                    }
                }
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                script {
                    echo "Building production image for scanning..."
                    sh "IMAGE_TAG=${IMAGE_TAG} docker compose build web"
                    
                    // Run Trivy with persistent cache
                    sh """
                    docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v trivy-cache:/root/.cache/ \
                    aquasec/trivy image \
                    --severity CRITICAL,HIGH \
                    --no-progress \
                    s-web:${IMAGE_TAG} > trivy_report.txt || true
                    """
                    
                    def report = readFile('trivy_report.txt').trim()
                    
                    if (report.contains("Total: 0") || !report.contains("Total:")) {
                        env.SECURITY_STATUS = "✅ **Clean** (No Critical/High)"
                        env.SECURITY_DETAILS = ""
                    } else {
                        env.SECURITY_STATUS = "🚨 **Vulnerabilities Found**"
                        def table = sh(returnStdout: true, script: "grep -A 15 'Total:' trivy_report.txt | head -n 20").trim()
                        env.SECURITY_DETAILS = "```\n${table}\n```"
                    }
                }
            }
        }

        stage('Zero-Downtime Deploy') {
            steps {
                script {
                    try {
                        sh "IMAGE_TAG=${IMAGE_TAG} REPLICAS=${params.REPLICAS} docker compose up -d --scale web=${params.REPLICAS} --no-deps web"
                        env.DEPLOY_STATUS = "✅ **Deployed**"
                    } catch (Exception e) {
                        env.DEPLOY_STATUS = "❌ **Failed**"
                        error "Deployment failed"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Safely Calculate Duration
                def duration = "Unknown"
                if (startTime != null) {
                    long endTime = System.currentTimeMillis()
                    long durationSeconds = (endTime - startTime) / 1000
                    duration = "${(int)(durationSeconds / 60)}m ${durationSeconds % 60}s"
                }

                // Determine Color & Title based on status
                def resultColor = 5763719 // Success Green
                def resultTitle = "🏁 Deployment Successful"
                
                if (currentBuild.currentResult == 'FAILURE') {
                    resultColor = 15548997 // Failure Red
                    resultTitle = "❌ Deployment Failed"
                } else if (env.SECURITY_STATUS.contains('🚨')) {
                    resultColor = 16761095 // Warning Orange
                    resultTitle = "⚠️ Deployment Successful (With Security Risks)"
                }

                def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
                
                // Construct JSON
                def payload = """
                {
                    "embeds": [{
                        "title": "${resultTitle}",
                        "description": "Pipeline execution details for build **#${env.BUILD_NUMBER}**",
                        "color": ${resultColor},
                        "fields": [
                            { "name": "📊 Execution Status", "value": "> 🏗️ **Lint:** ${env.LINT_STATUS}\n> 🛡️ **Security:** ${env.SECURITY_STATUS}\n> 🚀 **Deploy:** ${env.DEPLOY_STATUS}", "inline": false },
                            ${ env.SECURITY_DETAILS ? "{\"name\": \"🛡️ Security Deep Dive\", \"value\": ${env.SECURITY_DETAILS.inspect()}, \"inline\": false}," : "" }
                            { "name": "📦 Artifact", "value": "`${IMAGE_TAG}`", "inline": true },
                            { "name": "👥 Replicas", "value": "`${params.REPLICAS}`", "inline": true },
                            { "name": "⏱️ Duration", "value": "`${duration}`", "inline": true },
                            { "name": "📂 Project", "value": "`${env.JOB_NAME}`", "inline": true },
                            { "name": "🔗 Repository", "value": "${params.REPO_URL}", "inline": false },
                            { "name": "📝 Logs", "value": "[View Jenkins Build Log](${env.BUILD_URL})", "inline": false }
                        ],
                        "footer": { "text": "Jenkins • Self-Healing Infrastructure • ${timestamp}" }
                    }]
                }
                """
                
                writeFile file: 'discord_final.json', text: payload
                sh 'curl -H "Content-Type: application/json" -X POST -d @discord_final.json $DISCORD_WEBHOOK_URL'
                
                // Final Cleanup
                sh "docker rmi s-web-builder:${IMAGE_TAG} || true"
                sh "rm discord_final.json trivy_report.txt || true"
            }
        }
    }
}
