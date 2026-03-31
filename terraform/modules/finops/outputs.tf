output "monthly_budget_id" {
  description = "ID du budget mensuel total"
  value       = aws_budgets_budget.monthly_total.id
}

output "eks_budget_id" {
  description = "ID du budget EKS"
  value       = aws_budgets_budget.eks_budget.id
}

output "ec2_budget_id" {
  description = "ID du budget EC2"
  value       = aws_budgets_budget.ec2_budget.id
}

output "rds_budget_id" {
  description = "ID du budget RDS"
  value       = aws_budgets_budget.rds_budget.id
}
