#cloud-config

# Update system and install packages
runcmd:
  - yum update -y
  - yum install -y wget unzip curl jq htop awslogs

  # Install Nomad
  - cd /tmp
  - wget https://releases.hashicorp.com/nomad/1.6.2/nomad_1.6.2_linux_amd64.zip
  - unzip nomad_1.6.2_linux_amd64.zip
  - mv nomad /usr/local/bin/
  - chmod +x /usr/local/bin/nomad

  # Install Consul
  - wget https://releases.hashicorp.com/consul/1.16.2/consul_1.16.2_linux_amd64.zip
  - unzip consul_1.16.2_linux_amd64.zip
  - mv consul /usr/local/bin/
  - chmod +x /usr/local/bin/consul

  # Create nomad user and directories
  - useradd --system --home /etc/nomad.d --shell /bin/false nomad
  - mkdir -p /etc/nomad.d /opt/nomad/data /var/log/nomad /opt/consul/data /var/log/consul
  - chown -R nomad:nomad /etc/nomad.d /opt/nomad /var/log/nomad /opt/consul /var/log/consul

  # Get instance metadata
  - PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

  # Configure CloudWatch Logs
  - echo "[general]" > /etc/awslogs/awslogs.conf
  - echo "state_file = /var/lib/awslogs/agent-state" >> /etc/awslogs/awslogs.conf
  - echo "" >> /etc/awslogs/awslogs.conf
  - echo "[${log_group_name}]" >> /etc/awslogs/awslogs.conf
  - echo "file = /var/log/nomad/nomad.log" >> /etc/awslogs/awslogs.conf
  - echo "log_group_name = ${log_group_name}" >> /etc/awslogs/awslogs.conf
  - echo "log_stream_name = {instance_id}" >> /etc/awslogs/awslogs.conf
  - echo "datetime_format = %Y-%m-%d %H:%M:%S" >> /etc/awslogs/awslogs.conf

  - echo "[default]" > /etc/awslogs/awscli.conf
  - echo "region = ${region}" >> /etc/awslogs/awscli.conf

  - systemctl start awslogsd
  - systemctl enable awslogsd

  # Generate Nomad server configuration
  - |
    cat > /etc/nomad.d/nomad.hcl << 'EOF'
# Nomad server configuration
data_dir = "/opt/nomad/data"
log_level = "INFO"
log_file = "/var/log/nomad/nomad.log"

server {
  enabled = true
  bootstrap_expect = 3
  retry_join = ["provider=aws tag_key=Type tag_value=nomad-server region=us-west-2"]
  raft_multiplier = 1
  raft_snapshot_interval = "30s"
  raft_snapshot_threshold = 16384
  raft_trailing_logs = 10000
  heartbeat_grace = "30s"
  min_heartbeat_telemetry = "1m"
  max_heartbeat_telemetry = "24h"
}

client {
  enabled = false
}

consul {
  address = "127.0.0.1:8500"
  service_registration {
    enabled = true
  }
}

telemetry {
  prometheus_metrics = true
  disable_hostname = true
  collection_interval = "30s"
}

addresses {
  http = "0.0.0.0"
  rpc  = "0.0.0.0"
  serf = "0.0.0.0"
}

advertise {
  http = "PRIVATE_IP_PLACEHOLDER:4646"
  rpc  = "PRIVATE_IP_PLACEHOLDER:4647"
  serf = "PRIVATE_IP_PLACEHOLDER:4648"
}

ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

ui {
  enabled = true
  consul {
    ui_url = "http://127.0.0.1:8500/ui"
  }
}
EOF

  # Generate Consul server configuration
  - |
    cat > /etc/consul.d/consul.hcl << 'EOF'
# Consul server configuration
data_dir = "/opt/consul/data"
server = true
bootstrap_expect = 3
retry_join = ["provider=aws tag_key=Type tag_value=nomad-server region=us-west-2"]

addresses {
  http = "0.0.0.0"
  https = "0.0.0.0"
  grpc = "0.0.0.0"
}

advertise_addr = "PRIVATE_IP_PLACEHOLDER"
advertise_addr_wan = "PRIVATE_IP_PLACEHOLDER"

ports {
  grpc = 8502
  http = 8500
  https = -1
  server = 8300
  serf_lan = 8301
  serf_wan = 8302
  sidecar_min_port = 21000
  sidecar_max_port = 21255
}

ui_config {
  enabled = true
}

connect {
  enabled = true
}

performance {
  raft_multiplier = 1
}

log_level = "INFO"
log_file = "/var/log/consul/consul.log"
log_rotate_duration = "24h"
log_rotate_max_files = 30

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}
EOF

  # Replace placeholders with actual IP
  - sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/g" /etc/nomad.d/nomad.hcl
  - sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/g" /etc/consul.d/consul.hcl

  # Create systemd services
  - |
    cat > /etc/systemd/system/consul.service << 'EOF'
[Unit]
Description=Consul
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=nomad
Group=nomad
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  - |
    cat > /etc/systemd/system/nomad.service << 'EOF'
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/
Requires=consul.service
After=consul.service

[Service]
Type=notify
User=nomad
Group=nomad
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  # Start services
  - systemctl daemon-reload
  - systemctl enable consul
  - systemctl enable nomad
  - systemctl start consul
  - sleep 10
  - systemctl start nomad
  - sleep 30

  # Health check
  - |
    if systemctl is-active --quiet nomad; then
      echo "Nomad server started successfully"
    else
      echo "Failed to start Nomad server"
      systemctl status nomad
      exit 1
    fi