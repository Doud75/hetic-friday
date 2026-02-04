output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for CloudWatch alarms"
  value       = aws_sns_topic.alerts.name
}

output "nat_packets_drop_alarm_names" {
  description = "Names of the NAT Gateway packet drop alarms"
  value       = aws_cloudwatch_metric_alarm.nat_gateway_packets_drop[*].alarm_name
}

output "nat_port_error_alarm_names" {
  description = "Names of the NAT Gateway port allocation error alarms"
  value       = aws_cloudwatch_metric_alarm.nat_gateway_error_port_allocation[*].alarm_name
}
