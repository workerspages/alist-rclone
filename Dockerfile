# ========================================
# Stage 1: Build Node.js backend
# ========================================
FROM node:20-alpine AS builder

WORKDIR /build/server
COPY server/package.json server/package-lock.json* ./
RUN npm install --production
COPY server/ ./

# ========================================
# Stage 2: Final image
# ========================================
FROM alpine:3.20

LABEL maintainer="workerspages"
LABEL org.opencontainers.image.source="https://github.com/workerspages/alist-rclone"
LABEL org.opencontainers.image.description="Alist + Rclone All-in-One with Web Console"

# Versions (override with build args)
ARG ALIST_VERSION=latest
ARG RCLONE_VERSION=current

# Install base packages
RUN apk add --no-cache \
    nginx \
    supervisor \
    nodejs \
    npm \
    curl \
    ca-certificates \
    fuse3 \
    tzdata \
    bash \
    unzip \
    && rm -rf /var/cache/apk/*

# Detect architecture and download Alist
RUN set -ex; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64)  ALIST_ARCH="amd64" ;; \
        aarch64) ALIST_ARCH="arm64" ;; \
        armv7l)  ALIST_ARCH="armv7" ;; \
        *)       echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac; \
    if [ "$ALIST_VERSION" = "latest" ]; then \
        ALIST_URL="https://github.com/AlistGo/alist/releases/latest/download/alist-linux-musl-${ALIST_ARCH}.tar.gz"; \
    else \
        ALIST_URL="https://github.com/AlistGo/alist/releases/download/${ALIST_VERSION}/alist-linux-musl-${ALIST_ARCH}.tar.gz"; \
    fi; \
    echo "Downloading Alist from: $ALIST_URL"; \
    curl -fsSL "$ALIST_URL" -o /tmp/alist.tar.gz && \
    tar -xzf /tmp/alist.tar.gz -C /tmp/ && \
    mv /tmp/alist /app/alist && \
    chmod +x /app/alist && \
    rm -f /tmp/alist.tar.gz

# Download Rclone
RUN set -ex; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64)  RCLONE_ARCH="amd64" ;; \
        aarch64) RCLONE_ARCH="arm64" ;; \
        armv7l)  RCLONE_ARCH="arm" ;; \
        *)       echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac; \
    curl -fsSL "https://downloads.rclone.org/rclone-${RCLONE_VERSION}-linux-${RCLONE_ARCH}.zip" -o /tmp/rclone.zip && \
    unzip -q /tmp/rclone.zip -d /tmp/ && \
    mv /tmp/rclone-*/rclone /usr/bin/rclone && \
    chmod +x /usr/bin/rclone && \
    rm -rf /tmp/rclone*

# Create directories
RUN mkdir -p /app/web /app/server /data/alist /data/rclone /var/log/nginx

# Copy web frontend
COPY web/ /app/web/

# Copy Node.js backend
COPY --from=builder /build/server/ /app/server/

# Copy configs
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY supervisor/supervisord.conf /etc/supervisord.conf

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables
ENV TZ=Asia/Shanghai \
    WEB_USERNAME=admin \
    WEB_PASSWORD=admin \
    ALIST_ADMIN_USERNAME=admin \
    ALIST_ADMIN_PASSWORD=admin

# Data volume
VOLUME ["/data"]

# Expose port
EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
