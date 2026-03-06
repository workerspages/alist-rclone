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

# ---- Initialize Alist ----
echo "[Init] Initializing Alist..."
if [ ! -f /data/alist/config.json ]; then
    echo "[Init] First run, creating Alist config..."
    mkdir -p /data/alist
    cd /data/alist

    DB_TYPE="${DB_TYPE:-sqlite3}"
    DB_HOST="${DB_HOST:-127.0.0.1}"
    DB_PORT="${DB_PORT:-3306}"
    DB_USER="${DB_USER:-root}"
    DB_PASS="${DB_PASS:-password}"
    DB_NAME="${DB_NAME:-alist}"
    DB_TABLE_PREFIX="${DB_TABLE_PREFIX:-alist_}"
    DB_SSL_MODE="${DB_SSL_MODE:-}"
    
    # If using sqlite3, let Alist generate the default config by running it once
    if [ "$DB_TYPE" = "sqlite3" ]; then
        /app/alist server --data /data/alist &
        ALIST_PID=$!
        sleep 3
        kill $ALIST_PID 2>/dev/null || true
        wait $ALIST_PID 2>/dev/null || true
    else
        echo "[Init] Configuring external database ($DB_TYPE)..."
        # Generate config.json for external DB
        cat > /data/alist/config.json <<EOF
{
  "force": false,
  "site_url": "",
  "cdn": "",
  "jwt_secret": "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)",
  "token_expires_in": 48,
  "database": {
    "type": "$DB_TYPE",
    "host": "$DB_HOST",
    "port": $DB_PORT,
    "user": "$DB_USER",
    "password": "$DB_PASS",
    "name": "$DB_NAME",
    "db_file": "data.db",
    "table_prefix": "$DB_TABLE_PREFIX",
    "ssl_mode": "$DB_SSL_MODE",
    "dsn": ""
  },
  "meilisearch": {
    "host": "http://localhost:7700",
    "api_key": "",
    "index_prefix": ""
  },
  "scheme": {
    "address": "0.0.0.0",
    "http_port": 5244,
    "https_port": -1,
    "force_https": false,
    "cert_file": "",
    "key_file": "",
    "unix_file": "",
    "unix_file_perms": ""
  },
  "temp_dir": "data/temp",
  "bleve_dir": "data/bleve",
  "dist_dir": "",
  "log": {
    "enable": true,
    "name": "log.log",
    "max_size": 50,
    "max_backups": 30,
    "max_age": 28,
    "compress": false
  },
  "delayed_start": 0,
  "max_connections": 0,
  "tls_insecure_skip_verify": true,
  "tasks": {
    "download": {
      "workers": 5,
      "max_retry": 1
    },
    "transfer": {
      "workers": 5,
      "max_retry": 2
    },
    "upload": {
      "workers": 5,
      "max_retry": 0
    },
    "copy": {
      "workers": 5,
      "max_retry": 2
    }
  },
  "cors": {
    "allow_origins": [
      "*"
    ],
    "allow_methods": [
      "*"
    ],
    "allow_headers": [
      "*"
    ]
  },
  "s3": {
    "enable": false,
    "port": 5246,
    "ssl": false
  }
}
EOF
    fi
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
