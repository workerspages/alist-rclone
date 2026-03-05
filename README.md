# Alist-Rclone All-in-One

将 [Alist](https://github.com/AlistGo/alist) 和 [Rclone](https://rclone.org/) 集成到一个 Docker 镜像中，提供统一的 Web 控制台管理界面。

专为 PaaS 平台设计（无需终端，所有操作通过 Web 完成）。

## ✨ 功能特性

- 🗂️ **Alist 文件管理** — 支持多种云存储的在线文件管理
- ☁️ **Rclone 云同步** — 强大的云存储挂载和同步工具
- 🎛️ **统一 Web 控制台** — 在浏览器中管理所有配置
- 🔐 **安全登录** — 用户名密码认证保护
- 📊 **状态监控** — 实时查看服务运行状态
- 📝 **日志查看** — 在线查看所有服务日志
- 🏗️ **多架构支持** — 同时支持 `amd64` 和 `arm64`

## 🚀 快速部署

### Docker Run

```bash
docker run -d \
  --name alist-rclone \
  -p 5000:80 \
  -v ./data:/data \
  -e WEB_USERNAME=admin \
  -e WEB_PASSWORD=your_password \
  -e ALIST_ADMIN_PASSWORD=your_alist_password \
  ghcr.io/workerspages/alist-rclone:latest
```

### Docker Compose

```yaml
services:
  alist-rclone:
    image: ghcr.io/workerspages/alist-rclone:latest
    container_name: alist-rclone
    restart: unless-stopped
    ports:
      - "5000:80"
    volumes:
      - ./data:/data
    environment:
      - TZ=Asia/Shanghai
      - WEB_USERNAME=admin
      - WEB_PASSWORD=your_password
      - ALIST_ADMIN_PASSWORD=your_alist_password
```

访问 `http://your-ip:5000` 即可打开 Web 控制台。

## 📋 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `WEB_USERNAME` | `admin` | Web 控制台登录用户名 |
| `WEB_PASSWORD` | `admin` | Web 控制台登录密码 |
| `ALIST_ADMIN_USERNAME` | `admin` | Alist 管理员用户名 |
| `ALIST_ADMIN_PASSWORD` | `admin` | Alist 管理员密码 |
| `TZ` | `Asia/Shanghai` | 时区设置 |

## 📁 路由说明

| 路径 | 服务 |
|------|------|
| `/` | Web 管理控制台 |
| `/alist/` | Alist 文件管理界面 |
| `/rclone/` | Rclone 原生 Web GUI |
| `/api/` | 后端 API |

## 🏗️ 镜像地址

- **GitHub Container Registry**: `ghcr.io/workerspages/alist-rclone:latest`
- **Docker Hub**: `workerspages/alist-rclone:latest`

## 📄 License

MIT