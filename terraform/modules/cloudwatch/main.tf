# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ec2/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = var.tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { "stat" = "Sum", "period" = 300 }],
            ["AWS/ApplicationELB", "TargetResponseTime", { "stat" = "Average", "period" = 300 }],
            [".", "HTTPCode_Target_2XX_Count", { "stat" = "Sum", "period" = 300 }],
            [".", "HTTPCode_Target_4XX_Count", { "stat" = "Sum", "period" = 300 }],
            [".", "HTTPCode_Target_5XX_Count", { "stat" = "Sum", "period" = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "ALB Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { "stat" = "Average", "period" = 300 }],
            [".", "NetworkIn", { "stat" = "Average", "period" = 300 }],
            [".", "NetworkOut", { "stat" = "Average", "period" = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "EC2 Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { "stat" = "Average", "period" = 300 }],
            [".", "DatabaseConnections", { "stat" = "Average", "period" = 300 }],
            [".", "FreeableMemory", { "stat" = "Average", "period" = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "RDS Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupDesiredCapacity", { "stat" = "Average", "period" = 300 }],
            [".", "GroupInServiceInstances", { "stat" = "Average", "period" = 300 }],
            [".", "GroupTotalInstances", { "stat" = "Average", "period" = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Auto Scaling Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0
  alarm_description   = "This metric monitors ALB response time"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors 5xx error rate"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  tags = var.tags
}
