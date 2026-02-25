# ============================================================================
# Intents
# ============================================================================
# Creates all intents defined in the bot configuration across all locales.
# Each intent represents a user goal (e.g., BookTable, TrackOrder).
# Intent IDs are sanitized to meet Lex naming requirements (max 10 chars).

resource "aws_lexv2models_intent" "intents" {
  for_each = {
    for intent in local.intents :
    "${intent.locale}-${intent.name}" => intent
  }

  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"
  locale_id   = each.value.locale
  name        = each.value.lex_id
  description = each.value.description

  # Enable fulfillment code hook when a fulfillment_lambda_name is provided in bot_config.
  # The actual Lambda ARN is configured at the bot alias level; this just turns on the hook.
  dynamic "fulfillment_code_hook" {
    for_each = each.value.fulfillment_lambda_name != null ? [1] : []
    content {
      enabled = true
    }
  }

  # lifecycle {
  #   create_before_destroy = false
  #   ignore_changes = [sample_utterance]
  # }

  # 🔹 Dynamically create sample utterances
  dynamic "sample_utterance" {
    for_each = each.value.sample_utterances
    content {
      utterance = sample_utterance.value
    }
  }

  depends_on = [
    aws_lexv2models_bot_locale.locales
  ]
}

# ============================================================================
# Slot Types (Custom)
# ============================================================================
# Creates custom slot types (e.g., MealType, ProductCategory) for each locale.
# Slot types define the valid values that can fill a slot in an intent.
# Built-in Amazon slot types (AMAZON.Date, AMAZON.Time) don't need to be created.

resource "aws_lexv2models_slot_type" "slot_types" {
  for_each = {
    for st in local.slot_types :
    "${st.locale}-${st.name}" => st
  }

  bot_id      = aws_lexv2models_bot.this.id
  bot_version = "DRAFT"
  locale_id   = each.value.locale
  name        = each.value.lex_id
  description = each.value.description

  dynamic "slot_type_values" {
    for_each = each.value.values
    content {
      sample_value {
        value = slot_type_values.value
      }
    }
  }

  value_selection_setting {
    resolution_strategy = "OriginalValue"
  }

  depends_on = [
    aws_lexv2models_bot_locale.locales
  ]
}

# ============================================================================
# Slots
# ============================================================================
# Creates slots for each intent. Slots are the information pieces the bot
# needs to collect (e.g., date, time, party size).
# - Required slots will prompt the user until a value is provided
# - Optional slots can be skipped
# - Supports both custom and Amazon built-in slot types

resource "aws_lexv2models_slot" "slots" {
  for_each = {
    for slot in local.slots :
    "${slot.locale}-${slot.intent}-${slot.name}" => slot
  }

  bot_id       = aws_lexv2models_bot.this.id
  bot_version  = "DRAFT"
  locale_id    = each.value.locale
  intent_id    = aws_lexv2models_intent.intents["${each.value.locale}-${each.value.intent}"].intent_id
  name         = each.value.name
  description  = each.value.description
  slot_type_id = startswith(each.value.slot_type, "AMAZON.") ? each.value.slot_type : aws_lexv2models_slot_type.slot_types["${each.value.locale}-${each.value.slot_type}"].slot_type_id

  value_elicitation_setting {
    slot_constraint = each.value.required ? "Required" : "Optional"
    prompt_specification {
      max_retries                = 2
      allow_interrupt            = true
      message_selection_strategy = "Random"
      message_group {
        message {
          plain_text_message { value = each.value.prompt }
        }
      }
      prompt_attempts_specification {
        map_block_key   = "Initial"
        allow_interrupt = true
        allowed_input_types {
          allow_audio_input = true
          allow_dtmf_input  = true
        }
        audio_and_dtmf_input_specification {
          start_timeout_ms = 4000
          audio_specification {
            max_length_ms  = 15000
            end_timeout_ms = 640
          }
          dtmf_specification {
            max_length         = 513
            end_timeout_ms     = 5000
            deletion_character = "*"
            end_character      = "#"
          }
        }
        text_input_specification {
          start_timeout_ms = 30000
        }
      }
      prompt_attempts_specification {
        map_block_key   = "Retry1"
        allow_interrupt = true
        allowed_input_types {
          allow_audio_input = true
          allow_dtmf_input  = true
        }
        audio_and_dtmf_input_specification {
          start_timeout_ms = 4000
          audio_specification {
            max_length_ms  = 15000
            end_timeout_ms = 640
          }
          dtmf_specification {
            max_length         = 513
            end_timeout_ms     = 5000
            deletion_character = "*"
            end_character      = "#"
          }
        }
        text_input_specification {
          start_timeout_ms = 30000
        }
      }
      prompt_attempts_specification {
        map_block_key   = "Retry2"
        allow_interrupt = true
        allowed_input_types {
          allow_audio_input = true
          allow_dtmf_input  = true
        }
        audio_and_dtmf_input_specification {
          start_timeout_ms = 4000
          audio_specification {
            max_length_ms  = 15000
            end_timeout_ms = 640
          }
          dtmf_specification {
            max_length         = 513
            end_timeout_ms     = 5000
            deletion_character = "*"
            end_character      = "#"
          }
        }
        text_input_specification {
          start_timeout_ms = 30000
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      value_elicitation_setting[0].prompt_specification[0].prompt_attempts_specification,
      value_elicitation_setting[0].prompt_specification[0].allow_interrupt,
      value_elicitation_setting[0].prompt_specification[0].message_selection_strategy
    ]
  }

  depends_on = [
    aws_lexv2models_intent.intents,
    aws_lexv2models_slot_type.slot_types
  ]
}