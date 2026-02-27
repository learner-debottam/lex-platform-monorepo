variable "environment" {
  description = "Deployment environment name (e.g., dev, test, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the Lex bot is deployed (e.g., eu-west-2)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID hosting the Lex bot"
  type        = string
}

variable "aws_account_name" {
  description = "Human-friendly AWS account name used for tagging"
  type        = string
}

variable "bot_config_path" {
  description = "Relative path (from this module) to the bot configuration JSON file (e.g., examples/restaurant-bot.json)."
  type        = string
  default     = "examples/restaurant-bot.json"
}


