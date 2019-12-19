provider "aws" {
  version = "~> 2.0"
  profile = "terraform-user"
  region  = "${var.aws_region}"
}

locals {
  phone_numbers = "${distinct([for job in var.jobs : job.phone_number])}"
  schedules     = "${distinct([for job in var.jobs : job.schedule])}"
}

resource "aws_sns_topic" "sns" {
  name = "med-reminder-topic"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "med-reminder-lambdas"
}

resource "aws_lambda_function" "lambda" {
  s3_bucket     = "${aws_s3_bucket.bucket.id}"
  s3_key        = "send-reminder-text.zip"
  function_name = "med-reminder-lambda"
  memory_size   = "128"
  handler       = "main"
  runtime       = "go1.x"
  role          = "${aws_iam_role.lambda_role.arn}"
  timeout       = "5"

  environment {
    variables = {
      TOPIC_ARN = "${aws_sns_topic.sns.arn}"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "med-reminder-lambda-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "role_execution_policy" {
  role   = "${aws_iam_role.lambda_role.id}"
  policy = "${data.aws_iam_policy_document.role_execution_policy_document.json}"
}


data "aws_iam_policy_document" "role_execution_policy_document" {
  version = "2012-10-17"
  statement {
    sid    = "AllowLogs"
    effect = "Allow"
    actions = ["logs:CreateLogGroup",
      "logs:CreateLogStream",
    "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

data "aws_iam_policy_document" "topic_policy_document" {
  version = "2012-10-17"
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = ["${aws_sns_topic.sns.arn}"]
    principals {
      type        = "AWS"
      identifiers = ["${aws_iam_role.lambda_role.arn}"]
    }
  }
}

resource "aws_sns_topic_policy" "topic_policy" {
  arn    = "${aws_sns_topic.sns.arn}"
  policy = "${data.aws_iam_policy_document.topic_policy_document.json}"
}

## Resources that depend on jobs below

resource "aws_sns_topic_subscription" "sms_subscription" {
  count = "${length(local.phone_numbers)}"

  topic_arn     = "${aws_sns_topic.sns.arn}"
  protocol      = "sms"
  endpoint      = "${element(local.phone_numbers, count.index)}"
  filter_policy = "${jsonencode(map("endpoint", list(element(local.phone_numbers, count.index))))}"
}

resource "aws_cloudwatch_event_rule" "event_rule" {
  count               = "${length(local.schedules)}"
  schedule_expression = "${element(local.schedules, count.index)}"
  name                = "${sha256(element(local.schedules, count.index))}"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  depends_on = [aws_cloudwatch_event_rule.event_rule]
  count      = "${length(var.jobs)}"

  rule  = "${sha256(element(var.jobs, count.index).schedule)}"
  arn   = "${aws_lambda_function.lambda.arn}"
  input = "${jsonencode(map("message", "${element(var.jobs, count.index).message}", "phoneNumber", "${element(var.jobs, count.index).phone_number}"))}"
}


resource "aws_lambda_permission" "with_cloud_watch_event" {
  count         = "${length(aws_cloudwatch_event_rule.event_rule)}"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.event_rule[count.index].arn}"
}
