#!/bin/bash

# EC2 Auto-Scaling Startup Script (User Data)
# This script runs automatically when a new EC2 instance starts
# It clones the repo, installs dependencies, and starts the faucet

set -e

# Configuration
REPO_URL="https://github.com/ritvikmahajan17/allora-faucet.git"
BRANCH="ritvik-changes"
APP_DIR="/opt/allora-faucet"
EVM_ENDPOINT="http://l1bc-demo-dev-chain-rpc-216332031.us-east-1.elb.amazonaws.com/"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/faucet-startup.log
}

log "🚀 Starting Allora Faucet auto-deployment..."

# Update system
log "📦 Updating system packages..."
yum update -y

# Install required packages
log "📦 Installing Git, Docker, Node.js..."
yum install -y git docker nodejs npm

# Start and enable Docker
log "🐳 Starting Docker service..."
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install AWS CLI
log "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# Clone the repository
log "📥 Cloning repository..."
if [ -d "$APP_DIR" ]; then
    rm -rf "$APP_DIR"
fi
git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"

# Create necessary directories
log "📁 Creating application directories..."
mkdir -p config/secret
touch faucet.db

# Set up environment variables
log "⚙️ Setting up environment..."
cat > .env << EOF
EVM_ENDPOINT=$EVM_ENDPOINT
RECAPTCHA_SITE_KEY=
RECAPTCHA_SECRET_KEY=
EOF

# Build Docker image
log "🏗️ Building Docker image..."
docker build -t allora-faucet:latest .

# Create systemd service for auto-restart
log "🔧 Creating systemd service..."
cat > /etc/systemd/system/allora-faucet.service << EOF
[Unit]
Description=Allora Faucet Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStartPre=-/usr/bin/docker stop allora-faucet
ExecStartPre=-/usr/bin/docker rm allora-faucet
ExecStart=/usr/bin/docker run -d \\
  --name allora-faucet \\
  --restart unless-stopped \\
  -p 8000:8000 \\
  -e EVM_ENDPOINT=$EVM_ENDPOINT \\
  -v $APP_DIR/config/secret:/app/config/secret:ro \\
  -v $APP_DIR/faucet.db:/app/faucet.db \\
  allora-faucet:latest
ExecStop=/usr/bin/docker stop allora-faucet
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
log "🚀 Starting Allora Faucet service..."
systemctl daemon-reload
systemctl enable allora-faucet
systemctl start allora-faucet

# Wait a moment and check status
sleep 10

# Verify deployment
if docker ps --filter "name=allora-faucet" --format "table {{.Names}}\t{{.Status}}" | grep -q "allora-faucet"; then
    INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    log "✅ Faucet deployed successfully!"
    log "🌐 Access URL: http://$INSTANCE_IP:8000"
    log "📋 Container status:"
    docker ps --filter "name=allora-faucet" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a /var/log/faucet-startup.log
    
    # Send notification to CloudWatch Logs (optional)
    yum install -y awslogs
    echo "Allora Faucet deployed successfully on $INSTANCE_IP" | logger -t allora-faucet
    
else
    log "❌ Deployment failed! Check Docker logs:"
    docker logs allora-faucet | tee -a /var/log/faucet-startup.log
    exit 1
fi

log "🎉 Auto-deployment complete!"

# Create a simple health check script
cat > /usr/local/bin/faucet-health-check.sh << 'EOF'
#!/bin/bash
if ! docker ps --filter "name=allora-faucet" --format "{{.Names}}" | grep -q "allora-faucet"; then
    echo "Faucet container not running, restarting..."
    systemctl restart allora-faucet
fi
EOF

chmod +x /usr/local/bin/faucet-health-check.sh

# Add health check to cron (every 5 minutes)
echo "*/5 * * * * root /usr/local/bin/faucet-health-check.sh" >> /etc/crontab

log "💚 Health monitoring enabled!"