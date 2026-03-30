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

# ──────────────────────────────────────────────
# WAF v2 — Web Application Firewall
# Protège l'ALB avec des règles managées AWS
# et un rate-limiting par IP.
# ──────────────────────────────────────────────

# IP Set pour les adresses whitelistées (load test k6, équipe...)
# Ces IPs bypasse le rate limiting mais PAS les règles de sécurité.
resource "aws_wafv2_ip_set" "whitelist" {
  name               = "${var.project_name}-${var.environment}-whitelist"
  description        = "Whitelisted IPs for load testing"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.waf_whitelisted_ips

  tags = {
    Name        = "${var.project_name}-${var.environment}-whitelist"
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-${var.environment}-waf"
  description = "WAF for ALB ${var.project_name}-${var.environment}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # ── Règle 0 : Whitelist (bypass rate-limit) ──
  # Les IPs whitelistées passent le rate-limit mais restent
  # soumises aux règles de sécurité (XSS, SQLi, etc.)
  dynamic "rule" {
    for_each = length(var.waf_whitelisted_ips) > 0 ? [1] : []
    content {
      name     = "whitelist-allow"
      priority = 0

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelist.arn
        }
      }

      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-whitelist"
      }
    }
  }

  # ── Règle 1 : Rate Limiting ──
  # Bloque les IPs qui envoient plus de 2000 requêtes en 5 minutes
  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-rate-limit"
    }
  }

  # ── Règle 2 : AWS Core Rule Set (CRS) ──
  # Protège contre les attaques web courantes (XSS, traversal, injections...)
  rule {
    name     = "aws-managed-common"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-common-rules"
    }
  }

  # ── Règle 3 : Known Bad Inputs ──
  # Bloque les requêtes connues comme malveillantes (Log4j, etc.)
  rule {
    name     = "aws-managed-bad-inputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-bad-inputs"
    }
  }

  # ── Règle 4 : SQL Injection ──
  rule {
    name     = "aws-managed-sqli"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-sqli"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-waf"
    environment = var.environment
    managed-by  = "terraform"
  }
}

# ── Association WAF → ALB ──
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
