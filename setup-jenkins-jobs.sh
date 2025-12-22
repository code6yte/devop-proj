#!/bin/bash
# Jenkins Job Setup Script
# This script helps set up Jenkins jobs using Jenkins CLI

JENKINS_URL="http://localhost:8081"
JENKINS_USER="admin"

echo "Setting up Jenkins jobs..."

# Get Jenkins CLI
echo "Downloading Jenkins CLI..."
curl -o jenkins-cli.jar $JENKINS_URL/jnlpJars/jenkins-cli.jar

# Wait for Jenkins to be ready
echo "Waiting for Jenkins to be ready..."
sleep 30

# Get initial admin password
ADMIN_PASSWORD=$(docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "password_not_found")

if [ "$ADMIN_PASSWORD" = "password_not_found" ]; then
    echo "Could not get admin password. Please get it manually from Jenkins UI."
    echo "Access http://localhost:8081 and complete setup first."
    exit 1
fi

echo "Admin password: $ADMIN_PASSWORD"

# Create devop job
echo "Creating devop job..."
cat > devop-job.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <description>Build and deploy the self-healing web server</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.92">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.10.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>.</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

java -jar jenkins-cli.jar -s $JENKINS_URL -auth $JENKINS_USER:$ADMIN_PASSWORD create-job devop < devop-job.xml

# Create heal job
echo "Creating heal job..."
cat > heal-job.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <description>Run self-healing operations</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.92">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.10.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>.</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile.heal</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

java -jar jenkins-cli.jar -s $JENKINS_URL -auth $JENKINS_USER:$ADMIN_PASSWORD create-job heal < heal-job.xml

echo "Jobs created successfully!"
echo "You can now trigger builds:"
echo "- devop job: Builds and deploys the system"
echo "- heal job: Runs healing operations"

# Cleanup
rm -f jenkins-cli.jar devop-job.xml heal-job.xml