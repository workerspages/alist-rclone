#!/bin/bash
set -e

echo "============================================"
echo "  Alist-Rclone All-in-One Container"
echo "============================================"

# ---- Timezone ----
if [ -n "$TZ" ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo "$TZ" > /etc/timezone
fi

# ---- Initialize Alist ----
echo "[Init] Initializing Alist..."
if [ ! -f /data/alist/config.json ]; then
    echo "[Init] First run, creating Alist config..."
    mkdir -p /data/alist
    cd /data/alist
    /app/alist server --data /data/alist &
    ALIST_PID=$!
    # Wait for Alist to initialize
    sleep 3
    kill $ALIST_PID 2>/dev/null || true
    wait $ALIST_PID 2>/dev/null || true
fi

# Set Alist admin password
if [ -n "$ALIST_ADMIN_PASSWORD" ]; then
    echo "[Init] Setting Alist admin credentials..."
    /app/alist admin set "$ALIST_ADMIN_PASSWORD" --data /data/alist 2>/dev/null || true
fi

# ---- Initialize Rclone ----
echo "[Init] Initializing Rclone..."
mkdir -p /data/rclone/cache
if [ ! -f /data/rclone/rclone.conf ]; then
    echo "[Init] Creating empty Rclone config..."
    touch /data/rclone/rclone.conf
fi

# Auto-add local Alist WebDAV into Rclone config if it doesn't exist
ALIST_REMOTE_NAME="alist"
if ! grep -q "\[$ALIST_REMOTE_NAME\]" /data/rclone/rclone.conf; then
    echo "[Init] Adding local Alist as WebDAV remote '$ALIST_REMOTE_NAME' to Rclone..."
    ALIST_USER="${ALIST_ADMIN_USERNAME:-admin}"
    ALIST_PASS="${ALIST_ADMIN_PASSWORD:-admin}"
    # Obscure password for Rclone config
    OBSCURED_PASS=$(rclone obscure "$ALIST_PASS")
    cat >> /data/rclone/rclone.conf <<EOF

[$ALIST_REMOTE_NAME]
type = webdav
url = http://127.0.0.1:5244/dav
vendor = other
user = $ALIST_USER
pass = $OBSCURED_PASS
EOF
fi

# Auto-add local host directory as alias remote
HOST_REMOTE_NAME="host"
if ! grep -q "\[$HOST_REMOTE_NAME\]" /data/rclone/rclone.conf; then
    echo "[Init] Adding local host directory as alias remote '$HOST_REMOTE_NAME'..."
    mkdir -p /opt/host
    cat >> /data/rclone/rclone.conf <<EOF

[$HOST_REMOTE_NAME]
type = alias
remote = /opt/host
EOF
fi

# ---- Set environment for API server ----
export WEB_USERNAME="${WEB_USERNAME:-admin}"
export WEB_PASSWORD="${WEB_PASSWORD:-admin}"

# ---- Generate nginx Basic Auth file ----
echo "[Init] Generating Basic Auth credentials..."
htpasswd -cb /etc/nginx/.htpasswd "$WEB_USERNAME" "$WEB_PASSWORD"

# ---- Create log files ----
touch /var/log/alist.log /var/log/rclone.log /var/log/api.log

echo "[Init] Starting services via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
