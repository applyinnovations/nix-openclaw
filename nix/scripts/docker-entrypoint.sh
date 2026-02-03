#!/bin/bash
set -euo pipefail

mkdir -p /data/workspace /tmp/openclaw

if [ -f /config/openclaw.json ]; then
  export MOLTBOT_CONFIG_PATH=/config/openclaw.json
  export CLAWDBOT_CONFIG_PATH=/config/openclaw.json
fi

exec openclaw gateway --port "${OPENCLAW_GATEWAY_PORT:-18789}" "$@"
