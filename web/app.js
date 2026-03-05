/* ========================================
   Alist-Rclone Web Console — App Logic
   ======================================== */
const App = {
    token: null,
    currentPage: 'dashboard',
    currentLogService: 'alist',
    statusInterval: null,

    // ========================
    // Init
    // ========================
    init() {
        this.token = localStorage.getItem('auth_token');
        if (this.token) {
            this.checkAuth();
        } else {
            this.showLogin();
        }
        this.bindEvents();
    },

    bindEvents() {
        // Login form
        document.getElementById('login-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.login();
        });

        // Nav items
        document.querySelectorAll('.nav-item').forEach((item) => {
            item.addEventListener('click', () => {
                this.navigate(item.dataset.page);
            });
        });

        // Logout
        document.getElementById('logout-btn').addEventListener('click', () => this.logout());

        // Mobile menu
        document.getElementById('mobile-menu-btn').addEventListener('click', () => {
            document.querySelector('.sidebar').classList.toggle('open');
        });

        // Log tabs
        document.querySelectorAll('.tab[data-service]').forEach((tab) => {
            tab.addEventListener('click', () => {
                document.querySelectorAll('.tab[data-service]').forEach((t) => t.classList.remove('active'));
                tab.classList.add('active');
                this.currentLogService = tab.dataset.service;
                this.loadLogs(tab.dataset.service);
            });
        });

        // Remote type change
        document.getElementById('remote-type').addEventListener('change', (e) => {
            this.renderRemoteParams(e.target.value);
        });

        // Close sidebar on page click (mobile)
        document.querySelector('.main-content').addEventListener('click', () => {
            document.querySelector('.sidebar').classList.remove('open');
        });
    },

    // ========================
    // Auth
    // ========================
    async checkAuth() {
        try {
            const res = await this.api('GET', '/api/auth/check');
            if (res.valid) {
                this.showApp(res.username);
            } else {
                this.showLogin();
            }
        } catch {
            this.showLogin();
        }
    },

    async login() {
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        const errorEl = document.getElementById('login-error');
        const btn = document.getElementById('login-btn');

        btn.disabled = true;
        btn.innerHTML = '<span>登录中...</span>';
        errorEl.style.display = 'none';

        try {
            const res = await fetch('/api/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password }),
            });
            const data = await res.json();
            if (res.ok && data.token) {
                this.token = data.token;
                localStorage.setItem('auth_token', data.token);
                this.showApp(data.username);
            } else {
                errorEl.textContent = data.error || '登录失败';
                errorEl.style.display = 'block';
            }
        } catch (err) {
            errorEl.textContent = '网络错误，请重试';
            errorEl.style.display = 'block';
        } finally {
            btn.disabled = false;
            btn.innerHTML = '<span>登  录</span>';
        }
    },

    logout() {
        this.token = null;
        localStorage.removeItem('auth_token');
        if (this.statusInterval) clearInterval(this.statusInterval);
        this.showLogin();
    },

    showLogin() {
        document.getElementById('login-screen').classList.add('active');
        document.getElementById('app-screen').classList.remove('active');
    },

    showApp(username) {
        document.getElementById('login-screen').classList.remove('active');
        document.getElementById('app-screen').classList.add('active');
        document.getElementById('user-badge').textContent = username || 'admin';
        this.loadDashboard();
        this.statusInterval = setInterval(() => this.loadStatus(), 30000);
    },

    // ========================
    // Navigation
    // ========================
    navigate(page) {
        this.currentPage = page;
        // Update nav
        document.querySelectorAll('.nav-item').forEach((item) => {
            item.classList.toggle('active', item.dataset.page === page);
        });
        // Update pages
        document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
        document.getElementById('page-' + page)?.classList.add('active');
        // Update title
        const titles = {
            dashboard: '仪表板',
            'rclone-config': 'Rclone 配置管理',
            alist: 'Alist 文件管理',
            'rclone-gui': 'Rclone Web GUI',
            logs: '日志查看器',
        };
        document.getElementById('page-title').textContent = titles[page] || page;
        // Load page data
        if (page === 'dashboard') this.loadDashboard();
        if (page === 'rclone-config') this.loadRemotes();
        if (page === 'alist') this.loadAlistFrame();
        if (page === 'rclone-gui') this.loadRcloneFrame();
        if (page === 'logs') this.loadLogs(this.currentLogService);
        // Close mobile sidebar
        document.querySelector('.sidebar').classList.remove('open');
    },

    // ========================
    // API Helper
    // ========================
    async api(method, url, body) {
        const options = {
            method,
            headers: {
                'Content-Type': 'application/json',
                Authorization: 'Bearer ' + this.token,
            },
        };
        if (body) options.body = JSON.stringify(body);
        const res = await fetch(url, options);
        if (res.status === 401) {
            this.logout();
            throw new Error('Unauthorized');
        }
        return res.json();
    },

    // ========================
    // Dashboard
    // ========================
    async loadDashboard() {
        this.loadStatus();
        this.loadRemoteCount();
    },

    async loadStatus() {
        try {
            const data = await this.api('GET', '/api/status');
            // Alist status
            const alistStatus = document.querySelector('#stat-alist .stat-status');
            alistStatus.textContent = data.alist === 'running' ? '运行中' : '已停止';
            alistStatus.className = 'stat-status ' + (data.alist === 'running' ? 'running' : 'stopped');
            // Rclone status
            const rcloneStatus = document.querySelector('#stat-rclone .stat-status');
            rcloneStatus.textContent = data.rclone === 'running' ? '运行中' : '已停止';
            rcloneStatus.className = 'stat-status ' + (data.rclone === 'running' ? 'running' : 'stopped');
            // Uptime
            document.getElementById('stat-uptime').textContent = this.formatUptime(data.uptime);
        } catch {
            // Silently fail
        }
    },

    async loadRemoteCount() {
        try {
            const data = await this.api('GET', '/api/rclone/remotes');
            document.getElementById('stat-remotes').textContent = (data.remotes?.length || 0) + ' 个';
        } catch {
            document.getElementById('stat-remotes').textContent = '-';
        }
    },

    formatUptime(seconds) {
        if (!seconds) return '-';
        const d = Math.floor(seconds / 86400);
        const h = Math.floor((seconds % 86400) / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (d > 0) return `${d}天 ${h}时 ${m}分`;
        if (h > 0) return `${h}时 ${m}分`;
        return `${m}分`;
    },

    // ========================
    // Rclone Remotes
    // ========================
    async loadRemotes() {
        const container = document.getElementById('remotes-list');
        container.innerHTML = '<div class="loading-state"><div class="spinner"></div><p>加载中...</p></div>';
        try {
            const data = await this.api('GET', '/api/rclone/remotes');
            if (!data.remotes || data.remotes.length === 0) {
                container.innerHTML = `
                    <div class="empty-state">
                        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>
                        </svg>
                        <p>暂无远程存储配置</p>
                        <button class="btn btn-primary" onclick="App.showAddRemoteModal()">添加远程存储</button>
                    </div>`;
                return;
            }
            container.innerHTML = data.remotes
                .map((r) => {
                    const params = Object.entries(r)
                        .filter(([k]) => k !== 'name' && k !== 'type')
                        .map(
                            ([k, v]) =>
                                `<div class="param-row"><span class="param-key">${this.escapeHtml(k)}</span><span class="param-value" title="${this.escapeHtml(String(v))}">${this.escapeHtml(this.maskSensitive(k, String(v)))}</span></div>`
                        )
                        .join('');
                    return `
                    <div class="remote-card">
                        <div class="remote-card-header">
                            <h4>${this.escapeHtml(r.name)} <span class="remote-type-badge">${this.escapeHtml(r.type || 'unknown')}</span></h4>
                            <div class="remote-card-actions">
                                <button class="btn-icon" onclick="App.deleteRemote('${this.escapeHtml(r.name)}')" title="删除">
                                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                                </button>
                            </div>
                        </div>
                        <div class="remote-card-body">${params || '<span style="color:var(--text-muted)">无额外参数</span>'}</div>
                    </div>`;
                })
                .join('');
        } catch (err) {
            container.innerHTML = `<div class="empty-state"><p>加载失败: ${this.escapeHtml(err.message)}</p></div>`;
        }
    },

    maskSensitive(key, value) {
        const sensitiveKeys = ['password', 'secret', 'token', 'key', 'pass'];
        if (sensitiveKeys.some((k) => key.toLowerCase().includes(k)) && value.length > 4) {
            return value.substring(0, 2) + '***' + value.substring(value.length - 2);
        }
        return value;
    },

    // ========================
    // Remote Modal
    // ========================
    showAddRemoteModal() {
        document.getElementById('modal-title').textContent = '添加远程存储';
        document.getElementById('remote-name').value = '';
        document.getElementById('remote-type').value = '';
        document.getElementById('remote-params').innerHTML = '';
        document.getElementById('modal-overlay').classList.add('active');
    },

    closeModal() {
        document.getElementById('modal-overlay').classList.remove('active');
    },

    renderRemoteParams(type) {
        const container = document.getElementById('remote-params');
        const params = this.getParamsForType(type);
        if (!params.length) {
            container.innerHTML = '';
            return;
        }
        container.innerHTML = params
            .map(
                (p) => `
            <div class="form-group">
                <label for="param-${p.name}">${this.escapeHtml(p.label)}</label>
                ${p.type === 'select'
                        ? `<select id="param-${p.name}" data-param="${p.name}">
                        ${p.options.map((o) => `<option value="${o.value}">${o.label}</option>`).join('')}
                    </select>`
                        : p.type === 'textarea'
                            ? `<textarea id="param-${p.name}" data-param="${p.name}" placeholder="${this.escapeHtml(p.placeholder || '')}"></textarea>`
                            : `<input type="${p.sensitive ? 'password' : 'text'}" id="param-${p.name}" data-param="${p.name}" placeholder="${this.escapeHtml(p.placeholder || '')}">`
                    }
            </div>`
            )
            .join('');
    },

    getParamsForType(type) {
        const common = {
            s3: [
                {
                    name: 'provider', label: 'S3 提供商', type: 'select', options: [
                        { value: 'AWS', label: 'Amazon AWS' },
                        { value: 'Cloudflare', label: 'Cloudflare R2' },
                        { value: 'DigitalOcean', label: 'DigitalOcean Spaces' },
                        { value: 'Alibaba', label: '阿里云 OSS' },
                        { value: 'Tencent', label: '腾讯云 COS' },
                        { value: 'HuaweiOBS', label: '华为云 OBS' },
                        { value: 'Minio', label: 'MinIO' },
                        { value: 'Other', label: '其他' },
                    ]
                },
                { name: 'access_key_id', label: 'Access Key ID', placeholder: 'AKIAIOSFODNN7EXAMPLE' },
                { name: 'secret_access_key', label: 'Secret Access Key', placeholder: '密钥', sensitive: true },
                { name: 'region', label: '区域', placeholder: 'us-east-1' },
                { name: 'endpoint', label: 'Endpoint', placeholder: '留空使用默认' },
            ],
            drive: [
                { name: 'client_id', label: 'Client ID', placeholder: '留空使用内置' },
                { name: 'client_secret', label: 'Client Secret', placeholder: '留空使用内置', sensitive: true },
                { name: 'root_folder_id', label: '根目录 ID', placeholder: '留空为根目录' },
                { name: 'service_account_file', label: 'SA 文件路径', placeholder: '/data/sa.json' },
            ],
            onedrive: [
                { name: 'client_id', label: 'Client ID', placeholder: '' },
                { name: 'client_secret', label: 'Client Secret', placeholder: '', sensitive: true },
                { name: 'token', label: 'Token (JSON)', type: 'textarea', placeholder: '{"access_token":"...","token_type":"Bearer",...}' },
            ],
            webdav: [
                { name: 'url', label: '服务器 URL', placeholder: 'https://example.com/remote.php/dav/files/user/' },
                { name: 'user', label: '用户名', placeholder: '' },
                { name: 'pass', label: '密码', placeholder: '', sensitive: true },
                {
                    name: 'vendor', label: '供应商', type: 'select', options: [
                        { value: 'other', label: '其他' },
                        { value: 'nextcloud', label: 'Nextcloud' },
                        { value: 'owncloud', label: 'ownCloud' },
                        { value: 'sharepoint', label: 'SharePoint' },
                    ]
                },
            ],
            sftp: [
                { name: 'host', label: '主机地址', placeholder: 'example.com' },
                { name: 'port', label: '端口', placeholder: '22' },
                { name: 'user', label: '用户名', placeholder: 'root' },
                { name: 'pass', label: '密码', placeholder: '', sensitive: true },
                { name: 'key_file', label: '密钥文件路径', placeholder: '/data/id_rsa' },
            ],
            ftp: [
                { name: 'host', label: '主机地址', placeholder: 'ftp.example.com' },
                { name: 'port', label: '端口', placeholder: '21' },
                { name: 'user', label: '用户名', placeholder: '' },
                { name: 'pass', label: '密码', placeholder: '', sensitive: true },
            ],
            dropbox: [
                { name: 'client_id', label: 'Client ID', placeholder: '' },
                { name: 'client_secret', label: 'Client Secret', placeholder: '', sensitive: true },
                { name: 'token', label: 'Token (JSON)', type: 'textarea', placeholder: '' },
            ],
            b2: [
                { name: 'account', label: 'Account ID', placeholder: '' },
                { name: 'key', label: 'Application Key', placeholder: '', sensitive: true },
            ],
            azureblob: [
                { name: 'account', label: 'Storage Account Name', placeholder: '' },
                { name: 'key', label: 'Storage Account Key', placeholder: '', sensitive: true },
                { name: 'sas_url', label: 'SAS URL', placeholder: '可选' },
            ],
            mega: [
                { name: 'user', label: '邮箱', placeholder: '' },
                { name: 'pass', label: '密码', placeholder: '', sensitive: true },
            ],
            pcloud: [
                { name: 'token', label: 'Token (JSON)', type: 'textarea', placeholder: '' },
            ],
            smb: [
                { name: 'host', label: '主机地址', placeholder: '192.168.1.100' },
                { name: 'user', label: '用户名', placeholder: '' },
                { name: 'pass', label: '密码', placeholder: '', sensitive: true },
                { name: 'domain', label: '域', placeholder: 'WORKGROUP' },
            ],
            local: [
                { name: 'root', label: '根路径', placeholder: '/data/local' },
            ],
        };
        return common[type] || [];
    },

    async saveRemote() {
        const name = document.getElementById('remote-name').value.trim();
        const type = document.getElementById('remote-type').value;
        if (!name || !type) {
            this.toast('请填写名称和类型', 'error');
            return;
        }
        const parameters = {};
        document.querySelectorAll('#remote-params [data-param]').forEach((el) => {
            const val = el.value.trim();
            if (val) parameters[el.dataset.param] = val;
        });
        try {
            await this.api('POST', '/api/rclone/remote', { name, type, parameters });
            this.toast(`远程存储 "${name}" 创建成功`, 'success');
            this.closeModal();
            this.loadRemotes();
            this.loadRemoteCount();
        } catch (err) {
            this.toast('创建失败: ' + err.message, 'error');
        }
    },

    async deleteRemote(name) {
        if (!confirm(`确定删除远程存储 "${name}" 吗？`)) return;
        try {
            await this.api('DELETE', '/api/rclone/remote/' + encodeURIComponent(name));
            this.toast(`远程存储 "${name}" 已删除`, 'success');
            this.loadRemotes();
            this.loadRemoteCount();
        } catch (err) {
            this.toast('删除失败: ' + err.message, 'error');
        }
    },

    // ========================
    // Service Management
    // ========================
    async restartService(service) {
        try {
            this.toast(`正在重启 ${service}...`, 'info');
            await this.api('POST', '/api/service/restart', { service });
            this.toast(`${service} 已重启`, 'success');
            setTimeout(() => this.loadStatus(), 2000);
        } catch (err) {
            this.toast('重启失败: ' + err.message, 'error');
        }
    },

    // ========================
    // Iframe Pages
    // ========================
    loadAlistFrame() {
        const frame = document.getElementById('alist-frame');
        if (!frame.src || frame.src === window.location.href) {
            frame.src = '/alist/';
        }
    },

    loadRcloneFrame() {
        const frame = document.getElementById('rclone-frame');
        if (!frame.src || frame.src === window.location.href) {
            frame.src = '/rclone/';
        }
    },

    // ========================
    // Logs
    // ========================
    async loadLogs(service) {
        const viewer = document.getElementById('log-viewer');
        viewer.textContent = '加载中...';
        try {
            const data = await this.api('GET', `/api/logs/${service}?lines=200`);
            viewer.textContent = data.log || '无日志';
        } catch {
            viewer.textContent = '加载日志失败';
        }
    },

    refreshLogs() {
        this.loadLogs(this.currentLogService);
    },

    // ========================
    // Utilities
    // ========================
    toast(message, type = 'info') {
        const container = document.getElementById('toast-container');
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        container.appendChild(toast);
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateX(20px)';
            toast.style.transition = '0.3s ease';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    },

    escapeHtml(str) {
        const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
        return String(str).replace(/[&<>"']/g, (c) => map[c]);
    },
};

// Boot
document.addEventListener('DOMContentLoaded', () => App.init());
