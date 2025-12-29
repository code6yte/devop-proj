// Global map to track status and logs across stages
def buildStatus = [
    lint: "⚪ Skipped",
    lint_logs: "",
    security: "⏳ Pending",
    security_details: "",
    deploy: "⏳ Pending",
    deploy_logs: "",
    start_time: System.currentTimeMillis()
]

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
                        echo "Running Linting..."
                        sh "docker build --target builder -t s-web-builder:${IMAGE_TAG} docker/web"
                        sh "docker run --rm s-web-builder:${IMAGE_TAG} npm run lint > lint_output.txt 2>&1"
                        buildStatus.lint = "✅ **Passed**"
                    } catch (Exception e) {
                        buildStatus.lint = "⚠️ **Failed**"
                        // Capture last 10 lines of lint failure
                        def logs = sh(returnStdout: true, script: "[ -f lint_output.txt ] && tail -n 10 lint_output.txt || echo 'No logs available'").trim()
                        buildStatus.lint_logs = "```text\n${logs}\n```"
                    }
                }
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                script {
                    echo "Building for scanning..."
                    sh "IMAGE_TAG=${IMAGE_TAG} docker compose build web"
                    
                    sh """
                    docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v trivy-cache:/root/.cache/ \
                    aquasec/trivy image \
                    --severity CRITICAL,HIGH \
                    --no-progress \
                    s-web:${IMAGE_TAG} > trivy_report.txt 2>&1 || true
                    """
                    
                    def report = readFile('trivy_report.txt').trim()
                    
                    if (report.contains("Total: 0") || !report.contains("Total:")) {
                        buildStatus.security = "✅ **Clean**"
                        buildStatus.security_details = ""
                    } else {
                        buildStatus.security = "🚨 **Vulnerabilities Found**"
                        def table = sh(returnStdout: true, script: "grep -A 20 'Total:' trivy_report.txt | head -n 25").trim()
                        buildStatus.security_details = "```\n${table}\n```"
                    }
                }
            }
        }

        stage('Zero-Downtime Deploy') {
            steps {
                script {
                    try {
                        echo "Deploying with Auto-Healing (Ansible)..."
                        sh "IMAGE_TAG=${IMAGE_TAG} REPLICAS=${params.REPLICAS} docker compose up -d --scale web=${params.REPLICAS} > deploy_output.txt 2>&1"
                        buildStatus.deploy = "✅ **Deployed**"
                    } catch (Exception e) {
                        buildStatus.deploy = "❌ **Failed**"
                        def logs = sh(returnStdout: true, script: "[ -f deploy_output.txt ] && tail -n 10 deploy_output.txt || echo 'No logs available'").trim()
                        buildStatus.deploy_logs = "```text\n${logs}\n```"
                        error "Deployment failed"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                long endTime = System.currentTimeMillis()
                long durationSeconds = (endTime - buildStatus.start_time) / 1000
                def duration = "${(int)(durationSeconds / 60)}m ${durationSeconds % 60}s"

                def resultColor = (currentBuild.currentResult == 'SUCCESS') ? 5763719 : 15548997
                if (buildStatus.security.contains('🚨')) resultColor = 16761095
                
                def resultTitle = (currentBuild.currentResult == 'SUCCESS') ? "🏁 Deployment Successful" : "❌ Deployment Failed"
                def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
                
                def executionStatus = "> 🏗️ **Lint Check:** ${buildStatus.lint}\n> 🛡️ **Security:** ${buildStatus.security}\n> 🚀 **Deployment:** ${buildStatus.deploy}"

                // Build dynamic fields list
                def fields = [
                    [ name: "📊 Execution Status", value: executionStatus, inline: false ]
                ]

                if (buildStatus.security_details) {
                    fields << [ name: "🛡️ Security Deep Dive", value: buildStatus.security_details, inline: false ]
                }
                if (buildStatus.lint_logs) {
                    fields << [ name: "⚠️ Lint Error Snippet", value: buildStatus.lint_logs, inline: false ]
                }
                if (buildStatus.deploy_logs) {
                    fields << [ name: "❌ Deploy Error Snippet", value: buildStatus.deploy_logs, inline: false ]
                }

                fields << [ name: "⏱️ Duration", value: "`${duration}`", inline: true ]
                fields << [ name: "👥 Replicas", value: "`${params.REPLICAS}`", inline: true ]
                fields << [ name: "📦 Version", value: "`${IMAGE_TAG}`", inline: true ]
                fields << [ name: "🔗 Repository", value: "${params.REPO_URL}", inline: false ]

                def payload = [
                    embeds: [[
                        title: resultTitle,
                        description: "Pipeline summary for build **#${env.BUILD_NUMBER}**",
                        color: resultColor,
                        fields: fields,
                        footer: [ text: "Jenkins • Self-Healing Infrastructure • ${timestamp}" ]
                    ]]
                ]
                
                // Using groovy JSON builder to handle escaping perfectly
                def jsonPayload = groovy.json.JsonOutput.toJson(payload)
                writeFile file: 'discord_final.json', text: jsonPayload
                
                sh 'curl -H "Content-Type: application/json" -X POST -d @discord_final.json $DISCORD_WEBHOOK_URL'
                
                sh "docker rmi s-web-builder:${IMAGE_TAG} || true"
                sh "rm discord_final.json trivy_report.txt lint_output.txt deploy_output.txt || true"
            }
        }
    }
}