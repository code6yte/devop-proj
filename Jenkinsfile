import groovy.json.JsonOutput

// Build metrics and status tracker
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
        timestamps()
    }

    environment {
        COMPOSE_PROJECT_NAME = 's'
        DOCKER_BUILDKIT = '1'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        TRIVY_CONTAINER = 'trivy-scanner'
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
                    // Send start notification to Discord
                    sendDiscordNotification(
                        title: "🏗️ Build Pipeline Started",
                        description: "Deployment process for build **#${env.BUILD_NUMBER}** of **${env.JOB_NAME}**",
                        color: 3447003,
                        fields: [
                            [name: "👤 Triggered By", value: "${currentBuild.getBuildCauses()[0].shortDescription}", inline: true],
                            [name: "📋 Project", value: "`${env.JOB_NAME}`", inline: true],
                            [name: "🔗 Repository", value: "${params.REPO_URL}", inline: false]
                        ]
                    )
                    
                    // Ensure Trivy scanner is ready
                    ensureTrivyScanner()
                }
            }
        }

        stage('Checkout & Prep') {
            steps {
                script {
                    echo "📦 Checking out source code..."
                    checkout scm
                    
                    echo "🔄 Cloning application repository..."
                    sh 'rm -rf docker/web/app'
                    sh "git clone ${params.REPO_URL} docker/web/app"
                }
            }
        }

        stage('Quality Check (Lint)') {
            steps {
                script {
                    echo "🔍 Running code quality checks..."
                    try {
                        sh "docker build --target builder -t s-web-builder:${IMAGE_TAG} docker/web"
                        sh "docker run --rm s-web-builder:${IMAGE_TAG} npm run lint > lint_output.txt 2>&1"
                        
                        def lintOutput = readFile('lint_output.txt').trim()
                        echo "✅ Lint check passed\n${lintOutput}"
                        buildStatus.lint = "✅ **Passed**"
                    } catch (Exception e) {
                        buildStatus.lint = "⚠️ **Failed**"
                        def logs = sh(returnStdout: true, script: "tail -n 10 lint_output.txt 2>/dev/null || echo 'No logs available'").trim()
                        buildStatus.lint_logs = "```text\n${logs}\n```"
                        echo "⚠️ Lint check failed (non-blocking)\n${logs}"
                    }
                }
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                script {
                    echo "🏗️ Building production image..."
                    sh "IMAGE_TAG=${IMAGE_TAG} docker compose build web"
                    
                    echo "🛡️ Running security vulnerability scan..."
                    sh """
                        docker exec ${TRIVY_CONTAINER} trivy image \
                        --severity CRITICAL,HIGH \
                        --scanners vuln,secret,config \
                        --vuln-type os,library \
                        --no-progress \
                        --timeout 10m \
                        s-web:${IMAGE_TAG} | tee trivy_report.txt
                    """
                    
                    // Analyze security scan results
                    def report = readFile('trivy_report.txt').trim()
                    if (report.contains("Total: 0") || !report.contains("Total:")) {
                        buildStatus.security = "✅ **Clean**"
                        buildStatus.security_details = ""
                        echo "✅ No vulnerabilities found"
                    } else {
                        buildStatus.security = "🚨 **Vulnerabilities Found**"
                        // Extract only the "Total:" line for the notification
                        def totalLine = sh(returnStdout: true, script: "grep '^Total:' trivy_report.txt || echo 'Total: Unknown'").trim()
                        buildStatus.security_details = "```\n${totalLine}\n```"
                        echo "🚨 Security vulnerabilities detected: ${totalLine}"
                    }

                    // Generate full security report file (only if vulnerabilities found)
                    if (!report.contains("Total: 0") && report.contains("Total:")) {
                        sh """
                            echo '# 🛡️ Security Scan Report - Build #${env.BUILD_NUMBER}' > security_report.md
                            echo '## Image: s-web:${IMAGE_TAG}' >> security_report.md
                            echo '---' >> security_report.md
                            echo '```text' >> security_report.md
                            cat trivy_report.txt >> security_report.md
                            echo '```' >> security_report.md
                        """
                    }
                }
            }
        }

        stage('Zero-Downtime Deploy') {
            steps {
                script {
                    echo "🚀 Starting zero-downtime deployment..."
                    try {
                        // Step 1: Stop and remove Ansible container FIRST (before other containers)
                        echo "🛑 Stopping and removing Ansible container..."
                        sh "docker rm -f ansible 2>/dev/null || echo 'Ansible container not found'"

                        // Step 2: Deploy new web containers and remove old ones
                        echo "📦 Deploying new web containers..."
                        sh """
                            IMAGE_TAG=${IMAGE_TAG} \
                            REPLICAS=${params.REPLICAS} \
                            docker compose up -d --scale web=${params.REPLICAS} --no-color 2>&1 | tee deploy_output.txt
                        """
                        
                        // Step 3: Verify web deployment
                        def runningContainers = sh(returnStdout: true, script: "docker compose ps web --format json | jq -r '.State' | grep -c running || echo 0").trim()
                        echo "✅ Web deployment successful - ${runningContainers} containers running"
                        
                        // Step 4: Update backup container
                        echo "🔄 Updating backup container..."
                        sh "docker compose up -d backup --no-color"
                        
                        // Step 5: Recreate and start Ansible container LAST (after all other containers)
                        echo "✅ Starting Ansible monitoring..."
                        sh "docker compose up -d ansible --no-color"
                        
                        buildStatus.deploy = "✅ **Deployed**"
                        
                    } catch (Exception e) {
                        buildStatus.deploy = "❌ **Failed**"
                        def logs = sh(returnStdout: true, script: "tail -n 10 deploy_output.txt 2>/dev/null || echo 'No logs available'").trim()
                        buildStatus.deploy_logs = "```text\n${logs}\n```"
                        
                        // Ensure Ansible is started even on failure
                        echo "⚠️ Deployment failed - starting Ansible anyway..."
                        sh "docker compose up -d ansible --no-color 2>/dev/null || echo 'Warning: Could not start Ansible'"
                        
                        error "Deployment failed: ${e.message}"
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                // Calculate build duration
                long durationMs = System.currentTimeMillis() - buildStatus.start_time
                long durationSec = durationMs / 1000
                def duration = "${(int)(durationSec / 60)}m ${durationSec % 60}s"

                // Determine result status and color
                def resultColor = 5763719 // Green
                def resultTitle = "🏁 Deployment Successful"
                
                if (buildStatus.security.contains('🚨')) {
                    resultColor = 16761095 // Orange - vulnerabilities found but deployed
                }
                if (currentBuild.currentResult != 'SUCCESS') {
                    resultColor = 15548997 // Red - failed
                    resultTitle = "❌ Deployment Failed"
                }

                // Build status summary
                def statusSummary = [
                    "🏗️ **Lint Check:** ${buildStatus.lint}",
                    "🛡️ **Security:** ${buildStatus.security}",
                    "🚀 **Deployment:** ${buildStatus.deploy}"
                ].join("\n")

                // Prepare notification fields
                def fields = [
                    [name: "📊 Execution Summary", value: statusSummary, inline: false]
                ]

                // Add security details if vulnerabilities found
                if (buildStatus.security_details) {
                    fields << [name: "🛡️ Security Overview", value: buildStatus.security_details, inline: false]
                }

                // Add error logs if present
                if (buildStatus.lint_logs) {
                    fields << [name: "⚠️ Lint Error Snippet", value: buildStatus.lint_logs, inline: false]
                }
                if (buildStatus.deploy_logs) {
                    fields << [name: "❌ Deploy Error Snippet", value: buildStatus.deploy_logs, inline: false]
                }

                // Add build metadata
                fields << [name: "⏱️ Duration", value: "`${duration}`", inline: true]
                fields << [name: "👥 Replicas", value: "`${params.REPLICAS}`", inline: true]
                fields << [name: "📦 Version", value: "`${IMAGE_TAG}`", inline: true]
                fields << [name: "🔗 Repository", value: "${params.REPO_URL}", inline: false]

                // Send final Discord notification
                try {
                    // Send build notification first (without attachment)
                    sendDiscordNotification(
                        title: resultTitle,
                        description: "Final report for build **#${env.BUILD_NUMBER}**",
                        color: resultColor,
                        fields: fields
                    )
                    
                    // Send security report file separately if vulnerabilities found
                    if (buildStatus.security.contains('🚨') && fileExists('security_report.md')) {
                        sleep 1 // Small delay to ensure messages arrive in order
                        echo "📎 Sending security report file..."
                        sh """
                            curl -f -X POST \
                            -F "content=📋 **Detailed Security Report - Build #${env.BUILD_NUMBER}**" \
                            -F "file=@security_report.md" \
                            \$DISCORD_WEBHOOK_URL
                        """
                    }
                } catch (Exception e) {
                    echo "⚠️ WARNING: Failed to send Discord notification: ${e.message}"
                }

                // Cleanup
                cleanupArtifacts()
            }
        }
    }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Ensures Trivy security scanner container is running
 */
def ensureTrivyScanner() {
    echo "🔧 Checking Trivy scanner status..."
    
    // Check if container exists
    def exists = sh(
        returnStdout: true,
        script: "docker ps -a --format '{{.Names}}' | grep -q '^${TRIVY_CONTAINER}\$' && echo 'true' || echo 'false'"
    ).trim()

    if (exists == 'true') {
        // Check if it's running
        def isRunning = sh(
            returnStdout: true,
            script: "docker inspect -f '{{.State.Running}}' ${TRIVY_CONTAINER} 2>/dev/null || echo 'false'"
        ).trim()
        
        if (isRunning == 'true') {
            echo "✅ Trivy scanner is already running"
            return
        }
        
        // Container exists but not running - check if it's the old broken version
        echo "🗑️ Removing old Trivy scanner container..."
        sh "docker rm -f ${TRIVY_CONTAINER} || true"
    }

    // Create new Trivy scanner container
    echo "🆕 Creating new Trivy scanner container..."
    sh """
        docker run -d \
        --name ${TRIVY_CONTAINER} \
        --restart unless-stopped \
        --entrypoint /bin/sh \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v trivy-cache:/root/.cache/ \
        aquasec/trivy:latest \
        -c 'while true; do sleep 3600; done'
    """

    // Verify it's running
    sleep 2
    def isRunning = sh(
        returnStdout: true,
        script: "docker inspect -f '{{.State.Running}}' ${TRIVY_CONTAINER} 2>/dev/null || echo 'false'"
    ).trim()

    if (isRunning != 'true') {
        sh "docker logs ${TRIVY_CONTAINER} 2>&1 || true"
        error "❌ Trivy scanner failed to start"
    }
    
    echo "✅ Trivy scanner is ready"
}

/**
 * Send notification to Discord webhook
 * @param config Map with title, description, color, fields
 */
def sendDiscordNotification(Map config) {
    def timestamp = sh(returnStdout: true, script: "date -u +%Y-%m-%dT%H:%M:%SZ").trim()
    
    def payload = [
        embeds: [[
            title: config.title,
            description: config.description,
            color: config.color,
            fields: config.fields,
            footer: [text: "Jenkins • Self-Healing Infrastructure"],
            timestamp: timestamp
        ]]
    ]
    
    writeFile file: 'discord_payload.json', text: JsonOutput.toJson(payload)
    
    // Send simple JSON notification
    sh """
        curl -f -X POST \
        -H "Content-Type: application/json" \
        -d @discord_payload.json \
        \$DISCORD_WEBHOOK_URL
    """
    
    sh "rm -f discord_payload.json"
}

/**
 * Cleanup temporary files and old Docker images
 */
def cleanupArtifacts() {
    echo "🧹 Cleaning up temporary files and images..."
    
    // Remove builder image
    sh "docker rmi s-web-builder:${IMAGE_TAG} 2>/dev/null || true"
    
    // Remove temporary files
    sh """
        rm -f discord_payload.json \
              trivy_report.txt \
              security_report.md \
              lint_output.txt \
              deploy_output.txt \
              2>/dev/null || true
    """
    
    // Stop Trivy scanner to free up resources
    echo "🛑 Stopping Trivy scanner to save resources..."
    sh "docker stop ${TRIVY_CONTAINER} 2>/dev/null || echo 'Trivy scanner already stopped'"
    
    echo "✅ Cleanup complete"
}
