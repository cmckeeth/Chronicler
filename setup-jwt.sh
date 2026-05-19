#!/usr/bin/env bash
set -euo pipefail

KEY=$(openssl rand -base64 48)
echo "JWT_KEY=$KEY" > .env

echo ""
echo "==================================="
echo "JWT_KEY=$KEY"
echo "==================================="
echo ""
echo "1. .env written to current directory"
echo "2. Copy the JWT_KEY value above into:"
echo "   GitHub → cmckeeth/Chronicler → Settings → Secrets → Actions → New secret"
echo "   Name:  JWT_KEY"
echo "   Value: (the string above)"
echo ""
