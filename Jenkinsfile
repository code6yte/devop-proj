import groovy.json.JsonOutput

// GLOBAL STATUS TRACKER
def buildStatus = [
    lint: "⚪ Skipped",
    security: "⏳ Pending",
    deploy: "⏳ Pending",
    lint_logs: "",
    deploy_logs: "",
    security_details: "",
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
                    sh """
                    if ! docker ps -a --format '{{.Names}}' | grep -q '^trivy-scanner\$'; then
                        echo "Creating persistent Trivy scanner..."
                        docker run -d --name trivy-scanner \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        -v trivy-cache:/root/.cache/ \\
                        aquasec/trivy:latest sleep infinity
                    elif ! docker ps --format '{{.Names}}' | grep -q '^trivy-scanner\$'; then
                        echo "Restarting Trivy scanner..."
                        docker start trivy-scanner
                    fi
                    """

                    def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
                    def startPayload = [
                        embeds: [[
                            title: "🏗️ Build Pipeline Started",
                            description: "Deployment process for build **#${env.BUILD_NUMBER}** of **${env.JOB_NAME}**.",
                            color: 3447003,
                            fields: [
                                [ name: "👤 Triggered By", "value": "${currentBuild.getBuildCauses()[0].shortDescription}", "inline": true ],
                                [ name: "📋 Project", "value": "`${env.JOB_NAME}`", "inline": true ],
                                [ name: "🔗 Repository", "value": "${params.REPO_URL}", "inline": false ]
                            ],
                            timestamp: timestamp
                        ]]
                    ]
                    writeFile file: 'discord_start.json', text: JsonOutput.toJson(startPayload)
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
                        sh "docker run --rm s-web-builder:${IMAGE_TAG} npm run lint > lint_output.txt 2>&1"
                        echo "--- LINT OUTPUT ---"
                        sh "cat lint_output.txt"
                        buildStatus.lint = "✅ **Passed**"
                    } catch (Exception e) {
                        buildStatus.lint = "⚠️ **Failed**"
                        echo "--- LINT ERROR OUTPUT ---"
                        sh "cat lint_output.txt"
                        def logs = sh(returnStdout: true, script: "[ -f lint_output.txt ] && tail -n 5 lint_output.txt || echo 'No logs'").trim()
                        buildStatus.lint_logs = "```text\n${logs}\n```"
                    }
                }
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                script {
                    echo "Baking production image..."
                    sh "IMAGE_TAG=${IMAGE_TAG} docker compose build web"
                    
                    echo "Running Deep Security Scan..."
                    // We generate a Markdown report for Discord attachment and a text report for console
                    sh """
                    docker exec trivy-scanner trivy image \
                    --severity CRITICAL,HIGH \
                    --format table \
                    --no-progress \
                    s-web:${IMAGE_TAG} > trivy_report.txt 2>&1 || true
                    
                    # Create a Markdown version for Discord
                    echo "# 🛡️ Security Scan Report - Build #${env.BUILD_NUMBER}" > security_report.md
                    echo "## Image: s-web:${IMAGE_TAG}" >> security_report.md
                    echo "---" >> security_report.md
                    echo '```text' >> security_report.md
                    cat trivy_report.txt >> security_report.md
                    echo '```' >> security_report.md
                    """
                    
                    def report = readFile('trivy_report.txt').trim()
                    
                    if (report.contains("Total: 0") || !report.contains("Total:")) {
                        buildStatus.security = "✅ **Clean**"
                        buildStatus.security_details = "No vulnerabilities detected."
                    } else {
                        buildStatus.security = "🚨 **Vulnerabilities Found**"
                        def summary = sh(returnStdout: true, script: "grep 'Total:' trivy_report.txt").trim()
                        buildStatus.security_details = "Vulnerabilities detected: ${summary}. Full report attached below."
                    }
                }
            }
        }

        stage('Zero-Downtime Deploy') {
            steps {
                script {
                    try {
                        echo "Deploying with Auto-Healing Management..."
                        sh "docker exec ansible touch /tmp/healing.lock || true"
                        
                        sh "IMAGE_TAG=${IMAGE_TAG} REPLICAS=${params.REPLICAS} docker compose up -d --scale web=${params.REPLICAS} > deploy_output.txt 2>&1"
                        echo "--- DEPLOY OUTPUT ---"
                        sh "cat deploy_output.txt"
                        buildStatus.deploy = "✅ **Deployed**"
                    } catch (Exception e) {
                        buildStatus.deploy = "❌ **Failed**"
                        echo "--- DEPLOY ERROR OUTPUT ---"
                        sh "cat deploy_output.txt"
                        def logs = sh(returnStdout: true, script: "[ -f deploy_output.txt ] && tail -n 5 deploy_output.txt || echo 'No logs'").trim()
                        buildStatus.deploy_logs = "```text\n${logs}\n```"
                        error "Deployment failed"
                    } finally {
                        sh "docker exec ansible rm -f /tmp/healing.lock || true"
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
                
                def statusSummary = [
                    "🏗️ **Lint Check:** ${buildStatus.lint}",
                    "🛡️ **Security:** ${buildStatus.security}",
                    "🚀 **Deployment:** ${buildStatus.deploy}"
                ].join("\n")

                def fields = [
                    [ name: "📊 Execution Summary", value: statusSummary, inline: false ],
                    [ name: "🛡️ Security Overview", value: buildStatus.security_details, inline: false ]
                ]

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

                def finalPayload = [
                    embeds: [[
                        title: resultTitle,
                        description: "Final report for build **#${env.BUILD_NUMBER}**",
                        color: resultColor,
                        fields: fields,
                        footer: [ text: "Jenkins • Self-Healing Infrastructure • ${timestamp}" ]
                    ]]
                ]
                
                writeFile file: 'discord_final.json', text: JsonOutput.toJson(finalPayload)
                
                // SENDING TO DISCORD:
                // We use multipart/form-data to send both the JSON payload AND the file
                sh '''
                curl -H "Content-Type: multipart/form-data" \
                     -F "payload_json=$(cat discord_final.json)" \
                     -F "file1=@security_report.md" \
                     $DISCORD_WEBHOOK_URL
                '''
                
                sh "docker rmi s-web-builder:${IMAGE_TAG} || true"
                sh "rm -f discord_final.json trivy_report.txt security_report.md lint_output.txt deploy_output.txt || true"
            }
        }
    }
}
