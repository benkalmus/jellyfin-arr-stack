#!/bin/sh
set -e

# Copy config template to writable location
cp /app/slskd.yml /tmp/slskd.yml
CONFIG="/tmp/slskd.yml"

# Inject secrets from env vars into config
if [ -n "$SLSKD_USERNAME" ]; then
  sed -i "s|__SLSKD_USERNAME__|${SLSKD_USERNAME}|g" "$CONFIG"
fi
if [ -n "$SLSKD_SOULSEEK_PASS" ]; then
  sed -i "s|__SLSKD_SOULSEEK_PASS__|${SLSKD_SOULSEEK_PASS}|g" "$CONFIG"
fi
if [ -n "$SLSKD_WEB_PASSWORD" ]; then
  sed -i "s|__SLSKD_WEB_PASSWORD__|${SLSKD_WEB_PASSWORD}|g" "$CONFIG"
fi
if [ -n "$SLSKD_API_KEY" ]; then
  sed -i "s|__SLSKD_API_KEY__|${SLSKD_API_KEY}|g" "$CONFIG"
fi

echo "Secrets injected into config"

# Point slskd to the generated config
export SLSKD_CONFIG=/tmp/slskd.yml

# Run original entrypoint
exec /usr/bin/tini -- ./start.sh
