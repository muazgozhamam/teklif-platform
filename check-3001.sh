#!/usr/bin/env bash
set -euo pipefail
echo "==> lsof :3001"
lsof -nP -iTCP:3001 -sTCP:LISTEN || true
echo
echo "==> curl /health"
curl -sS -i http://localhost:3001/health || true
echo
