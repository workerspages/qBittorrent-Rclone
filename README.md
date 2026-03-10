
# qBittorrent Enhanced Edition + WebDAV (PaaS 优化版)

这是一个专为 PaaS (Platform as a Service) 平台部署优化的 Docker 镜像项目。它集成了 **qBittorrent Enhanced Edition (增强版)** 与 **Rclone**，不仅可以提供强大的 BT/PT 下载功能，还内置了轻量级的 WebDAV 服务，让您可以轻松地将云端下载好的文件直接拉取到本地设备。

## ✨ 核心特性

- **自动构建最新版**：通过 GitHub Actions 每天自动从上游获取并编译最新的 qBittorrent Enhanced Edition 静态核心。
- **专为 PaaS 优化**：
  - 完美解决新版 qBittorrent 需要在终端查看随机生成密码的痛点，启动时自动注入默认账号密码。
  - 动态适配 PaaS 平台注入的 `$PORT` 环境变量。
  - 容器启动时自动修复 `/data` 目录读写权限，解决 PaaS 挂载存储卷时的 `Permission denied` 问题。
- **内置 WebDAV 服务**：基于 Rclone 提供轻量、纯净的 WebDAV 服务，零额外依赖，默认指向 `/data/downloads` 下载目录。
- **双端镜像推送**：自动将构建好的镜像推送到 Docker Hub 和 GitHub Container Registry (ghcr.io)。

---

## ⚙️ 环境变量 (Environment Variables)

在 PaaS 平台部署时，您可以通过设置以下环境变量来配置您的容器：

| 变量名 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `PORT` | `8080` | qBittorrent WebUI 面板端口。部分 PaaS 会自动强行注入此变量。 |
| `WEBDAV_PORT` | `8081` | Rclone WebDAV 服务的监听端口。 |
| `WEBDAV_USER` | `admin` | WebDAV 服务的登录用户名，**强烈建议修改**。 |
| `WEBDAV_PASS` | `password` | WebDAV 服务的登录密码，**强烈建议修改**。 |
| `TZ` | `Asia/Shanghai` | 容器时区。 |

---

## 📂 目录结构与数据持久化 (Volumes)

为了防止容器重启导致数据丢失，请在 PaaS 平台或本地部署时，挂载持久化存储卷 (Volume) 到容器内的 `/data` 目录。容器启动时会自动创建并赋予以下子目录最高读写权限：

- `/data/config`：存储 qBittorrent 的配置文件和种子校验数据。
- `/data/downloads`：固定的默认下载保存路径。WebDAV 服务仅会暴露此目录以供本地拉取。
- `/data/rclone`：预留的 Rclone 配置文件目录。

---

## 🚀 部署指南

### 1. 在 PaaS 平台部署 (如 Render, Zeabur, Railway 等)

1. 在您的 PaaS 控制台创建一个新的 Docker/Container 服务。
2. 填入您的镜像地址：`您的DockerHub用户名/qbittorrent-ee-rclone:latest` 或 `ghcr.io/您的GitHub用户名/您的仓库名:latest`。
3. 在 **Environment Variables (环境变量)** 设置中，添加并修改上述提及的变量（务必修改 `WEBDAV_USER` 和 `WEBDAV_PASS`）。
4. （非常重要）添加持久化存储卷 (Volume)，将其挂载到容器的 `/data` 路径。
5. 确保 PaaS 平台对外暴露了 `$PORT` 和 `WEBDAV_PORT` 对应的端口。

### 2. 本地使用 Docker Compose 部署测试

如果您想在本地测试此镜像，可以使用以下 `docker-compose.yml` 文件：

```yaml
version: "3.8"
services:
  qbittorrent:
    image: ghcr.io/your-github-username/your-repo-name:latest
    container_name: qbittorrent-webdav
    restart: unless-stopped
    environment:
      - PORT=8080
      - WEBDAV_PORT=8081
      - WEBDAV_USER=myuser
      - WEBDAV_PASS=mypassword
      - TZ=Asia/Shanghai
    ports:
      - "8080:8080" # qBittorrent WebUI
      - "8081:8081" # WebDAV Port
      - "6881:6881" # BT TCP
      - "6881:6881/udp" # BT UDP
    volumes:
      - ./data:/data

```

运行命令启动：

```bash
docker-compose up -d

```

---

## 💡 使用说明与默认凭据

### qBittorrent WebUI 面板

* **访问地址**：`http://<您的IP或PaaS域名>:<PORT>`
* **默认账号**：`admin`
* **默认密码**：`adminadmin`

> **⚠️ 警告**：为了您的数据安全，请在首次登录后，立即前往 **设置 -> Web UI** 中修改账号和密码！

---

## 🔄 使用 Rclone 将文件从云端拉取到本地

当 qBittorrent 在云端 PaaS 平台完成下载后，您可以使用本地电脑上的 `rclone` 工具，通过 WebDAV 协议将文件全自动拉取回来。

### 步骤 1：在本地电脑配置 Rclone

1. 在本地电脑终端或命令提示符中运行：
```bash
rclone config

```


2. 按照提示进行以下选择和输入：
* 输入 `n` (新建远端 New remote)
* 命名为：`paas-webdav` (或者您喜欢的其他名字)
* 类型 (Type) 选择：`webdav`
* URL 输入：`http://<您的PaaS域名或IP>:8081` (请替换为实际地址和映射的 WebDAV 端口)
* Vendor 选择：`other`
* User 输入：您在环境变量中设置的 `WEBDAV_USER`
* Password 输入：选择 `y` 输入自己的密码，然后输入您在环境变量中设置的 `WEBDAV_PASS`
* Bearer token：直接回车跳过
* 确认配置无误后保存并退出。



### 步骤 2：执行同步/下载命令

配置完成后，打开本地电脑的终端，根据您的需求选择以下命令执行下载：

**场景 A：仅复制文件到本地（保留云端文件）**
适合需要做本地备份，同时让云端继续做种的场景。

```bash
rclone copy paas-webdav:/ /您的/本地/下载路径/ --transfers 4 --progress

```

**场景 B：将文件移动到本地（下载后自动清理云端）**
适合 PaaS 平台存储空间有限的场景，下载成功后会自动删除云端文件以释放空间。

```bash
rclone move paas-webdav:/ /您的/本地/下载路径/ --delete-empty-src-dirs --transfers 4 --progress

```

**命令参数解析：**

* `paas-webdav:/`：刚刚配置的远端名称及根目录（对应容器内的 `/data/downloads`）。
* `/您的/本地/下载路径/`：请修改为您本地实际存放文件的绝对路径（如 Windows 下的 `D:\Downloads\`）。
* `--transfers 4`：设置同时下载 4 个文件，可根据本地宽带情况调高或调低。
* `--progress`：在终端实时显示详细的下载进度条、速度和 ETA。
* `--delete-empty-src-dirs`：文件移动走后，顺便删除云端遗留的空文件夹。

---

## 🛠️ GitHub Actions 自动化构建设置

Fork 或克隆此仓库后，要启用自动构建推送到 Docker Hub：

1. 前往 GitHub 仓库的 **Settings -> Secrets and variables -> Actions**。
2. 添加 `DOCKER_USERNAME`（您的 Docker Hub 账号）。
3. 添加 `DOCKER_PASSWORD`（您的 Docker Hub Access Token）。
4. 提交并推送到 `main` 分支，Actions 工作流将自动运行。

---

*Powered by [qBittorrent-Enhanced-Edition](https://github.com/c0re100/qBittorrent-Enhanced-Edition) and [Rclone*](https://rclone.org/)

```

这个 README 文件现在不仅包含部署指南，还形成了一个完整的闭环指导。您是否需要我为您整理一份将代码提交至 GitHub 并触发自动化构建的完整 Git 命令流程？

```
