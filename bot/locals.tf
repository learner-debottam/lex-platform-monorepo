locals {
  bot_config = jsondecode(
    file("${path.module}/examples/minimal-bot.json")
  )
  tags ={
    MANAGED_BY ="Terraform"
    ENVIRONMENT = var.environment
    AWS_REGION = var.aws_region
    AWS_ACCOUNT_NAME = var.aws_account_name
    AWS_ACCOUNT_ID = var.aws_account_id
  }
  
}