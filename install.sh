#!/bin/bash
set -e

echo "================================================="
echo " qBittorrent-Rclone One-Click Deployment Script"
echo "================================================="

# 1. 检查 root 权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (例如: sudo bash install.sh)"
  exit 1
fi

# 检查是否开启全自动模式
AUTO_MODE=0
if [ "$1" = "-auto" ] || [ "$1" = "--auto" ]; then
    AUTO_MODE=1
    echo "已开启全自动安装模式，将使用默认配置或环境变量配置。"
fi

# 2. 检查操作系统 (仅支持 Debian/Ubuntu)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ] && [ "$ID" != "debian" ]; then
        echo "警告: 此脚本主要为 Debian/Ubuntu 设计。当前系统是: $ID。安装可能会失败。"
        if [ $AUTO_MODE -eq 0 ]; then
            read -p "是否继续? [y/N]: " continue_install
            if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            echo "全自动模式下忽略系统警告，继续安装..."
        fi
    fi
else
    echo "无法检测操作系统，假定支持继续..."
fi

# 3. 收集配置信息
echo ""
echo "--- 基础配置 ---"

if [ $AUTO_MODE -eq 0 ]; then
    read -p "请输入 qBittorrent WebUI 用户名 [默认: admin]: " INPUT_QBT_USER
    read -p "请输入 qBittorrent WebUI 密码 [默认: adminadmin]: " INPUT_QBT_PASS
    read -p "请输入对外 HTTP 端口 [默认: 8080]: " INPUT_PORT
    read -p "请输入 WebDAV 用户名 [默认: admin]: " INPUT_WEBDAV_USER
    read -p "请输入 WebDAV 密码 [默认: password]: " INPUT_WEBDAV_PASS
    read -p "请输入安装路径 [默认: /opt/qBittorrent-Rclone]: " INPUT_INSTALL_DIR
fi

QBT_USER=${INPUT_QBT_USER:-${QBT_USER:-admin}}
QBT_PASS=${INPUT_QBT_PASS:-${QBT_PASS:-adminadmin}}
PORT=${INPUT_PORT:-${PORT:-8080}}
WEBDAV_USER=${INPUT_WEBDAV_USER:-${WEBDAV_USER:-admin}}
WEBDAV_PASS=${INPUT_WEBDAV_PASS:-${WEBDAV_PASS:-password}}
INSTALL_DIR=${INPUT_INSTALL_DIR:-${INSTALL_DIR:-/opt/qBittorrent-Rclone}}

echo "最终使用的配置:"
echo "qBittorrent 用户名: $QBT_USER"
echo "HTTP 端口: $PORT"
echo "WebDAV 用户名: $WEBDAV_USER"
echo "安装路径: $INSTALL_DIR"
echo ""

# 4. 安装基础依赖
echo "正在更新软件包列表并安装基础依赖..."
apt-get update
apt-get install -y curl unzip bash tzdata ca-certificates python3 python3-pip

if ! apt-get install -y python3-psutil python3-requests; then
    echo "通过 apt 安装 python 依赖失败，尝试使用 pip3..."
    pip3 install psutil requests --break-system-packages || pip3 install psutil requests
fi
pip3 install qbittorrent-api --break-system-packages || pip3 install qbittorrent-api

# 5. 检测架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        QBT_ARCH="x86_64-linux-musl_static"
        CADDY_ARCH="amd64"
        ;;
    aarch64)
        QBT_ARCH="aarch64-linux-musl_static"
        CADDY_ARCH="arm64"
        ;;
    *)
        echo "不支持的系统架构: $ARCH"
        exit 1
        ;;
esac

# 6. 安装 Caddy
if ! command -v caddy > /dev/null 2>&1; then
    echo "正在下载 Caddy ($CADDY_ARCH)..."
    curl -s -L "https://caddyserver.com/api/download?os=linux&arch=$CADDY_ARCH" -o /usr/local/bin/caddy
    chmod +x /usr/local/bin/caddy
else
    echo "Caddy 已安装。"
fi

# 7. 安装 Rclone
if ! command -v rclone > /dev/null 2>&1; then
    echo "正在安装 Rclone..."
    curl https://rclone.org/install.sh | bash
else
    echo "Rclone 已安装。"
fi

# 8. 安装 qBittorrent-nox (固定版本 5.1.3.10)
QBT_VERSION="5.1.3.10"
if ! command -v qbittorrent-nox > /dev/null 2>&1; then
    echo "正在下载 qBittorrent-Enhanced-Edition ($QBT_VERSION)..."
    mkdir -p /tmp/qbittorrent
    curl -L "https://github.com/c0re100/qBittorrent-Enhanced-Edition/releases/download/release-${QBT_VERSION}/qbittorrent-enhanced-nox_${QBT_ARCH}.zip" -o /tmp/qbittorrent/qb.zip
    unzip -o /tmp/qbittorrent/qb.zip -d /tmp/qbittorrent
    mv /tmp/qbittorrent/qbittorrent-nox /usr/local/bin/qbittorrent-nox
    chmod +x /usr/local/bin/qbittorrent-nox
    rm -rf /tmp/qbittorrent
else
    echo "qbittorrent-nox 已安装。"
fi

# 9. 部署文件
echo "正在创建部署目录结构: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$INSTALL_DIR/defaults"

echo "正在从 GitHub 获取项目文件..."
mkdir -p /tmp/qbrclone_src
curl -sL "https://github.com/workerspages/qBittorrent-Rclone/archive/refs/heads/v5.1.3.10.tar.gz" | tar -xz -C /tmp/qbrclone_src --strip-components=1

CURRENT_DIR="/tmp/qbrclone_src"
cp "$CURRENT_DIR/qBittorrent.conf" "$INSTALL_DIR/defaults/"
cp "$CURRENT_DIR/categories.json" "$INSTALL_DIR/defaults/"
cp "$CURRENT_DIR/monitor.py" "$INSTALL_DIR/defaults/"
cp -r "$CURRENT_DIR/engines" "$INSTALL_DIR/defaults/" 2>/dev/null || true

cp "$CURRENT_DIR/entrypoint.sh" "$INSTALL_DIR/run.sh"
sed -i "s|/data|$INSTALL_DIR/data|g" "$INSTALL_DIR/run.sh"
sed -i "s|/defaults|$INSTALL_DIR/defaults|g" "$INSTALL_DIR/run.sh"
sed -i "s|/root/\.config/rclone|$INSTALL_DIR/data/rclone|g" "$INSTALL_DIR/run.sh"
chmod +x "$INSTALL_DIR/run.sh"

# 清理临时文件
rm -rf /tmp/qbrclone_src

cat <<EOF > "$INSTALL_DIR/.env"
QBT_USER=$QBT_USER
QBT_PASS=$QBT_PASS
PORT=$PORT
WEBDAV_USER=$WEBDAV_USER
WEBDAV_PASS=$WEBDAV_PASS
TZ=Asia/Shanghai
MAX_CONCURRENT_FILES=3
MIN_FREE_SPACE_GB=10
RESOURCE_MONITOR_ENABLED=true
MAX_CPU_PERCENT=95.0
MAX_MEM_PERCENT=95.0
EOF

# 10. 注册 Systemd 服务
SERVICE_FILE="/etc/systemd/system/qbittorrent-rclone.service"
echo "正在注册 systemd 服务..."
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=qBittorrent-Rclone Daemon
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=$INSTALL_DIR/run.sh
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable qbittorrent-rclone.service
systemctl restart qbittorrent-rclone.service || echo "警告: 服务启动失败，请检查日志 (journalctl -u qbittorrent-rclone)。"

echo "================================================="
echo " 安装成功！"
echo " WebUI 和 WebDAV 已经通过端口 $PORT 暴露。"
echo " WebUI 初始用户名: $QBT_USER"
echo " WebUI 初始密码: $QBT_PASS"
echo ""
echo " WebDAV 初始用户名: $WEBDAV_USER"
echo " WebDAV 初始密码: $WEBDAV_PASS"
echo ""
echo " 日志查看命令: journalctl -u qbittorrent-rclone -f"
echo " 管理服务命令: systemctl [start|stop|restart] qbittorrent-rclone"
echo "================================================="
