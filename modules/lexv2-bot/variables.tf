variable "bot_config" {
  description = "Decoded JSON bot configuration"
  type        = any
}

variable "lambda_arns" {
  description = "Optional map of Lambda ARNs keyed by logical names used in bot_config (e.g., fulfillment_lambda_name)"
  type        = map(string)
  default     = {}
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}
# variable "locale_id" {
#   type = string
#   default = "en_GB"
# }
