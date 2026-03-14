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
        dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_SIZE_MB" 2>/dev/null
        chmod 600 /swapfile
        mkswap /swapfile
    fi
    swapon /swapfile || echo "[Warning] Failed to enable swap."
fi

# ---- Timezone ----
if [ -n "$TZ" ]; then
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo "$TZ" > /etc/timezone
fi

# ---- External Storage Restore (S3/WebDAV) ----
if [ -n "$SYNC_DEST" ]; then
    echo "[Init] SYNC_DEST is set. Attempting to restore /data from external storage..."
    mkdir -p /data
    RESTORE_OK=false
    
    # 增加重试机制：PaaS容器启动时网络可能存在延迟，最多重试6次（等待30秒）
    for i in 1 2 3 4 5 6; do
        echo "=> [Attempt $i/6] Pulling data from $SYNC_DEST..."
        if /usr/bin/rclone copy "$SYNC_DEST" /data -v; then
            RESTORE_OK=true
            echo "[Init] Restore successful (or remote is empty)!"
            break
        fi
        echo "=> [Warning] Pull failed. Network may not be ready. Retrying in 5 seconds..."
        sleep 5
    done

    # 致命错误保护（熔断机制）：如果30秒后依然无法拉取，强制停止容器！
    # 绝不让程序带病启动，防止触发 5 分钟后的 autosync 把网盘备份清空。
    if [ "$RESTORE_OK" != true ]; then
        echo "=========================================================================="
        echo "[FATAL ERROR] Failed to restore data from SYNC_DEST after 30 seconds!"
        echo "Container startup is HALTED to prevent wiping your remote backup."
        echo "Please check your SYNC_DEST credentials or provider API status."
        echo "=========================================================================="
        exit 1
    fi
fi

# ---- Initialize Alist ----
echo "[Init] Initializing Alist..."
if [ ! -f /data/alist/config.json ]; then
    echo "[Init] First run, creating Alist config (sqlite3)..."
    mkdir -p /data/alist
    cd /data/alist
    /app/alist server --data /data/alist &
    ALIST_PID=$!
    sleep 3
    kill $ALIST_PID 2>/dev/null || true
    wait $ALIST_PID 2>/dev/null || true
fi

if [ -n "$ALIST_ADMIN_PASSWORD" ]; then
    /app/alist admin set "$ALIST_ADMIN_PASSWORD" --data /data/alist 2>/dev/null || true
fi

# ---- Initialize Rclone ----
echo "[Init] Initializing Rclone..."
mkdir -p /data/rclone/cache
if [ ! -f /data/rclone/rclone.conf ]; then
    touch /data/rclone/rclone.conf
fi

ALIST_REMOTE_NAME="alist"
if ! grep -q "\[$ALIST_REMOTE_NAME\]" /data/rclone/rclone.conf; then
    ALIST_USER="${ALIST_ADMIN_USERNAME:-admin}"
    ALIST_PASS="${ALIST_ADMIN_PASSWORD:-admin}"
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

HOST_REMOTE_NAME="host"
if ! grep -q "\[$HOST_REMOTE_NAME\]" /data/rclone/rclone.conf; then
    mkdir -p /opt/host
    cat >> /data/rclone/rclone.conf <<EOF

[$HOST_REMOTE_NAME]
type = alias
remote = /opt/host
EOF
fi

export WEB_USERNAME="${WEB_USERNAME:-admin}"
export WEB_PASSWORD="${WEB_PASSWORD:-admin}"
htpasswd -cb /etc/nginx/.htpasswd "$WEB_USERNAME" "$WEB_PASSWORD"
touch /var/log/alist.log /var/log/rclone.log /var/log/api.log

echo "[Init] Starting services via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
