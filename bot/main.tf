module "lex_bot" {
  source         = "../modules/lexv2-bot"
  bot_config     = local.bot_config
  environment    = var.environment
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id
  tags           = local.tags
}