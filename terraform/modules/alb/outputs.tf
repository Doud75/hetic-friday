output "alb_dns_name" {
  description = "DNS public de l'ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN de l'ALB"
  value       = aws_lb.main.arn
}

output "frontend_target_group_arn" {
  description = "ARN du Target Group frontend (utilisé par le CD pour enregistrer les pods)"
  value       = aws_lb_target_group.frontend.arn
}

output "grafana_target_group_arn" {
  description = "ARN du Target Group Grafana (utilisé par le CD pour enregistrer les pods)"
  value       = aws_lb_target_group.grafana.arn
}

output "alb_security_group_id" {
  description = "ID du security group de l'ALB"
  value       = aws_security_group.alb.id
}

output "waf_web_acl_arn" {
  description = "ARN du WAF Web ACL associé à l'ALB"
  value       = aws_wafv2_web_acl.main.arn
}
