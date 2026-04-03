#!/bin/sh
set -e

# Generate config.ini from template using env vars
if [ -f /data/config.ini.template ]; then
  # Remove existing config (may be root-owned from previous runs)
  rm -f /data/config.ini

  # Use sed to replace ${VAR} placeholders with env var values
  cp /data/config.ini.template /tmp/config.ini
  sed -i "s|\${LIDARR_API_KEY}|${LIDARR_API_KEY}|g" /tmp/config.ini
  sed -i "s|\${SLSKD_API_KEY}|${SLSKD_API_KEY}|g" /tmp/config.ini
  cp /tmp/config.ini /data/config.ini
  echo "Generated config.ini from template"
fi

# Run original entrypoint
exec /app/run.sh
