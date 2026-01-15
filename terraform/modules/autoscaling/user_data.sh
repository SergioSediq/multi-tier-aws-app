#!/bin/bash
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Create docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  app:
    image: ${docker_image}
    container_name: app
    restart: always
    ports:
      - "80:8080"
    environment:
      - DB_HOST=${db_endpoint}
      - DB_NAME=${db_name}
      - DB_USER=${db_username}
      - DB_PASSWORD=${db_password}
    logging:
      driver: "awslogs"
      options:
        awslogs-group: "/ec2/multi-tier-app"
        awslogs-region: us-east-1
        awslogs-stream-prefix: "app"
EOF

# Start application
docker-compose up -d

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "metrics": {
    "namespace": "MultiTierApp",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/ec2/multi-tier-app",
            "log_stream_name": "{instance_id}/messages"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

echo "Application deployment completed successfully"
