# outputs.tf
output "target_groups_a_arn" {
  value       = { for k, v in aws_lb_target_group.a : k => v.arn }
  description = "Target Groups A ARN"
}

output "target_groups_b_arn" {
  value       = { for k, v in aws_lb_target_group.b : k => v.arn }
  description = "Target Groups B ARN"
}