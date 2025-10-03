#!/bin/bash

#
# 智能网络监控脚本 - Ubuntu系统级卸载脚本
#
# 功能描述：
# 完全卸载系统级部署的智能网络监控脚本
# 包括停止服务、删除文件、清理配置等
#
# 使用方法：
# sudo ./uninstall_system.sh
#

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 定义系统级路径
PROGRAM_PATH="/opt/smart-network-monitor"
CONFIG_PATH="/etc/smart-network-monitor"
LOG_PATH="/var/log/smart-network-monitor"
SERVICE_FILE="/etc/systemd/system/smart-network-monitor.service"
SERVICE_NAME="smart-network-monitor"
SYMLINK_PATH="/usr/local/bin/smart-monitor"

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}智能网络监控脚本 - Ubuntu系统级卸载${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：此脚本需要root权限执行${NC}"
    echo -e "${YELLOW}请使用: sudo $0${NC}"
    exit 1
fi

echo -e "${YELLOW}将要删除的组件:${NC}"
echo -e "- 程序目录: ${PROGRAM_PATH}"
echo -e "- 配置目录: ${CONFIG_PATH}"
echo -e "- 日志目录: ${LOG_PATH}"
echo -e "- 服务文件: ${SERVICE_FILE}"
echo -e "- 符号链接: ${SYMLINK_PATH}"
echo ""

# 询问用户确认
read -p "确定要完全卸载智能网络监控脚本吗？这将删除所有相关文件和日志 (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${YELLOW}卸载已取消${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}开始卸载过程...${NC}"

# 停止并禁用服务
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${YELLOW}正在停止服务...${NC}"
    if systemctl stop "$SERVICE_NAME"; then
        echo -e "${GREEN}[OK] 服务已停止${NC}"
    else
        echo -e "${RED}[WARNING] 停止服务失败${NC}"
    fi
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}正在禁用服务自启动...${NC}"
    if systemctl disable "$SERVICE_NAME"; then
        echo -e "${GREEN}[OK] 服务自启动已禁用${NC}"
    else
        echo -e "${RED}[WARNING] 禁用服务自启动失败${NC}"
    fi
fi

# 删除服务文件
if [[ -f "$SERVICE_FILE" ]]; then
    echo -e "${YELLOW}正在删除服务文件...${NC}"
    if rm -f "$SERVICE_FILE"; then
        echo -e "${GREEN}[OK] 服务文件已删除: $SERVICE_FILE${NC}"
    else
        echo -e "${RED}[ERROR] 删除服务文件失败${NC}"
    fi
fi

# 重新加载systemd配置
echo -e "${YELLOW}正在重新加载systemd配置...${NC}"
if systemctl daemon-reload; then
    echo -e "${GREEN}[OK] systemd配置已重新加载${NC}"
else
    echo -e "${RED}[WARNING] 重新加载systemd配置失败${NC}"
fi

# 删除符号链接
if [[ -L "$SYMLINK_PATH" ]]; then
    echo -e "${YELLOW}正在删除符号链接...${NC}"
    if rm -f "$SYMLINK_PATH"; then
        echo -e "${GREEN}[OK] 符号链接已删除: $SYMLINK_PATH${NC}"
    else
        echo -e "${RED}[ERROR] 删除符号链接失败${NC}"
    fi
fi

# 删除程序目录
if [[ -d "$PROGRAM_PATH" ]]; then
    echo -e "${YELLOW}正在删除程序目录...${NC}"
    if rm -rf "$PROGRAM_PATH"; then
        echo -e "${GREEN}[OK] 程序目录已删除: $PROGRAM_PATH${NC}"
    else
        echo -e "${RED}[ERROR] 删除程序目录失败${NC}"
    fi
fi

# 询问是否删除配置文件
echo ""
read -p "是否删除配置文件？这将删除您的自定义配置 (y/N): " delete_config

if [[ "$delete_config" == "y" || "$delete_config" == "Y" ]]; then
    if [[ -d "$CONFIG_PATH" ]]; then
        echo -e "${YELLOW}正在删除配置目录...${NC}"
        if rm -rf "$CONFIG_PATH"; then
            echo -e "${GREEN}[OK] 配置目录已删除: $CONFIG_PATH${NC}"
        else
            echo -e "${RED}[ERROR] 删除配置目录失败${NC}"
        fi
    fi
else
    echo -e "${BLUE}[INFO] 保留配置文件: $CONFIG_PATH${NC}"
fi

# 询问是否删除日志文件
echo ""
read -p "是否删除日志文件？这将删除所有监控历史记录 (y/N): " delete_logs

if [[ "$delete_logs" == "y" || "$delete_logs" == "Y" ]]; then
    if [[ -d "$LOG_PATH" ]]; then
        echo -e "${YELLOW}正在删除日志目录...${NC}"
        if rm -rf "$LOG_PATH"; then
            echo -e "${GREEN}[OK] 日志目录已删除: $LOG_PATH${NC}"
        else
            echo -e "${RED}[ERROR] 删除日志目录失败${NC}"
        fi
    fi
else
    echo -e "${BLUE}[INFO] 保留日志文件: $LOG_PATH${NC}"
fi

# 清理系统日志中的相关条目（可选）
echo ""
read -p "是否清理系统日志中的相关条目？(y/N): " clean_syslogs

if [[ "$clean_syslogs" == "y" || "$clean_syslogs" == "Y" ]]; then
    echo -e "${YELLOW}正在清理系统日志...${NC}"
    if command -v journalctl >/dev/null 2>&1; then
        # 注意：journalctl --vacuum-time 需要适当的权限
        journalctl --vacuum-time=1d 2>/dev/null || echo -e "${YELLOW}[WARNING] 清理系统日志需要额外权限${NC}"
        echo -e "${GREEN}[OK] 系统日志清理完成${NC}"
    else
        echo -e "${YELLOW}[WARNING] journalctl命令不可用${NC}"
    fi
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}卸载完成！${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""

# 显示卸载摘要
echo -e "${CYAN}卸载摘要:${NC}"
echo -e "${GREEN}[OK]${NC} 服务已停止并禁用"
echo -e "${GREEN}[OK]${NC} 服务文件已删除"
echo -e "${GREEN}[OK]${NC} 程序文件已删除"
echo -e "${GREEN}[OK]${NC} 符号链接已删除"

if [[ "$delete_config" == "y" || "$delete_config" == "Y" ]]; then
    echo -e "${GREEN}[OK]${NC} 配置文件已删除"
else
    echo -e "${BLUE}[INFO]${NC} 配置文件已保留"
fi

if [[ "$delete_logs" == "y" || "$delete_logs" == "Y" ]]; then
    echo -e "${GREEN}[OK]${NC} 日志文件已删除"
else
    echo -e "${BLUE}[INFO]${NC} 日志文件已保留"
fi

echo ""

# 检查是否有残留文件
echo -e "${YELLOW}检查残留文件...${NC}"
remaining_files=()

[[ -f "$SERVICE_FILE" ]] && remaining_files+=("$SERVICE_FILE")
[[ -d "$PROGRAM_PATH" ]] && remaining_files+=("$PROGRAM_PATH")
[[ -L "$SYMLINK_PATH" ]] && remaining_files+=("$SYMLINK_PATH")

if [[ ${#remaining_files[@]} -eq 0 ]]; then
    echo -e "${GREEN}[OK] 没有发现残留文件${NC}"
else
    echo -e "${YELLOW}[WARNING] 发现以下残留文件:${NC}"
    for file in "${remaining_files[@]}"; do
        echo -e "${RED}  - $file${NC}"
    done
    echo -e "${YELLOW}您可能需要手动删除这些文件${NC}"
fi

echo ""
echo -e "${CYAN}智能网络监控脚本已完全卸载！${NC}"

# 如果保留了配置或日志文件，提供再次卸载的说明
if [[ "$delete_config" != "y" && "$delete_config" != "Y" ]] || [[ "$delete_logs" != "y" && "$delete_logs" != "Y" ]]; then
    echo ""
    echo -e "${BLUE}如果您之后想删除保留的文件，可以手动删除：${NC}"
    [[ "$delete_config" != "y" && "$delete_config" != "Y" ]] && echo -e "${BLUE}  配置文件: sudo rm -rf $CONFIG_PATH${NC}"
    [[ "$delete_logs" != "y" && "$delete_logs" != "Y" ]] && echo -e "${BLUE}  日志文件: sudo rm -rf $LOG_PATH${NC}"
fi

echo ""