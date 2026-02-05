# SNS Topic
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Alarm pour tester le NAT Gateway Packet Drops
resource "aws_cloudwatch_metric_alarm" "nat_gateway_packets_drop" {
  count = length(var.nat_gateway_ids)

  alarm_name          = "${var.project_name}-${var.environment}-nat-packets-drop-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "PacketsDropCount"
  namespace           = "AWS/NATGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Alert when NAT Gateway ${count.index + 1} drops packets"
  treat_missing_data  = "notBreaching"

  dimensions = {
    NatGatewayId = var.nat_gateway_ids[count.index]
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-packets-drop-${count.index + 1}"
    Environment = var.environment
  }
}

# CloudWatch Alarm pour tester le NAT Gateway Connection Errors
resource "aws_cloudwatch_metric_alarm" "nat_gateway_error_port_allocation" {
  count = length(var.nat_gateway_ids)

  alarm_name          = "${var.project_name}-${var.environment}-nat-port-allocation-errors-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ErrorPortAllocation"
  namespace           = "AWS/NATGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when NAT Gateway ${count.index + 1} has port allocation errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    NatGatewayId = var.nat_gateway_ids[count.index]
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-port-errors-${count.index + 1}"
    Environment = var.environment
  }
}
