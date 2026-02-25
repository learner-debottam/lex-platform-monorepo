# ============================================================================
# AWS Lex Bot - Main Bot Resource
# ============================================================================
# Creates the primary Lex V2 bot with data privacy settings and session timeout.
# The bot name is automatically suffixed with the environment (e.g., my-bot-dev).

resource "aws_lexv2models_bot" "this" {
  name        = local.bot_name
  description = lookup(var.bot_config, "description", "Lex bot managed by Terraform")
  role_arn    = aws_iam_role.lex_role.arn

  data_privacy {
    child_directed = false
  }

  idle_session_ttl_in_seconds = var.bot_config.idle_session_ttl

  tags = var.tags
}

# ============================================================================
# Bot Locales
# ============================================================================
# Creates a locale for each language defined in the bot configuration.
# Each locale has its own confidence threshold for NLU intent matching.

resource "aws_lexv2models_bot_locale" "locales" {
  for_each = local.locales

  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"
  locale_id   = each.key
  description = lookup(each.value, "description", "Locale for ${each.key}")

  n_lu_intent_confidence_threshold = each.value.confidence_threshold
}