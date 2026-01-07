#!/bin/sh
set -e

store_path_file="${PNPM_STORE_PATH_FILE:-.pnpm-store-path}"
if [ -f "$store_path_file" ]; then
  store_path="$(cat "$store_path_file")"
  export PNPM_STORE_DIR="$store_path"
  export PNPM_STORE_PATH="$store_path"
  export NPM_CONFIG_STORE_DIR="$store_path"
  export NPM_CONFIG_STORE_PATH="$store_path"
fi

export HOME="$(mktemp -d)"
export TMPDIR="$HOME/tmp"
mkdir -p "$TMPDIR"

if [ -z "${CONFIG_SCHEMA_CHECK_SCRIPT:-}" ]; then
  echo "CONFIG_SCHEMA_CHECK_SCRIPT is not set" >&2
  exit 1
fi
if [ ! -f "$CONFIG_SCHEMA_CHECK_SCRIPT" ]; then
  echo "CONFIG_SCHEMA_CHECK_SCRIPT not found: $CONFIG_SCHEMA_CHECK_SCRIPT" >&2
  exit 1
fi
if [ -z "${CONFIG_SCHEMA_SAMPLE_JSON:-}" ]; then
  echo "CONFIG_SCHEMA_SAMPLE_JSON is not set" >&2
  exit 1
fi
if [ ! -f "$CONFIG_SCHEMA_SAMPLE_JSON" ]; then
  echo "CONFIG_SCHEMA_SAMPLE_JSON not found: $CONFIG_SCHEMA_SAMPLE_JSON" >&2
  exit 1
fi

script_dest="./config-schema-check.ts"
cp "$CONFIG_SCHEMA_CHECK_SCRIPT" "$script_dest"

pnpm exec tsx "$script_dest" "$CONFIG_SCHEMA_SAMPLE_JSON"
