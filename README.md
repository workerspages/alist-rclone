
# Alist-Rclone All-in-One

将 [Alist](https://github.com/AlistGo/alist) 和 [Rclone](https://github.com/wiserain/rclone)（mod 版本）集成到一个 Docker 镜像中，提供统一的 Web 控制台管理界面。

专为 **PaaS 平台与 VPS** 设计 — 无需终端，所有操作通过 Web 界面完成。

## ✨ 功能特性

- 🗂️ **Alist 文件管理** — 支持多种云存储的在线文件管理
- ☁️ **Rclone 云同步** — 强大的云存储挂载和同步工具（wiserain mod 版本）
- 🎛️ **统一 Web 控制台** — 在浏览器中管理所有配置和操作
- 🔄 **高级文件传输** — 支持在不同云盘间直接互拷，支持并发、过滤等高级传输参数
- ⚙️ **配置编辑功能** — 支持在图形界面上直接修改现有的 Rclone 远程存储配置参数
- 🔐 **安全登录** — 用户名密码认证保护
- 📊 **状态监控与日志** — 实时查看服务运行状态及各组件日志
- ☁️ **无状态环境支持** — 专为 PaaS 设计，支持通过 `SYNC_DEST` 自动同步全站状态到 S3/WebDAV，彻底解决容器重启数据丢失问题
- 🏗️ **多架构支持** — 同时支持 `amd64` 和 `arm64`

---

## 🚀 快速部署

### 方式一：Docker Run (适合常规 VPS)

```bash
docker run -d \
  --name alist-rclone \
  -p 5000:8080 \
  -v $(pwd)/data:/data \
  -v $(pwd)/host:/opt/host:ro \
  -e WEB_USERNAME=admin \
  -e WEB_PASSWORD=your_password \
  -e ALIST_ADMIN_PASSWORD=your_alist_password \
  -e TZ=Asia/Shanghai \
  ghcr.io/workerspages/alist-rclone:main

```

> 💡 `-v $(pwd)/host:/opt/host` 用于将宿主机目录挂载到容器中。容器会自动在 Rclone 配置中添加一个名为 `host` 的本地驱动，方便你在网页上将网盘文件与宿主机直接互拷。

### 方式二：Docker Compose（推荐）

创建 `docker-compose.yml` 文件：

```yaml
services:
  alist-rclone:
    image: ghcr.io/workerspages/alist-rclone:main
    container_name: alist-rclone
    restart: unless-stopped
    ports:
      - "5244:8080"
    volumes:
      - ./data:/data
      - ./host:/opt/host:ro # 映射宿主机目录至容器内，用于本地与网盘间的文件传输
    environment:
      - TZ=Asia/Shanghai
      - SWAP_SIZE_MB=512
      # Web 控制台登录凭据
      - WEB_USERNAME=admin
      - WEB_PASSWORD=admin
      # Alist 管理员凭据
      - ALIST_ADMIN_USERNAME=admin
      - ALIST_ADMIN_PASSWORD=admin

```

启动：

```bash
docker compose up -d

```

### 方式三：PaaS 平台部署 (无持久化存储环境)

大多数 PaaS 平台（如 Railway、Render、Zeabur、Koyeb 等）支持直接使用 Docker 镜像部署：

1. **镜像地址**：`ghcr.io/workerspages/alist-rclone:main`
2. **端口**：设置为 `8080`
3. **环境变量**：按下方表格配置
4. **持久化存储**：如果平台无持久化本地存储，请务必参考下方的 `SYNC_DEST` 无状态持久化方案。

---

## 📋 环境变量

| 变量 | 默认值 | 必填 | 说明 |
| --- | --- | --- | --- |
| `WEB_USERNAME` | `admin` | ✅ | Web 控制台登录用户名 |
| `WEB_PASSWORD` | `admin` | ⚠️ | Web 控制台登录密码，**强烈建议修改** |
| `ALIST_ADMIN_USERNAME` | `admin` | ✅ | Alist 管理员用户名 |
| `ALIST_ADMIN_PASSWORD` | `admin` | ⚠️ | Alist 管理员密码，**强烈建议修改** |
| `TZ` | `Asia/Shanghai` | ✅ | 容器时区 |
| `SYNC_DEST` | - | ❌ | **[无状态 PaaS 专用]** 外部配置备份地址（如 S3 或 WebDAV）。配置后每次启动自动拉取，并每 5 分钟自动备份 `/data` 目录 |
| `CUSTOM_CA_CERT_PATH` | - | ❌ | 自定义 CA 证书的容器内路径（可为文件或目录），用于信任私有/自签证书 |
| `SWAP_SIZE_MB` | - | ❌ | 交换内存（虚拟内存）大小，单位为MB。例如 `512`表示分配512MB。开启此功能可能需要开启容器特权模式 |

> ⚠️ **安全提示**：首次部署时请务必修改 `WEB_PASSWORD` 和 `ALIST_ADMIN_PASSWORD`，不要使用默认值。

---

## ☁️ 无状态 PaaS 平台终极持久化方案 (SYNC_DEST)

在 Koyeb、Render 等没有本地持久化存储（Volume）的 PaaS 平台上，容器重启会导致所有应用数据和配置丢失。

为了解决此问题，您只需配置 `SYNC_DEST` 环境变量，容器就会在启动时**自动从外部存储拉取完整环境**，并在运行期间**每 5 分钟自动将最新状态备份回外部存储**（自动排除不必要的缓存和临时文件）。此方案将同时备份 Alist 数据库与 Rclone 配置。

### 1. 备份到 S3 存储桶（推荐，以 Cloudflare R2 为例）

添加环境变量：

```text
SYNC_DEST=":s3,provider='Cloudflare',endpoint='[https://xxx.r2.cloudflarestorage.com](https://xxx.r2.cloudflarestorage.com)',access_key_id='你的AK',secret_access_key='你的SK':/my-backup-bucket/alist-data"

```

### 2. 备份到 WebDAV（以坚果云为例）

⚠️ **极度重要提示**：WebDAV 的密码 (`pass`) **绝对不能填写明文**！必须使用 Rclone 进行混淆（Obscured）。

1. 在本地电脑或任意终端执行：`rclone obscure "你的坚果云应用密码"` （会输出一段类似 `v2x...` 的密文）。
2. 将获取到的密文填入环境变量（注意 `vendor='other'` 参数也是必须的）：

```text
SYNC_DEST=":webdav,url='[https://dav.jianguoyun.com/dav/',vendor='other',user='你的坚果云账号',pass='这里填入获取到的密文':/alist-backup-folder](https://dav.jianguoyun.com/dav/',vendor='other',user='你的坚果云账号',pass='这里填入获取到的密文':/alist-backup-folder)"

```

> **注意**：如果您使用的是常规 VPS 或支持本地硬盘挂载的环境，完全可以忽略此变量，系统默认依靠本地 `/data` 目录保存数据。

---

## 🌐 访问说明

部署完成后：

* **Alist 文件管理**：访问 `http://你的IP:端口/` 即可打开 Alist
* **Web 管理控制台**：访问 `http://你的IP:端口/console/` 管理 Rclone 配置、文件传输、查看日志等

### 路由说明

| 路径 | 服务 | 说明 |
| --- | --- | --- |
| `/` | Alist 文件管理 | Alist 原生界面（根路径直接访问） |
| `/console/` | Web 管理控制台 | 统一管理界面，需登录 |
| `/console-api/` | 后端 API | 控制台后端接口 |

### Web 控制台功能

1. **仪表板** — 查看 Alist 和 Rclone 运行状态、运行时间、远程存储数量
2. **Rclone 配置** — 添加/修改/测试/删除远程存储，包括强大的实时 **连通性探测功能**
3. **定时任务** — 支持在多个 Rclone 配置间进行定时和手动文件复制、移动和同步操作。包含高级参数（如 `--transfers`并发数，`--exclude`排除等）
4. **Alist 文件管理** — 内嵌 Alist 管理主打界面，一站式管理所有文件
5. **日志** — 在线查看 Alist、Rclone、Nginx、API 的运行日志

### 🔌 后端 API 使用指南

如果您希望通过脚本自动化调用控制器功能（如触发定时任务等），可以直接调用 `/console-api/` 接口：

**1. 获取 Token (登录)**

```http
POST /console-api/login
Content-Type: application/json

{"username": "admin", "password": "your_password"}

```

响应中将返回 `token`。

**2. 调用接口**
在后续其他请求中放入 Header 即可通信：
`Authorization: Bearer <获取到的 Token>`

**常用端点示例**：

* `GET /console-api/status` : 获取容器各服务运行状态
* `GET /console-api/rclone/remotes` : 枚举所有网盘配置
* `POST /console-api/tasks/{task_id}/run` : 立即触发执行某个转移任务
* `POST /console-api/service/restart` : 重启 Alist/Rclone 服务 (`{"service": "alist"}`)
*(如果需要更详尽的接口，请查阅容器内的 `server/index.js` 路由定义)*

---

## 📁 数据持久化

对于有本地硬盘的环境（VPS/NAS），所有数据默认保存在 `/data` 目录下：

```
/data
├── alist/          # Alist 配置和本地 SQLite 数据库
│   ├── config.json # Alist 配置文件
│   └── data.db     # Alist 数据库
└── rclone/         # Rclone 配置和缓存
    ├── rclone.conf # Rclone 配置文件
    ├── scheduled-tasks.json # 定时任务配置文件
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
| --- | --- |
| GitHub Container Registry | `ghcr.io/workerspages/alist-rclone:main` |
| Docker Hub | `workerspages/alist-rclone:main` |

---

## ⬆️ 关于版本更新

本项目内置的 `Alist` 和被修改过的 `Rclone` （wiserain版本）都配置为在构建时自动拉取最新的 Release 标签。要将您的环境更新至这两者的最新版本，您只需重新构建或拉取最新的 Docker 镜像。

* **如果您使用 GitHub 仓库 (推荐)**：在 GitHub 上的 `Actions` 页面手动运行一次 `Build and Push Docker Image`，构建出最新镜像后，用 `docker compose pull && docker compose up -d` 重新部署即可。
* **如果您手动管理版本**：修改代码提交 `git push` 到仓库即可触发自动构建动作。也可直接在服务器执行强制构建：`docker compose build --no-cache && docker compose up -d`。

---

## 🔨 本地构建

```bash
git clone [https://github.com/workerspages/alist-rclone.git](https://github.com/workerspages/alist-rclone.git)
cd alist-rclone
docker build -t alist-rclone .
docker run -d -p 5000:8080 -v $(pwd)/data:/data alist-rclone

```

## 📄 License

MIT


