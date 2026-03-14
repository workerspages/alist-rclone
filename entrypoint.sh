#!/bin/bash
set -e

echo "============================================"
echo "  Alist-Rclone All-in-One Container"
echo "============================================"

# ---- Setup Swap Memory ----
if [ -n "$SWAP_SIZE_MB" ] && [ "$SWAP_SIZE_MB" -gt 0 ] 2>/dev/null; then
    echo "[Init] Setting up swap space of ${SWAP_SIZE_MB}MB..."
    swapoff /swapfile 2>/dev/null || true
    if [ ! -f /swapfile ] || [ "$(stat -c %s /swapfile 2>/dev/null || echo 0)" -ne "$((SWAP_SIZE_MB * 1024 * 1024))" ]; then
        echo "[Init] Creating /swapfile..."
        dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_SIZE_MB" 2>/dev/null
        chmod 600 /swapfile
        mkswap /swapfile
    fi
    echo "[Init] Enabling swap..."
    swapon /swapfile || echo "[Warning] Failed to enable swap. This may require --privileged or CAP_SYS_ADMIN capabilities."
fi

# ---- Timezone ----
if [ -n "$TZ" ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo "$TZ" > /etc/timezone
fi

# ---- Custom CA Certificates ----
if [ -n "$CUSTOM_CA_CERT_PATH" ]; then
    if [ -f "$CUSTOM_CA_CERT_PATH" ]; then
        echo "[Init] Loading custom CA certificate from file: $CUSTOM_CA_CERT_PATH"
        cp "$CUSTOM_CA_CERT_PATH" /usr/local/share/ca-certificates/custom-ca.crt
        update-ca-certificates
        export NODE_EXTRA_CA_CERTS="$CUSTOM_CA_CERT_PATH"
    elif [ -d "$CUSTOM_CA_CERT_PATH" ]; then
        echo "[Init] Loading custom CA certificates from directory: $CUSTOM_CA_CERT_PATH"
        cp "$CUSTOM_CA_CERT_PATH"/* /usr/local/share/ca-certificates/ 2>/dev/null || true
        update-ca-certificates
    else
        echo "[Warning] CUSTOM_CA_CERT_PATH ($CUSTOM_CA_CERT_PATH) is not a valid file or directory"
    fi
fi

# ---- External Storage Restore (S3/WebDAV) ----
if [ -n "$SYNC_DEST" ]; then
    echo "[Init] SYNC_DEST is set. Attempting to restore /data from external storage..."
    mkdir -p /data
    # 使用 rclone 将外部存储的数据拉取到本地 /data 目录，跳过缓存目录
    /usr/bin/rclone copy "$SYNC_DEST" /data -v || echo "[Warning] Restore failed or remote is empty. Starting fresh."
fi

# ---- Initialize Alist ----
echo "[Init] Initializing Alist..."
if [ ! -f /data/alist/config.json ]; then
    echo "[Init] First run, creating Alist config (sqlite3)..."
    mkdir -p /data/alist
    cd /data/alist
    
    # 首次运行让 Alist 自动生成默认的 sqlite3 配置文件
    /app/alist server --data /data/alist &
    ALIST_PID=$!
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
