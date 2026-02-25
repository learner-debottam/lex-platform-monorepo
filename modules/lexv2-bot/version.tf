resource "aws_lexv2models_bot_version" "this" {
  bot_id = aws_lexv2models_bot.this.id

  locale_specification = {
    for locale_id, _ in local.locales : locale_id => {
      source_bot_version = "DRAFT"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_lexv2models_intent.intents,
    aws_lexv2models_slot.slots,
  ]
}

# resource "aws_lex_bot_alias" "live" {
#   bot_name    = aws_lexv2models_bot.this.name
#   bot_version = aws_lexv2models_bot_version.this.bot_version
#   description = "Live Version of the Bot."
#   name        = "Live"
# }
