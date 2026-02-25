# ============================================================================
# IAM Role for Lex Bot
# ============================================================================
# Creates an IAM role that allows AWS Lex service to perform actions on behalf
# of the bot. This role is required for the bot to function.

data "aws_iam_policy_document" "lex_trust_relationship" {
  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["lexv2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lex_role" {
  name = "${local.bot_name}-lex-role"
  assume_role_policy = data.aws_iam_policy_document.lex_trust_relationship.json
  tags = var.tags
  max_session_duration = 43200
}

# ============================================================================
# IAM Policy Attachment
# ============================================================================
# Attaches the AWS managed policy for Lex full access to the bot's IAM role.
# This provides necessary permissions for bot operations.

# resource "aws_iam_role_policy_attachment" "lex_basic" {
#   role       = aws_iam_role.lex_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonLexFullAccess"
# }

data "aws_iam_policy_document" "allow_synthesize_speech"{
  statement {
    sid = "LexActions"
    effect = "Allow"
    actions = [
      "polly:SynthesizeSpeech"
    ]
    resources = [ 
      "arn:aws:polly:${var.aws_region}:${var.aws_account_id}:lexicon/*"
    ]
 }
}

resource "aws_iam_policy" "allow_synthesize_speech" {
  name = "${local.bot_name}-allow-synthesize-speech-policy"
  policy = data.aws_iam_policy_document.allow_synthesize_speech.json
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "allow_synthesize_speech" {
  role       = aws_iam_role.lex_role.name
  policy_arn = aws_iam_policy.allow_synthesize_speech.arn
}

data "aws_iam_policy_document" "allow_lex_cloudwatch_logging"{
  statement {
    sid = "AllowLexCloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup"
    ]
    resources = [ 
      "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lex/*"
    ]
 }
}

resource "aws_iam_policy" "allow_lex_cloudwatch_logging" {
  name = "${local.bot_name}-allow-lex-cloudwatch-logging-policy"
  policy = data.aws_iam_policy_document.allow_lex_cloudwatch_logging.json
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "allow_lex_cloudwatch_logging" {
  role       = aws_iam_role.lex_role.name
  policy_arn = aws_iam_policy.allow_lex_cloudwatch_logging.arn
}

data "aws_iam_policy_document" "allow_invoke_lambdas"{
  count = length(var.lambda_arns) > 0 ? 1 : 0

  statement {
    sid = "AllowInvokeLambdas"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = values(var.lambda_arns)
 }
}

resource "aws_iam_policy" "allow_invoke_lambdas" {
  count  = length(var.lambda_arns) > 0 ? 1 : 0
  name   = "${local.bot_name}-allow-invoke-lambdas-policy"
  policy = data.aws_iam_policy_document.allow_invoke_lambdas[0].json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "allow_invoke_lambdas" {
  count      = length(var.lambda_arns) > 0 ? 1 : 0
  role       = aws_iam_role.lex_role.name
  policy_arn = aws_iam_policy.allow_invoke_lambdas[0].arn
}

# data "aws_iam_policy_document" "allow_invoke_lambda_function"{
#   statement {
#     sid = "AllowLexCloudWatchLogging"
#     effect = "Allow"
#     actions = [
#       "lambda: InvokeFunction"
#     ]
#     resources = [ 
#       "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lex/*"
#     ]
#  }
# }

# resource "aws_iam_policy" "allow_invoke_lambda_function" {
#   name = "${local.bot_name}-allow-invoke-lambda-function-policy"
#   policy = data.aws_iam_policy_document.allow_invoke_lambda_function.json
#   tags = local.tags
# }

# resource "aws_iam_role_policy_attachment" "allow_invoke_lambda_function" {
#   role       = aws_iam_role.lex_role.name
#   policy_arn = aws_iam_policy.allow_invoke_lambda_function.arn
# }