########### CloudWatch Log Group ###########
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/logs"
  retention_in_days = 14
  tags = {
    Name = "app-logs"
  }
}

########### SNS Topic + Subscription ###########
resource "aws_sns_topic" "alerts" {
  name = "app-alerts-topic-${var.env_name}"
  tags = {
    Name  = "app-alerts"
    Stage = var.env_name
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

########### IAM Policy for CloudWatch Agent ###########
resource "aws_iam_policy" "cw_logs_policy" {
  name = "CWLogsPolicy-${var.env_name}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:SendCommand",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_cw_logs" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cw_logs_policy.arn
}

########### Metric Filter for ERROR / Exception ###########
resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "ErrorFilter-${var.env_name}"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "?ERROR ?Exception"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "AppLogs/${var.env_name}"
    value     = "1"
  }
}

########### CloudWatch Alarm ###########
resource "aws_cloudwatch_metric_alarm" "error_alarm" {
  alarm_name          = "AppErrorAlarm-${var.env_name}"
  alarm_description   = "Alarm when ERROR/Exception occurs in app logs"
  namespace           = aws_cloudwatch_log_metric_filter.errors.metric_transformation[0].namespace
  metric_name         = aws_cloudwatch_log_metric_filter.errors.metric_transformation[0].name
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  tags = {
    Name  = "AppErrorAlarm"
    Stage = var.env_name
  }
}
