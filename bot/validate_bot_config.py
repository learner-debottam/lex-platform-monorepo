#!/usr/bin/env python3
"""
Validate a Lex V2 bot configuration JSON file against the schema used by
the Terraform lexv2-bot module.

Usage:
  python bot/validate_bot_config.py --config path/to/bot.json

Exit codes:
  0 - configuration is valid
  1 - configuration is invalid (schema validation failed)
  2 - usage error, missing files, or jsonschema not installed
"""

import argparse
import json
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
  parser = argparse.ArgumentParser(description="Validate Lex V2 bot config JSON against schema.json.")
  parser.add_argument(
    "--config",
    required=True,
    help="Path to the bot configuration JSON file to validate.",
  )
  parser.add_argument(
    "--schema",
    help="Optional path to schema.json. Defaults to modules/lexv2-bot/schema.json at repo root.",
  )
  return parser.parse_args()


def load_json(path: Path) -> dict:
  try:
    with path.open("r", encoding="utf-8") as f:
      return json.load(f)
  except FileNotFoundError:
    print(f"ERROR: File not found: {path}", file=sys.stderr)
    sys.exit(2)
  except json.JSONDecodeError as e:
    print(f"ERROR: Failed to parse JSON file {path}: {e}", file=sys.stderr)
    sys.exit(2)


def main() -> int:
  args = parse_args()

  try:
    import jsonschema
  except ImportError:
    print(
      "ERROR: Python package 'jsonschema' is not installed.\n"
      "Install it with: pip install jsonschema",
      file=sys.stderr,
    )
    return 2

  config_path = Path(args.config).expanduser().resolve()

  if args.schema:
    schema_path = Path(args.schema).expanduser().resolve()
  else:
    # Assume this script lives in <repo_root>/bot/
    repo_root = Path(__file__).resolve().parents[1]
    schema_path = repo_root / "modules" / "lexv2-bot" / "schema.json"

  schema = load_json(schema_path)
  config = load_json(config_path)

  try:
    jsonschema.validate(instance=config, schema=schema)
  except jsonschema.ValidationError as e:
    print("Bot configuration is INVALID:", file=sys.stderr)
    print(f"- Message : {e.message}", file=sys.stderr)
    if e.path:
      path_str = ".".join(str(p) for p in e.path)
      print(f"- At path : {path_str}", file=sys.stderr)
    sys.exit(1)

  print(f"Bot configuration is valid: {config_path}")
  return 0


if __name__ == "__main__":
  sys.exit(main())

