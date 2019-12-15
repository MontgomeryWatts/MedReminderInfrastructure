variable "aws_region" {
  type        = "string"
  default     = "us-east-1"
  description = "The AWS region to provision resources in"
}

variable "phone_numbers" {
  type = "list"
  description = "The phone numbers to subscribe to receive SMS messages"
}
