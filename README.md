## Lex V2 Bot Terraform Monorepo Template

This repository provides a **reusable, opinionated Terraform template** for provisioning **Amazon Lex V2 bots** in a monorepo. It is designed so that:

- Non‑Terraform users can define a bot using a **JSON template**.
- The JSON is **validated automatically** (schema + CI) before any infrastructure changes.
- The module creates **Lex V2 bot, locales, intents, slots, slot types, IAM roles, and bot version**.
- All resources are **driven declaratively** from the JSON; missing sections are simply not created.
- CI/CD for the **Dev environment** is handled via **GitHub Actions** with security checks.

---

## High‑Level Architecture

- **`modules/lexv2-bot`**  
  Generic, environment‑agnostic Terraform module that:
  - Creates the Lex V2 **bot** (`aws_lexv2models_bot`).
  - Creates **locales** per language (`aws_lexv2models_bot_locale`).
  - Creates **intents**, **custom slot types**, and **slots**:
    - `aws_lexv2models_intent`
    - `aws_lexv2models_slot_type`
    - `aws_lexv2models_slot`
  - Creates an **IAM role** and supporting policies for:
    - Allowing Lex to assume the role.
    - Allowing Lex to use Amazon Polly for speech synthesis.
    - Allowing Lex to write to CloudWatch Logs.
    - Optionally allowing Lex to invoke specified Lambda functions.
  - Creates a **bot version** (`aws_lexv2models_bot_version`) from the DRAFT bot.

- **`bot/`**  
  A concrete, Dev‑focused entrypoint that:
  - Reads a **bot configuration JSON** (e.g. `bot/examples/minimal-bot.json`).
  - Validates the JSON against a **JSON Schema**.
  - Calls the `lexv2-bot` module with appropriate variables.

- **`infra/`**  
  Shared Terraform infra components for remote state and providers (e.g., S3 backend for state).

- **`.github/workflows/terraform-dev.yml`**  
  GitHub Actions pipeline for **Dev**:
  - Lint, format, validate, and run security checks (Checkov).
  - Validate JSON configs with the schema using a shell script.
  - Run `terraform plan` and `terraform apply` for Dev using OIDC -> AWS.

---

## Repository Layout

- **`bot/`**
  - `main.tf` – Root Terraform entrypoint for the Dev bot, calls the module.
  - `variables.tf` – Input variables for Dev deployment (environment, region, account, bot_config_path, etc.).
  - `locals.tf` – Loads and decodes the bot JSON configuration (path controlled by `bot_config_path`) and defines common tags.
  - `examples/*.json` – Multiple **example bot configurations** (minimal, restaurant, booking, e‑commerce, etc.).
  - `validate_bot_config.sh` – Shell script to **validate any bot JSON** against the schema.
  - `validate_bot_config.py` – Python alternative for JSON validation (optional).

- **`modules/lexv2-bot/`**
  - `main.tf` – Lex bot (`aws_lexv2models_bot`) and locales (`aws_lexv2models_bot_locale`).
  - `intents.tf` – Intents, custom slot types, and slots (`aws_lexv2models_intent`, `aws_lexv2models_slot_type`, `aws_lexv2models_slot`).
  - `iam.tf` – Lex IAM role and policies (Polly, CloudWatch Logs, optional Lambda invoke).
  - `locals.tf` – Flattens the JSON config into Terraform‑friendly data structures.
  - `variables.tf` – Module inputs (bot_config, environment, tags, region, account, lambda_arns).
  - `version.tf` / `versions.tf` – Provider and bot version resources.
  - `outputs.tf` – Exposes bot ID, bot version, and configured locales.
  - `schema.json` – **JSON Schema** defining the required/optional structure of `bot_config`.

- **`infra/`**
  - `backend.tf` – S3 backend definition for Terraform remote state (S3 bucket + lock file).
  - `versions.tf` – Root Terraform and provider version constraints.
  - `providers.tf` – AWS provider stub (region/account wired via variables).
  - `variables.tf` – Shared root variables for environment, region, account, etc.
  - `state/dev.config` – Example backend config for the **Dev** environment.

- **`.github/workflows/terraform-dev.yml`**
  - GitHub Actions definition for **Dev** pipeline.

---

## The Bot Configuration JSON (User Input)

The module is driven by a single JSON document per bot, for example:

```json
{
  "name": "restaurant-bot",
  "description": "Restaurant booking bot",
  "idle_session_ttl": 300,
  "locales": {
    "en_US": {
      "description": "US English locale",
      "confidence_threshold": 0.7,
      "slot_types": {
        "MealType": {
          "description": "Type of meal",
          "values": ["breakfast", "lunch", "dinner"]
        }
      },
      "intents": {
        "BookTable": {
          "description": "Book a restaurant table",
          "sample_utterances": [
            "Book a table",
            "I want to book a table"
          ],
          "fulfillment_lambda_name": "restaurant-booking-handler",
          "slots": {
            "Date": {
              "description": "Booking date",
              "slot_type": "AMAZON.Date",
              "required": true,
              "prompt": "For what date would you like to book?"
            },
            "Time": {
              "description": "Booking time",
              "slot_type": "AMAZON.Time",
              "required": true,
              "prompt": "What time?"
            },
            "PartySize": {
              "description": "Number of people",
              "slot_type": "AMAZON.Number",
              "required": true,
              "prompt": "For how many people?"
            }
          }
        }
      }
    },
    "en_GB": {
      "description": "UK English locale",
      "confidence_threshold": 0.7,
      "slot_types": {},
      "intents": {
        "BookTable": {
          "description": "Book a table (UK)",
          "sample_utterances": ["Book a table", "Reserve a table"],
          "slots": {
            "Date": {
              "description": "Booking date (UK)",
              "slot_type": "AMAZON.Date",
              "required": true,
              "prompt": "What date would you like to book?"
            }
          }
        }
      }
    }
  }
}
```

### Optional vs required fields

- **Top‑level**
  - **Required**: `name`, `idle_session_ttl`, `locales`.
  - **Optional**: `description`.

- **Locales (`locales.<locale_id>`)**
  - **Required**: `confidence_threshold` (0–1).
  - **Optional**: `description`, `slot_types`, `intents`, `voice_settings`.
  - If `slot_types` is missing/empty → **no custom slot types** are created for that locale.
  - If `intents` is missing/empty → **no intents or slots** are created for that locale.
  - If `voice_settings` is provided, the locale will be configured with the specified Amazon Polly voice.

- **Slot types (`slot_types.<name>`)**
  - **Required**: `values` (non‑empty list of strings).
  - **Optional**: `description`.

- **Intents (`intents.<name>`)**
  - **Optional but recommended**: `sample_utterances` (non‑empty list of strings).
  - **Optional**:
    - `description`
    - `fulfillment_lambda_name` (string; must match a key in `lambda_arns` when you want Lex to call Lambda)
    - `slots` map.
  - If `slots` is missing/empty → **no slots** are created for that intent.

- **Slots (`slots.<name>`)**
  - **Required**:
    - `slot_type` – either an Amazon built‑in type (e.g. `AMAZON.Date`) or a custom type name defined under `slot_types` for that locale.
    - `required` – boolean.
    - `prompt` – non‑empty string (user prompt).
  - **Optional**: `description`.

All of this is enforced by **`modules/lexv2-bot/schema.json`** and the validation scripts / CI.

---

## JSON Schema and Validation

The JSON Schema is defined in **`modules/lexv2-bot/schema.json`** using JSON Schema **Draft‑07**. It:

- Enforces the required keys and types.
- Rejects unknown/typo’d fields (`additionalProperties: false`).
- Validates locale IDs with a regex: `^[a-z]{2}_[A-Z]{2}$` (e.g., `en_US`, `en_GB`).
- Validates structure and types of `slot_types`, `intents`, and `slots`.

### Shell‑based validation (`validate_bot_config.sh`)

In `bot/validate_bot_config.sh`:

- Validates any config JSON against the schema using **AJV**:
  - Uses `ajv` CLI if installed, otherwise falls back to `npx ajv-cli@8`.
- Default schema path: `modules/lexv2-bot/schema.json`.

Usage:

```bash
chmod +x bot/validate_bot_config.sh

./bot/validate_bot_config.sh --config bot/examples/minimal-bot.json

# or specify a custom schema
./bot/validate_bot_config.sh --config path/to/bot.json --schema modules/lexv2-bot/schema.json
```

### Optional Python validation (`validate_bot_config.py`)

In `bot/validate_bot_config.py`:

- Uses the `jsonschema` Python library to validate against the same schema.

Usage:

```bash
pip install jsonschema
python bot/validate_bot_config.py --config bot/examples/minimal-bot.json
```

Exit codes:

- `0` – config is valid.
- `1` – config invalid (schema failure).
- `2` – usage error / missing file / dependency missing.

---

## The Terraform Module (`modules/lexv2-bot`)

### Module Inputs

- **`bot_config`** (`any`, required)  
  The decoded JSON object (output of `jsondecode(file("...json"))`) representing the bot.

- **`environment`** (`string`, required)  
  Environment name (e.g., `dev`, `test`, `prod`). Used to suffix bot name and tags.

- **`aws_region`** (`string`, required)  
  Region where Lex is deployed.

- **`aws_account_id`** (`string`, required)  
  AWS account ID where the bot and IAM role are created.

- **`tags`** (`map(string)`, optional, default `{}`)  
  Tags applied to supported resources (e.g. IAM role, policies, bot).

- **`lambda_arns`** (`map(string)`, optional, default `{}`)  
  Map of logical Lambda names → Lambda ARNs.  
  - If `bot_config.locales.*.intents.*.fulfillment_lambda_name` matches a key in this map:
    - The module grants Lex permissions to **invoke** those Lambdas.
    - The intent’s **fulfillment code hook** is enabled.
  - If this map is empty, **no Lambda permissions** are created.

### Module Behavior

- **Bot and locales**
  - `locals.bot_name` = `${bot_config.name}-${environment}`.
  - `aws_lexv2models_bot` uses `bot_config.description` (if set) and `bot_config.idle_session_ttl`.
  - `aws_lexv2models_bot_locale` is created for each locale in `bot_config.locales` and optionally configures **voice settings** when present in the JSON.

- **Slot types**
  - `locals.slot_types` flattens `locales.*.slot_types` into a list.
  - Names are sanitized to Lex IDs (`lex_id`) with max length and safe characters.
  - `aws_lexv2models_slot_type` is created only when `slot_types` exist.

- **Intents and slots**
  - `locals.intents` flattens all intents across locales:
    - Carries `description`, `sample_utterances`, `slots`, `fulfillment_lambda_name`, and sanitized `lex_id`.
  - `locals.slots` flattens each intent’s `slots` into a separate list keyed by locale, intent, and slot name.
  - `aws_lexv2models_intent`:
    - Always created for defined intents.
    - Dynamically creates `sample_utterance` blocks.
    - Optionally sets `fulfillment_code_hook { enabled = true }` when **`fulfillment_lambda_name` is non‑null**.
  - `aws_lexv2models_slot`:
    - Created only for defined slots.
    - `slot_type_id` automatically references either:
      - Built‑in Amazon slot types (`AMAZON.*`), or
      - Custom slot types defined in the same locale.
    - Elicitation prompts and attempts are configured per slot, with lifecycle ignores for noisy fields.

- **IAM (`iam.tf`)**
  - **Trust policy** – Allows `lexv2.amazonaws.com` to assume the IAM role.
  - **Polly policy** – Allows `polly:SynthesizeSpeech` on the account’s lexicons.
  - **CloudWatch Logs policy** – Allows `logs:CreateLogStream`, `logs:PutLogEvents`, `logs:CreateLogGroup` on Lex log groups.
  - **Optional Lambda invoke policy** – Created only when `lambda_arns` is non‑empty:

    ```hcl
    data "aws_iam_policy_document" "allow_invoke_lambdas" {
      count = length(var.lambda_arns) > 0 ? 1 : 0

      statement {
        sid    = "AllowInvokeLambdas"
        effect = "Allow"
        actions = [
          "lambda:InvokeFunction",
          "lambda:InvokeAsync"
        ]
        resources = values(var.lambda_arns)
      }
    }
    ```

- **Bot version**
  - `aws_lexv2models_bot_version` builds a version from DRAFT for all locales, depending on intents and slots.

- **Outputs**
  - `bot_id` – Lex bot ID.
  - `bot_version` – Version number created by `aws_lexv2models_bot_version`.
  - `locales` – List of configured locale IDs (e.g., `["en_US", "en_GB"]`).

---

## Dev Entrypoint (`bot/`)

The `bot` folder is a **concrete Dev configuration** that calls the module.

- **`bot/locals.tf`**

  ```hcl
  locals {
    bot_config = jsondecode(
      file("${path.module}/${var.bot_config_path}")
    )
    tags = {
      MANAGED_BY      = "Terraform"
      ENVIRONMENT     = var.environment
      AWS_REGION      = var.aws_region
      AWS_ACCOUNT_NAME = var.aws_account_name
      AWS_ACCOUNT_ID   = var.aws_account_id
    }
  }
  ```

- **`bot/main.tf`**

  ```hcl
  module "lex_bot" {
    source         = "../modules/lexv2-bot"
    bot_config     = local.bot_config
    environment    = var.environment
    aws_region     = var.aws_region
    aws_account_id = var.aws_account_id
    tags           = local.tags
  }
  ```

- **`bot/variables.tf`**
  - Declares `environment`, `aws_region`, `aws_account_id`, `aws_account_name`, and `bot_config_path`.

This makes it easy to run Terraform for Dev directly from `bot/`.

---

## Running Terraform Locally (Dev)

### Prerequisites

- Terraform >= 1.6.0
- AWS credentials with appropriate permissions (e.g., via profile or environment).
- If using S3 backend (recommended), the S3 bucket and DynamoDB lock table should exist (as configured in `infra/backend.tf` and `infra/state/dev.config`).

### Steps

1. **Validate JSON config** (recommended)

   ```bash
   ./bot/validate_bot_config.sh --config bot/examples/restaurant-bot.json
   ```

2. **Initialize and plan (from `bot/`)**

   ```bash
   cd bot

   terraform init \
     -backend-config="../infra/state/dev.config"

   terraform plan \
     -var "environment=dev" \
     -var "aws_region=eu-west-2" \
     -var "aws_account_id=123456789012" \
     -var "aws_account_name=my-dev-account" \
     -var "bot_config_path=examples/restaurant-bot.json"
   ```

3. **Apply**

   ```bash
   terraform apply \
     -var "environment=dev" \
     -var "aws_region=eu-west-2" \
     -var "aws_account_id=123456789012" \
     -var "aws_account_name=my-dev-account" \
     -var "bot_config_path=examples/restaurant-bot.json"
   ```

---

## GitHub Actions CI/CD (Dev)

The workflow is defined in **`.github/workflows/terraform-dev.yml`** and is triggered on:

- Pushes to the `dev` branch.
- Pull requests targeting `dev`.
- Manual `workflow_dispatch`.

### Jobs

- **`lint` – Lint, format, security, and schema validation**
  - `terraform fmt -check -recursive` across the repo.
  - `terraform validate` for:
    - `modules/lexv2-bot`
    - `bot/` (Dev entrypoint)
  - Runs `bot/validate_bot_config.sh` on all `bot/*.json` configs (skips `schema.json`).
  - Runs **Checkov** (`bridgecrewio/checkov-action`) over the repo for Terraform security and compliance.

- **`plan` – Terraform plan for Dev**
  - Depends on `lint`.
  - Uses **GitHub OIDC** with `aws-actions/configure-aws-credentials@v4`.
  - Assumes a Dev role specified by `secrets.AWS_ASSUME_ROLE_DEV`.
  - Sets `TF_VAR_environment`, `TF_VAR_aws_region`, `TF_VAR_aws_account_id`, `TF_VAR_aws_account_name`.
  - Re‑validates JSON configs with `validate_bot_config.sh`.
  - Runs `terraform init` and `terraform plan -out=tfplan-dev` in `bot/`.
  - Uploads `tfplan-dev` as an artifact.

- **`apply` – Terraform apply for Dev**
  - Depends on `plan`.
  - Only runs on **pushes** to `dev` (not on PRs).
  - Uses the same AWS OIDC setup and variables as `plan`.
  - Downloads the `tfplan-dev` artifact.
  - Runs `terraform init` then `terraform apply tfplan-dev` in `bot/`.
  - Uses a GitHub `environment: dev` to allow environment‑level protections (e.g. required approvals).
  - When triggered manually via **workflow dispatch**, you can enable a checkbox to turn on `TF_LOG=DEBUG` for Terraform commands (useful for deep debugging).

### Required GitHub Secrets for Dev

- **`AWS_ASSUME_ROLE_DEV`** – IAM role ARN that GitHub Actions will assume via OIDC.
- **`AWS_REGION_DEV`** – AWS region for Dev (`eu-west-2`, etc.).
- **`AWS_ACCOUNT_NAME_DEV`** – Human‑readable account name for tagging.

> The AWS IAM role assumed by GitHub must have sufficient permissions to:
> - Manage Lex V2 resources (bot, locales, intents, slot types, slots, versions).
> - Create / update IAM roles and policies for Lex.
> - Access the S3 bucket used for Terraform state (if using remote backend).

---

## Security and Best Practices

- **Remote state and locking**
  - State is configured to use an **S3 backend**, with **lock file stored in the same bucket**.
  - This avoids local state drift and enables safe collaboration.

- **Least‑privilege IAM**
  - The Lex IAM role is limited to:
    - Assuming Lex V2 service.
    - Polly speech synthesis.
    - CloudWatch logging for Lex log groups.
    - Only the Lambda ARNs you explicitly provide in `lambda_arns`.

- **Infrastructure validation**
  - `terraform fmt` and `terraform validate` enforce formatting and basic correctness.
  - `checkov` enforces security/compliance checks for Terraform code.
  - JSON Schema validation ensures that bot definitions **conform to the contract** before any infrastructure run.

- **Environment separation**
  - This template focuses on **Dev** but is structured to scale:
    - Separate backend config files (e.g., `infra/state/dev.config`, `infra/state/prod.config`).
    - Separate workflows / jobs or environments for staging and production.

---

## Extending the Template

- **Add new locales**
  - Add additional locale entries under `locales` in your bot JSON (e.g., `en_AU`, `fr_FR`).
  - The module automatically creates locales, intents, slot types, and slots for those locales.

- **Add new intents or slots**
  - Extend the `intents` section in the JSON.
  - Add slots with proper `slot_type`, `required`, and `prompt`.

- **Add Lambda‑backed fulfillment**
  - Deploy Lambda functions separately (e.g., with another Terraform module).
  - Pass their ARNs via the `lambda_arns` map when calling `lexv2-bot`.
  - Reference their logical names in `fulfillment_lambda_name` in the JSON.

- **Add more CI checks**
  - You can extend the GitHub workflow to:
    - Run unit tests for Lambda code.
    - Perform additional security scans (e.g., Trivy, tfsec) if desired.

---

## Non‑Technical Overview (For Stakeholders)

- **Purpose**
  - Provide a **repeatable, automated way** to create and update Amazon Lex V2 bots based on **simple JSON descriptions**, without requiring deep Terraform or AWS expertise.

- **How it works (conceptually)**
  1. A product or domain expert defines the **bot behavior** in a structured JSON file:
     - Supported languages (locales).
     - User intents (what users can ask for).
     - Required information (slots) and prompts.
     - Optional connections to backend systems via AWS Lambda.
  2. The JSON is **validated automatically** to catch mistakes early.
  3. Terraform uses this JSON to create or update the Lex bot and related AWS resources.
  4. A **CI/CD pipeline** in GitHub ensures:
     - Changes are reviewed.
     - Security checks pass.
     - Infrastructure changes are consistent and auditable.

- **Benefits**
  - **Consistency** – All bots follow the same structure and infrastructure patterns.
  - **Safety** – Automated validation and security checks reduce runtime surprises.
  - **Scalability** – Supports multiple locales and complex bots without manual console changes.
  - **Traceability** – Every change is versioned in Git and deployed via CI/CD.

---

## Getting Help

- For questions about **bot JSON structure**, refer to `modules/lexv2-bot/schema.json` and the examples in `bot/examples/`.
- For issues with **validation scripts**, see `bot/validate_bot_config.sh` and `bot/validate_bot_config.py`.
- For Terraform or AWS Lex V2 specific behavior, consult:
  - Terraform AWS provider docs for `aws_lexv2models_*` resources.
  - AWS Lex V2 documentation for intents, slots, and locales.

