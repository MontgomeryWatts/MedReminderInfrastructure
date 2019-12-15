provider "aws" {
  version = "~> 2.0"
  profile = "terraform-user"
  region  = "${var.aws_region}"
}

resource "aws_sns_topic" "sns" {
  name = "med-reminder-topic"
}