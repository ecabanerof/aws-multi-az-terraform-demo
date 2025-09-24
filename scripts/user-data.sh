#!/bin/bash
# scripts/user-data.sh - Demo Infrastructure User Data Script

set -e

# Variables
HOSTNAME="${hostname}"
SERVER_TYPE="${server_type}"
ENVIRONMENT="${environment}"
DEMO_USER="demo-user"

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "=== Demo Infrastructure User Data Script ==="
echo "=========================================="
echo "Hostname: $HOSTNAME"
echo "Server Type: $SERVER_TYPE"
echo "Environment: $ENVIRONMENT"
echo "Start time: $(date)"

# Update system
echo "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install essential packages
echo "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    vim \
    htop \
    git \
    unzip \
    tree \
    net-tools \
    tcpdump \
    jq \
    awscli \
    docker.io \
    docker-compose \
    nginx \
    nodejs \
    npm \
    python3 \
    python3-pip \
    fail2ban \
    ufw

# Set hostname
echo "Setting hostname to $HOSTNAME..."
hostnamectl set-hostname $HOSTNAME
echo "127.0.1.1 $HOSTNAME" >> /etc/hosts

# Create demo user
echo "Creating demo user..."
if ! id "$DEMO_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$DEMO_USER"
    echo "$DEMO_USER:DemoPassword123!" | chpasswd
    usermod -aG sudo,docker "$DEMO_USER"
    
    # Setup SSH directory
    mkdir -p "/home/$DEMO_USER/.ssh"
    chmod 700 "/home/$DEMO_USER/.ssh"
    chown "$DEMO_USER:$DEMO_USER" "/home/$DEMO_USER/.ssh"
fi

# Configure Docker
echo "Configuring Docker..."
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Server-specific configurations
case "$SERVER_TYPE" in
    "web")
        echo "Configuring web server..."
        systemctl start nginx
        systemctl enable nginx
        
        # Create demo web content
        cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Demo Infrastructure - $HOSTNAME</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .content { margin-top: 20px; }
        .info-box { background: #f8f9fa; border-left: 4px solid #007bff; padding: 15px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Demo Infrastructure</h1>
        <h2>Server: $HOSTNAME</h2>
    </div>
    
    <div class="content">
        <div class="info-box">
            <strong>Server Type:</strong> $SERVER_TYPE
        </div>
        <div class="info-box">
            <strong>Environment:</strong> $ENVIRONMENT
        </div>
        <div class="info-box">
            <strong>Deployment Time:</strong> $(date)
        </div>
        <div class="info-box">
            <strong>Purpose:</strong> AWS Infrastructure Demonstration
        </div>
        
        <h3>Server Information</h3>
        <ul>
            <li>Operating System: Ubuntu 24.04 LTS</li>
            <li>Web Server: Nginx</li>
            <li>Docker: Enabled</li>
            <li>Security: CIS Hardened</li>
        </ul>
        
        <h3>Available Services</h3>
        <ul>
            <li><a href="/health">Health Check</a></li>
            <li><a href="/info">System Information</a></li>
            <li><a href="/metrics">Metrics (Prometheus)</a></li>
        </ul>
    </div>
</body>
</html>
EOF

        # Create health check endpoint
        mkdir -p /var/www/html/health
        cat > /var/www/html/health/index.html << EOF
{
  "status": "healthy",
  "server": "$HOSTNAME",
  "type": "$SERVER_TYPE",
  "timestamp": "$(date -Iseconds)",
  "uptime": "$(uptime -p)"
}
EOF

        ;;
        
    "app")
        echo "Configuring application server..."
        
        # Install Node.js application dependencies
        npm install -g pm2 express
        
        # Create demo application
        mkdir -p /opt/demo-app
        cat > /opt/demo-app/app.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        server: process.env.HOSTNAME || 'unknown',
        type: 'application',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Info endpoint
app.get('/info', (req, res) => {
    res.json({
        name: 'Demo Application Server',
        version: '1.0.0',
        environment: process.env.ENVIRONMENT || 'demo',
        node_version: process.version,
        platform: process.platform
    });
});

// API endpoints
app.get('/api/data', (req, res) => {
    res.json({
        message: 'Demo data from application server',
        data: [
            { id: 1, name: 'Item 1', status: 'active' },
            { id: 2, name: 'Item 2', status: 'pending' },
            { id: 3, name: 'Item 3', status: 'completed' }
        ]
    });
});

app.listen(port, () => {
    console.log(`Demo app listening at http://localhost:${port}`);
});
EOF

        # Create PM2 ecosystem file
        cat > /opt/demo-app/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'demo-app',
    script: '/opt/demo-app/app.js',
    instances: 2,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      HOSTNAME: '$HOSTNAME',
      ENVIRONMENT: '$ENVIRONMENT'
    }
  }]
};
EOF

        # Start application with PM2
        cd /opt/demo-app
        npm install express
        su - $DEMO_USER -c "cd /opt/demo-app && pm2 start ecosystem.config.js"
        su - $DEMO_USER -c "pm2 save"
        su - $DEMO_USER -c "pm2 startup"
        
        ;;
        
    "database")
        echo "Configuring database server..."
        
        # Install and configure MySQL
        apt-get install -y mysql-server
        systemctl start mysql
        systemctl enable mysql
        
        # Secure MySQL installation (automated)
        mysql -e "DELETE FROM mysql.user WHERE User='';"
        mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        mysql -e "DROP DATABASE IF EXISTS test;"
        mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
        mysql -e "FLUSH PRIVILEGES;"
        
        # Create demo database and user
        mysql -e "CREATE DATABASE demo_db;"
        mysql -e "CREATE USER 'demo_user'@'%' IDENTIFIED BY 'DemoDBPassword123!';"
        mysql -e "GRANT ALL PRIVILEGES ON demo_db.* TO 'demo_user'@'%';"
        mysql -e "FLUSH PRIVILEGES;"
        
        # Create sample table with data
        mysql demo_db << 'EOF'
CREATE TABLE demo_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO demo_table (name, description) VALUES
('Demo Item 1', 'First demo item for testing'),
('Demo Item 2', 'Second demo item for testing'),
('Demo Item 3', 'Third demo item for testing');
EOF

        ;;
        
    "vpn")
        echo "Configuring VPN server..."
        # VPN configuration will be handled by Ansible
        
        # Prepare for OpenVPN installation
        apt-get install -y easy-rsa iptables-persistent
        
        # Enable IP forwarding
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
        sysctl -p
        
        ;;
        
    "monitoring")
        echo "Configuring monitoring server..."
        
        # Install Prometheus
        wget https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
        tar -xzf prometheus-2.40.0.linux-amd64.tar.gz
        mv prometheus-2.40.0.linux-amd64 /opt/prometheus
        
        # Create Prometheus user
        useradd --no-create-home --shell /bin/false prometheus
        chown -R prometheus:prometheus /opt/prometheus
        
        # Create Prometheus configuration
        cat > /opt/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
      
  - job_name: 'demo-infrastructure'
    static_configs:
      - targets: 
        - '172.16.10.10:9100'  # Web server AZ1
        - '172.16.20.10:9100'  # Web server AZ2
        - '172.16.10.20:9100'  # App server
        - '172.16.20.20:9100'  # DB server
EOF

        # Create systemd service for Prometheus
        cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  --web.console.templates=/opt/prometheus/consoles \
  --web.console.libraries=/opt/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl start prometheus
        systemctl enable prometheus
        
        # Install Grafana
        wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
        echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
        apt-get update -y
        apt-get install -y grafana
        
        systemctl start grafana-server
        systemctl enable grafana-server
        
        ;;
esac

# Install Node Exporter for monitoring
echo "Installing Node Exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.4.0/node_exporter-1.4.0.linux-amd64.tar.gz
tar -xzf node_exporter-1.4.0.linux-amd64.tar.gz
mv node_exporter-1.4.0.linux-amd64/node_exporter /usr/local/bin/
useradd --no-create-home --shell /bin/false node_exporter

# Create Node Exporter systemd service
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Configure firewall
echo "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow ssh

# Allow internal network communication
ufw allow from 172.16.0.0/16

# Server-specific firewall rules
case "$SERVER_TYPE" in
    "web")
        ufw allow 80/tcp
        ufw allow 443/tcp
        ;;
    "app")
        ufw allow 3000/tcp
        ;;
    "database")
        ufw allow 3306/tcp
        ;;
    "vpn")
        ufw allow 1194/udp
        ;;
    "monitoring")
        ufw allow 9090/tcp  # Prometheus
        ufw allow 3000/tcp  # Grafana
        ;;
esac

# Allow Node Exporter
ufw allow 9100/tcp

ufw --force enable

# Create system information script
cat > /usr/local/bin/demo-info << EOF
#!/bin/bash
echo "=========================================="
echo "=== Demo Infrastructure Server Info ==="
echo "=========================================="
echo "Hostname: \$(hostname)"
echo "Server Type: $SERVER_TYPE"
echo "Environment: $ENVIRONMENT"
echo "IP Address: \$(hostname -I | awk '{print \$1}')"
echo "OS: \$(lsb_release -d | cut -f2)"
echo "Kernel: \$(uname -r)"
echo "Uptime: \$(uptime -p)"
echo "Load: \$(uptime | awk -F'load average:' '{print \$2}')"
echo "Memory: \$(free -h | grep '^Mem:' | awk '{print \$3 "/" \$2}')"
echo "Disk: \$(df -h / | tail -1 | awk '{print \$3 "/" \$2 " (" \$5 " used)"}')"
echo
echo "=== Services Status ==="
case "$SERVER_TYPE" in
    "web")
        echo "Nginx: \$(systemctl is-active nginx)"
        ;;
    "app")
        echo "Demo App: \$(su - $DEMO_USER -c 'pm2 list | grep demo-app' | awk '{print \$12}')"
        ;;
    "database")
        echo "MySQL: \$(systemctl is-active mysql)"
        ;;
    "monitoring")
        echo "Prometheus: \$(systemctl is-active prometheus)"
        echo "Grafana: \$(systemctl is-active grafana-server)"
        ;;
esac
echo "Node Exporter: \$(systemctl is-active node_exporter)"
echo "UFW Firewall: \$(ufw status | grep Status | awk '{print \$2}')"
echo "=========================================="
EOF

chmod +x /usr/local/bin/demo-info

# Run hardening script if available
if [[ -f "/tmp/bootstrap.sh" ]]; then
    echo "Running hardening script..."
    bash /tmp/bootstrap.sh "$ENVIRONMENT" "$SERVER_TYPE"
fi

# Create completion marker
touch /var/log/user-data-complete

echo "=========================================="
echo "=== User Data Script Completed ==="
echo "=========================================="
echo "Completion time: $(date)"
echo "Server: $HOSTNAME ($SERVER_TYPE)"
echo "Environment: $ENVIRONMENT"
echo "Run 'demo-info' for system information"

# Final system information
/usr/local/bin/demo-info