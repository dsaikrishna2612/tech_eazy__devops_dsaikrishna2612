output "ec2_public_ip" {
  value = aws_instance.server.public_ip
}

output "ec2_instance_id" {
  value = aws_instance.server.id
}


output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "cw_alarm_name" {
  value = aws_cloudwatch_metric_alarm.error_alarm.alarm_name
}
