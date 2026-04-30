# QManager

<div align="center">
  <img src="public/qmanager-logo.svg" alt="QManager Logo" width="120" />
  <h3>现代化的 Quectel 蜂窝模组 Web 管理界面</h3>
  <p>用直观的网页界面可视化、配置并优化蜂窝网络性能。</p>

  ![Version](https://img.shields.io/badge/version-v0.1.20-blue?style=flat-square)
  ![License](https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-green?style=flat-square)
  ![Platform](https://img.shields.io/badge/platform-OpenWRT-orange?style=flat-square)
  ![Next.js](https://img.shields.io/badge/Next.js-16-black?style=flat-square)
  ![React](https://img.shields.io/badge/React-19-61DAFB?style=flat-square)
</div>

---

本项目继承自 **[dr-dolomite/QManager](https://github.com/dr-dolomite/QManager)**。本 **`po1son7`（GitHub）/ `aowu2048`（Gitee）** 在功能上与上游对齐，并针对 **中国大陆网络** 调整了安装与更新源。

### 推荐仓库分工（本 fork 的典型流程）

| 角色 | 仓库 | 用途 |
|------|------|------|
| **主仓库** | [po1son7/QManager](https://github.com/po1son7/QManager) | 在此做「大陆版」修改、打 tag、`bun run package` 后发 **GitHub Release** |
| **镜像 / OTA 默认** | [aowu2048/QManager](https://gitee.com/aowu2048/QManager) | 将 **同一 tag** 下的 `qmanager.tar.gz`、`sha256sum.txt`（及需同步的脚本）同步到 **Gitee Release**；设备默认 OTA **只连 Gitee** |
| **上游** | [dr-dolomite/QManager](https://github.com/dr-dolomite/QManager) | 功能与致谢来源；不必作为本 fork 的日常 OTA 目标 |

> **致谢**：原版 QManager 是 [SimpleAdmin](https://github.com/dr-dolomite/simpleadmin-mockup) 的精神续作，专为 RM520N-GL、RM551E-GL 等 Quectel 模组深度优化。

---

## 中国大陆快速安装（推荐）

SSH 登录 OpenWRT 后 **任选其一**：

### A. Gitee Raw + 默认 Gitee Release（延迟最低时需先在 Gitee 侧同步 Release 附件）

```sh
curl -fsSL -o /tmp/qmanager-installer.sh \
  "https://gitee.com/aowu2048/QManager/raw/main/qmanager-installer.sh" && sh /tmp/qmanager-installer.sh
```

安装脚本默认 **`mirror=gitee`**，从 **Gitee Release** 拉 `qmanager.tar.gz` / `sha256sum.txt`。发布流程中须保持 **GitHub 与 Gitee 同一 tag、同一附件内容**，再在路由器上升级或安装。

### B. ghproxy + GitHub Raw（适用于 Release 仅发布在 GitHub 的情形）

```sh
curl -fsSL -o /tmp/qmanager-installer.sh \
  "https://ghproxy.net/https://raw.githubusercontent.com/po1son7/QManager/main/qmanager-installer.sh" \
  && sh /tmp/qmanager-installer.sh --mirror github_proxy
```

### C. 仅使用 GitHub 直连（在非大陆或已自备国际出口时使用）

```sh
curl -fsSL -o /tmp/qmanager-installer.sh \
  "https://raw.githubusercontent.com/po1son7/QManager/main/qmanager-installer.sh" \
  && sh /tmp/qmanager-installer.sh --mirror github --repo po1son7/QManager
```

### 卸载

```sh
curl -fsSL -o /tmp/qmanager-installer.sh \
  "https://gitee.com/aowu2048/QManager/raw/main/qmanager-installer.sh" \
  && sh /tmp/qmanager-installer.sh --uninstall
```

### 环境与参数说明（安装脚本）

| 环境变量 / 参数 | 说明 |
|-----------------|------|
| `QMANAGER_MIRROR` / `--mirror` | `gitee`（默认）、`github`、`github_proxy` |
| `QMANAGER_GITEE_REPO` / `--gitee-repo` | Gitee 仓库，默认 `aowu2048/QManager` |
| `QMANAGER_REPO` / `--repo` | GitHub `owner/repo`，默认 `po1son7/QManager` |
| `QMANAGER_TAG` / `--tag` | 固定版本标签，如不指定则用 `jq` 解析最新 Release |
| `QMANAGER_CHANNEL` / `--channel` | `stable` / `prerelease` / `any` |

**依赖**：脚本在需要自动解析版本时要求设备已安装 **`jq`**（与 QManager 本身推荐依赖一致：`opkg install jq`）。

---

## OTA（设备内在线更新）

逻辑在 **`/usr/lib/qmanager/mirror.sh`**。**默认 OTA 源为 Gitee**（`mirror_type=gitee`、`mirror_repo=aowu2048/QManager`）。首次写入 `quecmanager.update`（例如第一次打开软件更新页）时会自动写入上述默认值，并一并记录 **`mirror_github_repo=po1son7/QManager`**；若在 UCI 中将 `mirror_type` 改为 **`github`** 或 **`github_proxy`**，OTA 则改从对应的 **GitHub fork**（默认 `po1son7/QManager`）拉取 Release。

- 需要临时经 GitHub（含大陆 ghproxy）：将 UCI `mirror_type` 设为 `github` 或 `github_proxy`。  
- 自上游原版迁入、且仍须固定跟踪上游仓库的设备：可将 `mirror_type` 设为 `github`，`mirror_github_repo` 设为 `dr-dolomite/QManager`。

---

## 视频优化 / 流量伪装（nfqws）

设备端 **`qmanager_dpi_install`** 默认通过 **`https://ghproxy.net/`** 转发对 **GitHub API** 与 **zapret Release 附件**的请求；在可直连 GitHub 的网络环境中，可将环境变量设为关闭代理：

```sh
export ZAPRET_USE_GHPROXY=0
```

（由 init / procd 拉起时可在对应 service 环境中配置。）

---

## 功能概览

- **信号与网络**：实时 RSRP/RSRQ/SINR、历史曲线、网络事件、延迟与带宽、流量统计  
- **蜂窝配置**：锁频/锁小区/锁塔、APN、SIM 配置档、短信、IMEI、FPLMN、MBN  
- **本地网络**：以太网、TTL/HL、MTU、NAT、DNS、视频优化（nfqws）、Traffic Masquerade  
- **可靠性**：四级看门狗、邮件/短信告警、OTA、Tailscale  
- **界面**：亮色/暗色、响应式、Cookie 会话、AT 控制台、向导  

完整特性列表与技术细节见 **`docs/`** 目录。

---

## 本地开发（中国大陆提示）

开发环境可使用 **镜像加速** NPM / Bun（示例）：

```bash
npm config set registry https://registry.npmmirror.com
# Bun 安装与镜像：见 https://bun.sh/docs/install
git clone https://github.com/po1son7/QManager.git
cd QManager
bun install
bun run dev
```

浏览器打开 [http://localhost:3000](http://localhost:3000)，开发模式会将 `/cgi-bin/*` 代理到路由器（参见 `next.config.ts`）。

```bash
bun run build
bun run package
```

产物 `qmanager.tar.gz` + `sha256sum.txt` 需上传至 **GitHub Release**，并按需同步至 **Gitee Release**。

### 维护者脚本（不进仓库）

与个人流程相关的 PowerShell 放在 **仓库目录外**，例如：`E:\Myproject\QM-release-scripts\`。  
在该目录查阅 **`README.txt`**，并将环境变量 **`QM_REPO_ROOT`** 设为本地 `QManager` 克隆的根目录路径。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Myproject\QM-release-scripts\full-upstream-release-gitee.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Myproject\QM-release-scripts\sync-github-releases-to-gitee.ps1
```

脚本从 **`QM_REPO_ROOT\package.json`** 读取版本作 tag；**不会**修改路由器镜像 / `qmanager-installer.sh`（仍由仓库内现有文件负责）。

---

## 文档索引

| 文档 | 内容 |
|------|------|
| [docs/README.md](docs/README.md) | 英文文档索引（上游风格） |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | 部署与大陆镜像说明 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构 |
| [docs/API-REFERENCE.md](docs/API-REFERENCE.md) | CGI API |

---

## 许可证与支持

本项目采用 **[MIT License with Commons Clause](LICENSE)**：**不得**售卖或作为商业产品及付费服务分发（fork 亦然）。商用需联系原版作者。**赞助事宜建议优先联系原版作者：[dr-dolomite](https://github.com/sponsors/dr-dolomite)**。

---

<div align="center">
  <p>Fork（GitHub）：<a href="https://github.com/po1son7/QManager">po1son7/QManager</a> · 大陆镜像（Gitee）：<a href="https://gitee.com/aowu2048/QManager">aowu2048/QManager</a></p>
  <p>上游：<a href="https://github.com/dr-dolomite">DrDolomite</a></p>
</div>
