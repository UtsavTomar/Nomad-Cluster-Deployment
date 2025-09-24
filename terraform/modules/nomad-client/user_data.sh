#cloud-config

# Update system and install packages
runcmd:
  - yum update -y
  - yum install -y wget unzip curl jq htop awslogs docker git

  # Start and enable Docker
  - systemctl start docker
  - systemctl enable docker
  - usermod -a -G docker ec2-user

  # Install Nomad
  - cd /tmp
  - wget https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
  - unzip nomad_${NOMAD_VERSION}_linux_amd64.zip
  - mv nomad /usr/local/bin/
  - chmod +x /usr/local/bin/nomad

  # Install Consul
  - wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
  - unzip consul_${CONSUL_VERSION}_linux_amd64.zip
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

  # Generate Nomad client configuration
  - |
    cat > /etc/nomad.d/nomad.hcl << 'EOF'
# Nomad client configuration
data_dir = "/opt/nomad/data"
log_level = "INFO"
log_file = "/var/log/nomad/nomad.log"

server {
  enabled = false
}

client {
  enabled = true
  servers = ["${nomad_servers}"]
  node_class = "web"
  meta {
    environment = "production"
    datacenter = "${region}"
  }
  cpu_total_compute = 1000
  memory_total_mb = 1024
  network_interface = "eth0"
  
  chroot_env {
    "/bin" = "/bin"
    "/lib" = "/lib"
    "/lib64" = "/lib64"
    "/usr" = "/usr"
    "/sbin" = "/sbin"
  }
  
  options {
    "docker.privileged.enabled" = "true"
    "docker.volumes.enabled" = "true"
    "docker.cleanup.image" = "true"
  }
  
  host_volume "docker-sock" {
    path = "/var/run/docker.sock"
    read_only = true
  }
  
  host_volume "tmp" {
    path = "/tmp"
    read_only = false
  }
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

  # Replace placeholder with actual IP
  - sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/g" /etc/nomad.d/nomad.hcl

  # Generate Consul client configuration
  - |
    cat > /etc/consul.d/consul.hcl << 'EOF'
# Consul client configuration
data_dir = "/opt/consul/data"
server = false
retry_join = ["provider=aws tag_key=Type tag_value=nomad-server region=${region}"]

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
  server = -1
  serf_lan = 8301
  serf_wan = -1
  sidecar_min_port = 21000
  sidecar_max_port = 21255
}

ui_config {
  enabled = true
}

connect {
  enabled = true
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

  # Replace placeholder with actual IP
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
      echo "Nomad client started successfully"
    else
      echo "Failed to start Nomad client"
      systemctl status nomad
      exit 1
    fi
