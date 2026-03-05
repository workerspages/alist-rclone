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
