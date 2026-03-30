# ──────────────────────────────────────────────
# PROVIDERS — connexion au cluster EKS
# (nécessaire pour créer les TargetGroupBindings)
# ──────────────────────────────────────────────

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
  }
}

# ──────────────────────────────────────────────
# SECURITY GROUP — ALB public
# ──────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ALB public"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# ──────────────────────────────────────────────
# APPLICATION LOAD BALANCER
# ──────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# ──────────────────────────────────────────────
# TARGET GROUPS
# Le tag eks:eks-cluster-name est OBLIGATOIRE
# pour que le contrôleur ELB d'EKS Auto Mode
# puisse enregistrer les pod IPs automatiquement.
# ──────────────────────────────────────────────

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-${var.environment}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/nginx-health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name                   = "${var.project_name}-${var.environment}-frontend-tg"
    environment            = var.environment
    managed-by             = "terraform"
    "eks:eks-cluster-name" = var.cluster_name
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.project_name}-${var.environment}-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name                   = "${var.project_name}-${var.environment}-grafana-tg"
    environment            = var.environment
    managed-by             = "terraform"
    "eks:eks-cluster-name" = var.cluster_name
  }
}

# ──────────────────────────────────────────────
# LISTENER — Port 80 with path-based routing
# ──────────────────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Route /grafana* to Grafana target group
resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }
}

# ──────────────────────────────────────────────
# SG RULES — autoriser ALB a joindre les pods
# ──────────────────────────────────────────────

resource "aws_security_group_rule" "allow_frontend_from_alb" {
  description              = "ALB to pod nginx-cache-proxy (80)"
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "allow_grafana_from_alb" {
  description              = "ALB to pod Grafana (3000)"
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.alb.id
}

# ──────────────────────────────────────────────
# TARGET GROUP BINDINGS (Kubernetes)
# Créés via Terraform pour éviter les ARN en dur.
# EKS Auto Mode enregistre/désenregistre auto
# les pod IPs grâce au tag eks:eks-cluster-name.
# ──────────────────────────────────────────────

resource "kubernetes_manifest" "frontend_tgb" {
  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "frontend-tgb"
      namespace = "default"
    }
    spec = {
      targetGroupARN = aws_lb_target_group.frontend.arn
      targetType     = "ip"
      serviceRef = {
        name = "nginx-cache-proxy"
        port = 80
      }
      networking = {
        ingress = [
          {
            from = [
              {
                securityGroup = {
                  groupID = aws_security_group.alb.id
                }
              }
            ]
            ports = [
              {
                port     = 80
                protocol = "TCP"
              }
            ]
          }
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "grafana_tgb" {
  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "grafana-tgb"
      namespace = "monitoring"
    }
    spec = {
      targetGroupARN = aws_lb_target_group.grafana.arn
      targetType     = "ip"
      serviceRef = {
        name = "kube-prometheus-stack-grafana"
        port = 80
      }
      networking = {
        ingress = [
          {
            from = [
              {
                securityGroup = {
                  groupID = aws_security_group.alb.id
                }
              }
            ]
            ports = [
              {
                port     = 3000
                protocol = "TCP"
              }
            ]
          }
        ]
      }
    }
  }
}
