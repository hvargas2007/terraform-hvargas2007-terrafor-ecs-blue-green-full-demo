### Global variables:
variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {
    Service   = "ecs-blue-gree"
    CreatedBy = "JManzur - https://jmanzur.com"
    Env       = "POC"
  }
}

variable "name_prefix" {
  type        = string
  description = "[REQUIRED] Used to name and tag resources."
}

variable "environment" {
  type        = string
  description = "[REQUIRED] Used to name and tag resources."
}

variable "name_suffix" {
  type        = string
  description = "[OPTIONAL] Used to name and tag global resources."
  default     = ""
}