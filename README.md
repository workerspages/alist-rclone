# Alist-Rclone All-in-One

将 [Alist](https://github.com/AlistGo/alist) 和 [Rclone](https://github.com/wiserain/rclone)（mod 版本）集成到一个 Docker 镜像中，提供统一的 Web 控制台管理界面。

专为 **PaaS 平台**设计 — 无需终端，所有操作通过 Web 界面完成。

## ✨ 功能特性

- 🗂️ **Alist 文件管理** — 支持多种云存储的在线文件管理
- ☁️ **Rclone 云同步** — 强大的云存储挂载和同步工具（wiserain mod 版本）
- 🎛️ **统一 Web 控制台** — 在浏览器中管理所有配置
- 🔐 **安全登录** — 用户名密码认证保护
- 📊 **状态监控** — 实时查看服务运行状态
- 📝 **日志查看** — 在线查看所有服务日志
- 🏗️ **多架构支持** — 同时支持 `amd64` 和 `arm64`

---

## 🚀 快速部署

### 方式一：Docker Run

```bash
docker run -d \
  --name alist-rclone \
  -p 5000:80 \
  -v $(pwd)/data:/data \
  -e WEB_USERNAME=admin \
  -e WEB_PASSWORD=your_password \
  -e ALIST_ADMIN_PASSWORD=your_alist_password \
  -e TZ=Asia/Shanghai \
  ghcr.io/workerspages/alist-rclone:latest
```

### 方式二：Docker Compose（推荐）

创建 `docker-compose.yml` 文件：

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

启动：

```bash
docker compose up -d
```

### 方式三：PaaS 平台部署

大多数 PaaS 平台（如 Railway、Render、Zeabur 等）支持直接使用 Docker 镜像部署：

1. **镜像地址**：`ghcr.io/workerspages/alist-rclone:latest`
2. **端口**：设置为 `80`
3. **环境变量**：按下方表格配置
4. **持久化存储**：挂载 `/data` 目录（如平台支持）

---

## 📋 环境变量

| 变量 | 默认值 | 必填 | 说明 |
|------|--------|:---:|------|
| `WEB_USERNAME` | `admin` | ❌ | Web 控制台登录用户名 |
| `WEB_PASSWORD` | `admin` | ⚠️ | Web 控制台登录密码，**强烈建议修改** |
| `ALIST_ADMIN_USERNAME` | `admin` | ❌ | Alist 管理员用户名 |
| `ALIST_ADMIN_PASSWORD` | `admin` | ⚠️ | Alist 管理员密码，**强烈建议修改** |
| `TZ` | `Asia/Shanghai` | ❌ | 容器时区 |

> ⚠️ **安全提示**：首次部署时请务必修改 `WEB_PASSWORD` 和 `ALIST_ADMIN_PASSWORD`，不要使用默认值。

---

## 🌐 访问说明

部署完成后：
- **Alist 文件管理**：访问 `http://你的IP:端口/` 即可打开 Alist
- **Web 管理控制台**：访问 `http://你的IP:端口/console/` 管理 Rclone 配置、查看日志等

### 路由说明

| 路径 | 服务 | 说明 |
|------|------|------|
| `/` | Alist 文件管理 | Alist 原生界面（根路径直接访问） |
| `/console/` | Web 管理控制台 | 统一管理界面，需登录 |
| `/rclone/` | Rclone Web GUI | Rclone 原生管理界面 |
| `/console-api/` | 后端 API | 控制台后端接口 |

### Web 控制台功能

1. **仪表板** — 查看 Alist 和 Rclone 运行状态、运行时间、远程存储数量
2. **Rclone 配置** — 添加/删除远程存储，支持常见云存储类型：
   - Amazon S3 / 兼容存储（阿里云 OSS、腾讯云 COS、Cloudflare R2 等）
   - Google Drive、OneDrive、Dropbox
   - WebDAV、SFTP、FTP
   - Backblaze B2、Azure Blob、Mega、pCloud 等
3. **Alist 管理** — 内嵌 Alist 管理界面
4. **Rclone GUI** — 内嵌 Rclone 原生 Web GUI
5. **日志查看器** — 在线查看 Alist、Rclone、Nginx、API 四个服务的日志

---

## 📁 数据持久化

所有数据保存在 `/data` 目录下：

```
/data
├── alist/          # Alist 配置和数据库
│   ├── config.json # Alist 配置文件
│   └── data.db     # Alist 数据库
└── rclone/         # Rclone 配置和缓存
    ├── rclone.conf # Rclone 配置文件
    └── cache/      # Rclone 缓存目录
```

> 💡 请务必挂载 `/data` 目录以持久化数据，否则容器重启后配置会丢失。

---

## 🔧 使用示例

### 添加 Rclone 远程存储

1. 登录 Web 控制台
2. 进入「Rclone 配置」页面
3. 点击「添加远程存储」
4. 选择存储类型，填写参数，点击保存

### 在 Alist 中使用 Rclone 存储

Rclone 配置好远程存储后，可以在 Alist 中添加存储驱动时选择「本地存储」，挂载路径指向 Rclone 挂载的目录。

### 直接使用 Alist

访问 `/alist/` 路径，使用 `ALIST_ADMIN_USERNAME` / `ALIST_ADMIN_PASSWORD` 登录后即可管理存储。

---

## 🏗️ 镜像地址

| 仓库 | 地址 |
|------|------|
| GitHub Container Registry | `ghcr.io/workerspages/alist-rclone:latest` |
| Docker Hub | `workerspages/alist-rclone:latest` |

---

## 🔨 本地构建

```bash
git clone https://github.com/workerspages/alist-rclone.git
cd alist-rclone
docker build -t alist-rclone .
docker run -d -p 5000:80 -v $(pwd)/data:/data alist-rclone
```

## 📄 License

MIT