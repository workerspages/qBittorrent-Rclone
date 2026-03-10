# qBittorrent Enhanced Edition + WebDAV (PaaS 优化版)

这是一个专为 PaaS (Platform as a Service) 平台部署优化的 Docker 镜像项目。它集成了 **qBittorrent Enhanced Edition (增强版)** 与 **Rclone**，不仅可以提供强大的 BT/PT 下载功能，还内置了轻量级的 WebDAV 服务，让您可以轻松地将云端下载好的文件直接拉取到本地设备。

## ✨ 核心特性

- **自动构建最新版**：通过 GitHub Actions 每天自动从上游获取并编译最新的 qBittorrent Enhanced Edition 静态核心。
- **专为 PaaS 优化**：
  - 完美解决新版 qBittorrent 需要在终端查看随机生成密码的痛点，启动时自动注入默认账号密码。
  - 动态适配 PaaS 平台注入的 `$PORT` 环境变量。
- **内置 WebDAV 服务**：基于 Rclone 提供轻量、纯净的 WebDAV 服务，零额外依赖，方便本地播放器（如 Infuse, PotPlayer）或自动化脚本直接挂载和读取 `/data/downloads` 目录。
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

为了防止容器重启导致数据丢失，请在 PaaS 平台或本地部署时，挂载持久化存储到 `/data` 目录。容器内部会自动创建以下子目录：

- `/data/config`：存储 qBittorrent 的配置文件和种子校验数据。
- `/data/downloads`：默认的下载保存路径。WebDAV 服务仅会暴露此目录。
- `/data/rclone`：预留的 Rclone 配置文件目录（如果您需要使用 Rclone 向其他网盘推送数据）。

---

## 🚀 部署指南

### 1. 在 PaaS 平台部署 (如 Render, Zeabur, Railway 等)

1. 在您的 PaaS 控制台创建一个新的 Docker/Container 服务。
2. 填入您的镜像地址：`您的DockerHub用户名/qbittorrent-ee-rclone:latest` 或 `ghcr.io/您的GitHub用户名/您的仓库名:latest`。
3. 在 **Environment Variables (环境变量)** 设置中，添加并修改上述提及的变量（尤其是 `WEBDAV_USER` 和 `WEBDAV_PASS`）。
4. （可选）添加持久化存储卷 (Volume)，将其挂载到容器的 `/data` 路径。
5. 确保 PaaS 平台对外暴露了 `$PORT` 和 `WEBDAV_PORT` 对应的端口。

### 2. 本地使用 Docker Compose 部署测试

如果您想在本地 NAS 或 Linux 服务器上测试此镜像，可以使用以下 `docker-compose.yml` 文件：

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
