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

# Target architecture (auto-set by Docker Buildx)
ARG TARGETARCH

# Versions (override with build args)
ARG ALIST_VERSION=latest

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
    apache2-utils \
    && rm -rf /var/cache/apk/*

# Download Alist (use TARGETARCH from Buildx)
RUN set -ex; \
    mkdir -p /app; \
    if [ "$TARGETARCH" = "amd64" ]; then ALIST_ARCH="amd64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then ALIST_ARCH="arm64"; \
    else echo "Unsupported arch: $TARGETARCH" && exit 1; fi; \
    if [ "$ALIST_VERSION" = "latest" ]; then \
    ALIST_URL="https://github.com/AlistGo/alist/releases/latest/download/alist-linux-musl-${ALIST_ARCH}.tar.gz"; \
    else \
    ALIST_URL="https://github.com/AlistGo/alist/releases/download/${ALIST_VERSION}/alist-linux-musl-${ALIST_ARCH}.tar.gz"; \
    fi; \
    echo "Downloading Alist ($ALIST_ARCH) from: $ALIST_URL"; \
    curl -fsSL "$ALIST_URL" -o /tmp/alist.tar.gz && \
    tar -xzf /tmp/alist.tar.gz -C /tmp/ && \
    mv /tmp/alist /app/alist && \
    chmod +x /app/alist && \
    rm -f /tmp/alist.tar.gz

# Download Rclone mod (wiserain fork, use TARGETARCH from Buildx)
RUN set -ex; \
    if [ "$TARGETARCH" = "amd64" ]; then RCLONE_ARCH="amd64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then RCLONE_ARCH="arm64"; \
    elif [ "$TARGETARCH" = "arm" ]; then RCLONE_ARCH="arm-v7"; \
    else echo "Unsupported arch: $TARGETARCH" && exit 1; fi; \
    RCLONE_TAG=$(curl -fsS https://api.github.com/repos/wiserain/rclone/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'); \
    RCLONE_ZIP="rclone-${RCLONE_TAG}-linux-${RCLONE_ARCH}.zip"; \
    echo "Downloading Rclone mod ($RCLONE_ARCH) tag: $RCLONE_TAG"; \
    curl -fsSL "https://github.com/wiserain/rclone/releases/download/${RCLONE_TAG}/${RCLONE_ZIP}" -o /tmp/rclone.zip && \
    unzip -q /tmp/rclone.zip -d /tmp/rclone_unzip && \
    mv /tmp/rclone_unzip/*/rclone /usr/bin/rclone && \
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

# Environment variables (non-sensitive defaults)
ENV TZ=Asia/Shanghai \
    WEB_USERNAME=admin \
    ALIST_ADMIN_USERNAME=admin

# Data volume
VOLUME ["/data"]

# Expose port
EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
