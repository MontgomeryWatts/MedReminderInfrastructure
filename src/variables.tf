variable "aws_region" {
  type        = "string"
  default     = "us-east-1"
  description = "The AWS region to provision resources in"
}

variable "jobs" {
  type        = "list"
  description = "A list of job objects specifying what notifications should be sent"
}
