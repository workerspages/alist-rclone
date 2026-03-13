
### 终极纠错方案：回归精准注入

既然 Alist 的核心数据已经完美保存在了 TiDB 中，我们**根本不需要**打包整个 `data` 目录。我们只需要精准地将丢失的那两个核心纯文本文件（`rclone.conf` 和 `scheduled-tasks.json`）注入进去即可。这两个纯文本文件加起来通常只有几 KB，绝对不会触发限制。

请放弃使用 `tar.gz` 打包整个目录的方法，在本地分别获取这两个纯文本文件的 Base64 编码：

```bash
# 获取 rclone.conf 的 Base64
base64 /路径/到/你的/rclone.conf | tr -d '\n' > rclone_base64.txt

# 获取 scheduled-tasks.json 的 Base64
base64 /路径/到/你的/scheduled-tasks.json | tr -d '\n' > tasks_base64.txt

```

然后，使用下面这个**更加安全、且优化了底层执行逻辑的最终完整版 `manifest.yml**`。

*(注：我将启动命令中的 `echo` 替换成了 `printenv`，这是为了防止 Shell 解析变量时再次触发长度限制，同时加入了 `sh -c` 确保复杂命令在 Docker 中被正确解析)*

```yaml
---
applications:
  - name: alist-rclone
    memory: 4G
    disk_quota: 5G
    instances: 1
    docker:
      image: your-registry.com/your-username/alist-rclone:latest
    env:
      # 1. 填入你获取到的 rclone.conf 的 Base64 编码
      RCLONE_CONF_BASE64: "在此处填入rclone.conf的完整Base64编码字符串"
      
      # 2. 填入你获取到的 scheduled-tasks.json 的 Base64 编码
      SCHEDULED_TASKS_BASE64: "在此处填入scheduled-tasks.json的完整Base64编码字符串"
      
    # 最终完整启动命令：安全创建目录 -> 使用 printenv 精准还原两个核心文件 -> 启动主进程
    command: "sh -c 'mkdir -p /data/rclone /opt/alist/data/rclone && printenv RCLONE_CONF_BASE64 | base64 -d > /data/rclone/rclone.conf && printenv SCHEDULED_TASKS_BASE64 | base64 -d > /data/rclone/scheduled-tasks.json && cp -r /data/rclone/* /opt/alist/data/rclone/ 2>/dev/null || true && exec /usr/bin/supervisord -n -c /etc/supervisord.conf'"

```

请替换好真实的 `image` 和两段 Base64 字符串，再次执行 `cf push`。这次剥离了冗余数据，轻装上阵，应用应该就能瞬间恢复成 `Running` 状态了！
