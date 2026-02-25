# ============================================================================
# Local Variables - Data Transformation
# ============================================================================
# Transforms the JSON bot configuration into flattened data structures that
# Terraform can iterate over to create Lex resources.
#
# Key transformations:
# - Bot name: Appends environment suffix (e.g., restaurant-bot-dev)
# - Slot types: Flattens nested locale/slot_type structure
# - Intents: Sanitizes intent names to meet Lex ID requirements (max 10 chars)
# - Slots: Combines intent and slot data with proper type references

locals {
  bot_name = "${var.bot_config.name}-${var.environment}"

  # All locales from JSON
  locales = var.bot_config.locales

  # Flatten all slot types with lex-compliant IDs
  slot_types = flatten([
    for locale, locale_data in local.locales : [
      for slot_type_name, slot_type_data in lookup(locale_data, "slot_types", {}) : {
        locale = locale
        name   = slot_type_name
        description = lookup(slot_type_data, "description", "")
        values = slot_type_data.values
        # Lex-compliant ID (max 25, letters/numbers/_)
        lex_id = substr(replace(slot_type_name, "/[^0-9a-zA-Z_]/", ""), 0, 25)
      }
    ]
  ])

  # Flatten intents and sanitize IDs (max 10, letters/numbers only)
  intents = flatten([
    for locale, locale_data in local.locales : [
      for intent_name, intent_data in lookup(locale_data, "intents", {}) : {
        locale             = locale
        name               = intent_name
        description        = lookup(intent_data, "description", "")
        sample_utterances = lookup(intent_data, "sample_utterances", [])
        slots              = lookup(intent_data, "slots", {})
        # Optional Lambda association (by logical name) for fulfillment
        fulfillment_lambda_name = lookup(intent_data, "fulfillment_lambda_name", null)
        lex_id                  = substr(replace(intent_name, "/[^0-9a-zA-Z]/", ""), 0, 10)
      }
    ]
  ])

  # Flatten slots and attach sanitized IDs
  slots = flatten([
    for intent in local.intents : [
      for slot_name, slot_data in intent.slots : {
        locale       = intent.locale
        intent       = intent.name
        name         = slot_name
        description  = lookup(slot_data, "description", "")
        slot_type    = slot_data.slot_type
        required     = slot_data.required
        prompt       = slot_data.prompt
        lex_intent_id   = intent.lex_id
        lex_slot_type_id = lookup(
          { for st in local.slot_types : "${st.locale}-${st.name}" => st.lex_id }, 
          "${intent.locale}-${slot_data.slot_type}", 
          slot_data.slot_type
        )
      }
    ]
  ])
}
