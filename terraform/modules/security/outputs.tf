output "sg_bastion_id" {
  description = "ID du SG Bastion"
  value       = aws_security_group.sg_bastion.id
}

output "sg_web_id" {
  description = "ID du SG Web"
  value       = aws_security_group.sg_web.id
}

output "sg_app_id" {
  description = "ID du SG App"
  value       = aws_security_group.sg_app.id
}

output "sg_db_id" {
  description = "ID du SG DB"
  value       = aws_security_group.sg_db.id
}