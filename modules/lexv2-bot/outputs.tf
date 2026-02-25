output "bot_id" {
  value = aws_lexv2models_bot.this.id
}

output "bot_version" {
  value = aws_lexv2models_bot_version.this.bot_version
}

output "locales" {
  description = "Locales configured on the bot (keys are locale IDs such as en_US, en_GB)"
  value       = keys(local.locales)
}

