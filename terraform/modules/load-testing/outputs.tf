output "instance_id" {
  description = "ID de l'instance EC2 k6"
  value       = aws_instance.k6.id
}

output "public_ip" {
  description = "IP publique de l'instance k6"
  value       = aws_instance.k6.public_ip
}

output "public_dns" {
  description = "DNS public de l'instance k6"
  value       = aws_instance.k6.public_dns
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à l'instance (après avoir récupéré la clé)"
  value       = "ssh -i /tmp/k6-key.pem ubuntu@${aws_instance.k6.public_ip}"
}

output "key_pair_name" {
  description = "Nom du key pair AWS utilisé"
  value       = data.aws_key_pair.k6.key_name
}
