#!/bin/sh
# Smart Network Shutdown Monitor - Linux Installer
# Usage: curl -sSL https://raw.githubusercontent.com/UnbalancedCat/smart-shutdown/main/install.sh | sudo sh

set -e

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "[FAIL] 此安装脚本必须以 root 权限运行。请使用 sudo 执行。"
    exit 1
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l)  ARCH="armv7" ;;
    *)       echo "[FAIL] 不支持的架构: $ARCH"; exit 1 ;;
esac

FILE_NAME="smart-shutdown_linux_${ARCH}"
DOWNLOAD_URL="https://github.com/UnbalancedCat/smart-shutdown/releases/latest/download/$FILE_NAME"
TARGET_PATH="/usr/local/bin/smart-shutdown"

echo "正在下载最新版本: $FILE_NAME ..."
curl -sSL "$DOWNLOAD_URL" -o "$TARGET_PATH"
chmod +x "$TARGET_PATH"

echo "正在执行安装与服务注册..."
smart-shutdown install

echo "正在启动后台服务..."
smart-shutdown start

echo "安装完成。此后可直接使用 smart-shutdown 命令。"
