#!/bin/bash
# family_idm_bootstrap.sh
# Ensures all prerequisites for podman compose up -d are met
# Usage: ./family_idm_bootstrap.sh

set -e

# --- CONFIG ---
CADDY_LOGS_DIR="$(dirname "$0")/../caddy-logs"
CADDY_UID=1000  # Default UID for Caddy container
CADDY_GID=1000  # Default GID for Caddy container

# --- 1. Ensure caddy-logs directory exists ---
echo "[INFO] Ensuring $CADDY_LOGS_DIR exists..."
mkdir -p "$CADDY_LOGS_DIR"

# --- 2. Set correct ownership and permissions ---
echo "[INFO] Setting ownership to $CADDY_UID:$CADDY_GID and permissions to 755..."
sudo chown -R $CADDY_UID:$CADDY_GID "$CADDY_LOGS_DIR"
chmod -R 755 "$CADDY_LOGS_DIR"

# --- 3. Set SELinux context if needed ---
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" != "Disabled" ]; then
  echo "[INFO] Setting SELinux context for $CADDY_LOGS_DIR..."
  sudo chcon -Rt svirt_sandbox_file_t "$CADDY_LOGS_DIR"
fi

# --- 4. Validate docker-compose.yml for duplicate mounts ---
echo "[INFO] Checking for duplicate /data mounts in docker-compose.yml..."
if grep -A5 'caddy:' keycloak-stack/docker-compose.yml | grep -E '/data\s*$' | wc -l | grep -vq '^1$'; then
  echo "[ERROR] Duplicate /data mount found in caddy service! Please fix docker-compose.yml."
  exit 1
fi

# --- 5. Start the stack ---
echo "[INFO] Starting podman compose stack..."
podman compose -f keycloak-stack/docker-compose.yml up -d

# --- 6. Check container status ---
echo "[INFO] Checking container status..."
podman compose -f keycloak-stack/docker-compose.yml ps

# --- 7. Check Caddy log file creation ---
LOG_TEST_FILE="$CADDY_LOGS_DIR/logs/access.log"
if [ -f "$LOG_TEST_FILE" ]; then
  echo "[INFO] Caddy access log exists: $LOG_TEST_FILE"
else
  echo "[WARN] Caddy access log not found yet. It will be created on first request."
fi

echo "[INFO] Bootstrap complete."
