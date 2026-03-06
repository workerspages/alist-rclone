# Alist-Rclone All-in-One

将 [Alist](https://github.com/AlistGo/alist) 和 [Rclone](https://github.com/wiserain/rclone)（mod 版本）集成到一个 Docker 镜像中，提供统一的 Web 控制台管理界面。

专为 **PaaS 平台**设计 — 无需终端，所有操作通过 Web 界面完成。

## ✨ 功能特性

- 🗂️ **Alist 文件管理** — 支持多种云存储的在线文件管理
- ☁️ **Rclone 云同步** — 强大的云存储挂载和同步工具（wiserain mod 版本）
- 🎛️ **统一 Web 控制台** — 在浏览器中管理所有配置和操作
- 🔄 **高级文件传输** — 支持在不同云盘间直接互拷，支持并发、过滤等高级传输参数
- ⚙️ **配置编辑功能** — 支持在图形界面上直接修改现有的 Rclone 远程存储配置参数
- 🔐 **安全登录** — 用户名密码认证保护
- 📊 **状态监控与日志** — 实时查看服务运行状态及各组件日志
- 🏗️ **多架构支持** — 同时支持 `amd64` 和 `arm64`

---

## 🚀 快速部署

### 方式一：Docker Run

```bash
docker run -d \
  --name alist-rclone \
  -p 5000:80 \
  -v $(pwd)/data:/data \
  -v $(pwd)/host:/opt/host:ro \
  -e WEB_USERNAME=admin \
  -e WEB_PASSWORD=your_password \
  -e ALIST_ADMIN_PASSWORD=your_alist_password \
  -e TZ=Asia/Shanghai \
  ghcr.io/workerspages/alist-rclone:latest
```

> 💡 `-v $(pwd)/host:/opt/host` 用于将宿主机目录挂载到容器中。容器会自动在 Rclone 配置中添加一个名为 `host` 的本地驱动，方便你在网页上将网盘文件与宿主机直接互拷。

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
      - ./host:/opt/host:ro # 映射宿主机目录至容器内，用于本地与网盘间的文件传输
    environment:
      - TZ=Asia/Shanghai
      # Web 控制台登录凭据
      - WEB_USERNAME=admin
      - WEB_PASSWORD=your_password_here
      # Alist 管理员凭据
      - ALIST_ADMIN_USERNAME=admin
      - ALIST_ADMIN_PASSWORD=your_alist_password_here
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
- **Web 管理控制台**：访问 `http://你的IP:端口/console/` 管理 Rclone 配置、文件传输、查看日志等

### 路由说明

| 路径 | 服务 | 说明 |
|------|------|------|
| `/` | Alist 文件管理 | Alist 原生界面（根路径直接访问） |
| `/console/` | Web 管理控制台 | 统一管理界面，需登录 |
| `/console-api/` | 后端 API | 控制台后端接口 |

### Web 控制台功能

1. **仪表板** — 查看 Alist 和 Rclone 运行状态、运行时间、远程存储数量
2. **Rclone 配置** — 添加/修改/测试/删除远程存储，包括强大的实时 **连通性探测功能**
3. **定时任务** — 支持在多个 Rclone 配置间进行定时和手动文件复制、移动和同步操作。包含高级参数（如 `--transfers`并发数，`--exclude`排除等）
4. **Alist 文件管理** — 内嵌 Alist 管理主打界面，一站式管理所有文件
5. **日志** — 在线查看 Alist、Rclone、Nginx、API 的运行日志

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

### 添加和修改 Rclone 远程存储

1. 登录 Web 控制台
2. 进入「Rclone 配置」页面
3. **添加**：点击「添加远程存储」，选择存储类型，填写参数，点击保存
4. **修改**：点击现有存储卡片上的「编辑」按钮，修改密码及令牌等参数，保存更新

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

## ⬆️ 关于版本更新

本项目内置的 `Alist` 和被修改过的 `Rclone` （wiserain版本）都配置为在构建时自动拉取最新的 Release 标签。要将您的环境更新至这两者的最新版本，您只需重新构建或拉取最新的 Docker 镜像。

- **如果您使用 GitHub 仓库 (推荐)**：在 GitHub 上的 `Actions` 页面手动运行一次 `Build and Push Docker Image`，构建出最新镜像后，用 `docker compose pull && docker compose up -d` 重新部署即可。
- **如果您手动管理版本**：修改代码提交 `git push` 到仓库即可触发自动构建动作。也可直接在服务器执行强制构建：`docker compose build --no-cache && docker compose up -d`。

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
