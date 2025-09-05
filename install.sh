#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

echo "✅ Updating instance..."
sudo yum update -y

echo "☕ Installing Java 21..."
sudo dnf install java-21-amazon-corretto -y

echo "📦 Installing Maven..."
sudo yum install -y maven

echo "🔧 Installing Git..."
sudo yum install -y git

echo "📥 Cloning GitHub repo..."
cd /home/ec2-user
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops.git

cd test-repo-for-devops || {
  echo "❌ Failed to enter project directory"
  exit 1
}

echo "🏗️  Building the project with Maven..."
mvn clean package

echo "🚀 Running the app in background..."
nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar > app.log 2>&1 &

echo "⏳ Waiting for the app to start..."
sleep 10

echo "🌐 Fetching public IP..."
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "🔎 Testing the app at http://$PUBLIC_IP:8080/hello ..."
curl --retry 3 --connect-timeout 5 http://$PUBLIC_IP:8080/hello || echo "⚠️ App did not respond as expected."

echo "✅ Setup complete!"

# --- CloudWatch Agent setup ---
echo "☁️ Installing and configuring CloudWatch Agent..."

# Install CloudWatch Agent (works for both yum and dnf)
if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y amazon-cloudwatch-agent
else
  sudo yum install -y amazon-cloudwatch-agent
fi

# Ensure app log file exists and correct ownership
sudo mkdir -p /home/ec2-user
sudo touch /home/ec2-user/app.log
sudo chown ec2-user:ec2-user /home/ec2-user/app.log
sudo chmod 644 /home/ec2-user/app.log

# Write CloudWatch Agent configuration
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo bash -c 'cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ec2-user/app.log",
            "log_group_name": "/app/logs",
            "log_stream_name": "{instance_id}-app-log",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          }
        ]
      }
    }
  }
}
EOF'

# Start CloudWatch Agent with the config
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "☁️ CloudWatch Agent started and streaming logs."
# --- End CloudWatch Agent setup ---
