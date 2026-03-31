# ---------------------------------------------------------------
# Key Pair AWS existant
# ---------------------------------------------------------------
data "aws_key_pair" "k6" {
  key_name = var.key_pair_name
}

# ---------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------
resource "aws_security_group" "k6" {
  name        = "${var.project_name}-${var.environment}-k6-sg"
  description = "Security group for k6 load testing instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-k6-sg"
  }
}

# ---------------------------------------------------------------
# AMI Ubuntu 24.04 LTS ARM64 (Canonical)
# ---------------------------------------------------------------
data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ---------------------------------------------------------------
# EC2 Instance k6
# ---------------------------------------------------------------
locals {
  load_test_script = <<-SCRIPT
import http from "k6/http";
import { sleep, check } from "k6";

export const options = {
  stages: [
    { duration: "15s", target: 50 },
    { duration: "1m", target: 5000 },
    { duration: "2m", target: 5000 },
    { duration: "1s", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<2000"],
    http_req_failed: ["rate<0.05"],
  },
};

const BASE_URL = __ENV.BASE_URL || "${var.base_url}";

const params = {
  headers: { "Connection": "keep-alive" },
};

export default function () {
  const res = http.get(`$${BASE_URL}/`, params);

  check(res, {
    "status is 200": (r) => r.status === 200,
    "response time < 2s": (r) => r.timings.duration < 2000,
  });

  sleep(1);
}
SCRIPT
}

resource "aws_instance" "k6" {
  ami                         = data.aws_ami.ubuntu_arm.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.k6.id]
  key_name                    = data.aws_key_pair.k6.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Mise à jour du système
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get upgrade -y

    # Tuning OS pour les tests de charge
    sysctl -w net.ipv4.ip_local_port_range="1024 65535"
    sysctl -w net.ipv4.tcp_tw_reuse=1
    sysctl -w net.core.somaxconn=65535
    echo "net.ipv4.ip_local_port_range=1024 65535" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_tw_reuse=1" >> /etc/sysctl.conf
    echo "net.core.somaxconn=65535" >> /etc/sysctl.conf

    # Installation de k6 (repo officiel Grafana, ARM64)
    apt-get install -y gnupg ca-certificates curl
    curl -fsSL https://dl.k6.io/key.gpg | gpg --dearmor -o /usr/share/keyrings/k6-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
      > /etc/apt/sources.list.d/k6.list
    apt-get update -y
    apt-get install -y k6 || (
      # Fallback : binaire arm64 direct
      curl -LO https://github.com/grafana/k6/releases/download/v0.55.0/k6-v0.55.0-linux-arm64.tar.gz
      tar -xzf k6-v0.55.0-linux-arm64.tar.gz
      mv k6-v0.55.0-linux-arm64/k6 /usr/local/bin/k6
      chmod +x /usr/local/bin/k6
    )

    # Création du script de test
    cat > /home/ubuntu/load_test.js <<'JSSCRIPT'
${local.load_test_script}
JSSCRIPT

    chown ubuntu:ubuntu /home/ubuntu/load_test.js

    # Script helper pour lancer le test facilement
    cat > /home/ubuntu/run_test.sh <<'RUNSCRIPT'
#!/bin/bash
BASE_URL="${var.base_url}"
echo "Lancement du test k6 sur $BASE_URL ..."
k6 run --env BASE_URL="$BASE_URL" /home/ubuntu/load_test.js 2>&1 | tee ~/k6_output.txt
RUNSCRIPT
    chmod +x /home/ubuntu/run_test.sh
    chown ubuntu:ubuntu /home/ubuntu/run_test.sh

    echo "Instance k6 prête. Connectez-vous et lancez : bash ~/run_test.sh" > /home/ubuntu/README.txt
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-k6-load-tester"
  }
}
