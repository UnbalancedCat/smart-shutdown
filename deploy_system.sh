#!/bin/bash

#
# 智能网络监控脚本 - Ubuntu系统级部署脚本
#
# 功能描述：
# 将脚本部署到系统级目录，配置为systemd服务，开机自启动
#
# 部署位置：
# - 程序文件: /opt/smart-network-monitor/
# - 配置文件: /etc/smart-network-monitor/
# - 日志文件: /var/log/smart-network-monitor/
# - 服务文件: /etc/systemd/system/smart-network-monitor.service
#
# 使用方法：
# sudo ./deploy_system.sh
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

# 当前脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}智能网络监控脚本 - Ubuntu系统级部署${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

echo -e "${YELLOW}部署计划:${NC}"
echo -e "- 程序目录: ${PROGRAM_PATH}"
echo -e "- 配置目录: ${CONFIG_PATH}"
echo -e "- 日志目录: ${LOG_PATH}"
echo -e "- 服务文件: ${SERVICE_FILE}"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：此脚本需要root权限执行${NC}"
    echo -e "${YELLOW}请使用: sudo $0${NC}"
    exit 1
fi

# 检查源文件
REQUIRED_FILES=(
    "smart_shutdown.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
        echo -e "${RED}错误：找不到必需文件: $file${NC}"
        exit 1
    fi
done

echo -e "${GREEN}[OK] 源文件检查完成${NC}"

# 停止已存在的服务
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${YELLOW}正在停止现有服务...${NC}"
    systemctl stop "$SERVICE_NAME"
    echo -e "${GREEN}[OK] 服务已停止${NC}"
fi

# 创建目录结构
echo -e "${YELLOW}正在创建目录结构...${NC}"

# 创建程序目录
if [[ ! -d "$PROGRAM_PATH" ]]; then
    mkdir -p "$PROGRAM_PATH"
    echo -e "${GREEN}[OK] 创建程序目录: $PROGRAM_PATH${NC}"
fi

# 创建配置目录
if [[ ! -d "$CONFIG_PATH" ]]; then
    mkdir -p "$CONFIG_PATH"
    echo -e "${GREEN}[OK] 创建配置目录: $CONFIG_PATH${NC}"
fi

# 创建日志目录
if [[ ! -d "$LOG_PATH" ]]; then
    mkdir -p "$LOG_PATH"
    # 设置适当的权限，允许服务用户写入
    chmod 755 "$LOG_PATH"
    echo -e "${GREEN}[OK] 创建日志目录: $LOG_PATH${NC}"
fi

# 创建系统优化版的主脚本
echo -e "${YELLOW}正在创建系统版本的脚本...${NC}"

cat > "$PROGRAM_PATH/smart_shutdown_system.sh" << 'EOF'
#!/bin/bash

#
# 智能网络监控脚本 - 系统服务版本
#
# 功能描述：
# 系统级网络监控脚本，在网络持续中断时自动关机
#
# 特点：
# - 开机自启动，作为systemd服务运行
# - 日志存储在系统日志目录
# - 优化的错误处理和权限管理
#

# ==================== 系统级配置参数 ====================

# 默认配置参数
TARGET_IP="192.168.3.3"
NORMAL_PING_INTERVAL=15
MONITOR_WINDOW_SECONDS=180
SHUTDOWN_COUNTDOWN=60
COUNTDOWN_PING_INTERVAL=3
PING_TIMEOUT=3

# 系统级路径配置
CONFIG_FILE="/etc/smart-network-monitor/config.json"
LOG_DIRECTORY="/var/log/smart-network-monitor"
MAX_LOG_DAYS=30

# 正常连接时的日志记录间隔计数器
NORMAL_LOG_INTERVAL=24  # 每24次循环记录一次状态 (约6分钟)
NORMAL_LOG_COUNTER=0

# ==================== 函数定义 ====================

# 日志写入函数
write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIRECTORY/network_monitor_$(date '+%Y%m%d').log"
    local log_entry="[$timestamp] [$level] $message"
    
    # 确保日志目录存在
    mkdir -p "$LOG_DIRECTORY"
    
    # 写入日志文件
    echo "$log_entry" >> "$log_file" 2>/dev/null
    
    # 同时写入系统日志
    logger -t "smart-network-monitor" "$log_entry"
    
    # 对于关键信息，输出到标准输出（systemd会捕获）
    if [[ "$level" == "CRITICAL" || "$level" == "SUCCESS" || "$level" == "WARN" ]]; then
        echo "$log_entry"
    fi
}

# 加载配置文件
load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        write_log "INFO" "加载配置文件: $CONFIG_FILE"
        
        # 使用jq解析JSON配置文件（如果可用）
        if command -v jq >/dev/null 2>&1; then
            local target_ip=$(jq -r '.TargetIP // empty' "$CONFIG_FILE" 2>/dev/null)
            local monitor_window=$(jq -r '.MonitorWindowSeconds // empty' "$CONFIG_FILE" 2>/dev/null)
            local shutdown_countdown=$(jq -r '.ShutdownCountdown // empty' "$CONFIG_FILE" 2>/dev/null)
            local ping_interval=$(jq -r '.NormalPingInterval // empty' "$CONFIG_FILE" 2>/dev/null)
            
            [[ -n "$target_ip" ]] && TARGET_IP="$target_ip"
            [[ -n "$monitor_window" ]] && MONITOR_WINDOW_SECONDS="$monitor_window"
            [[ -n "$shutdown_countdown" ]] && SHUTDOWN_COUNTDOWN="$shutdown_countdown"
            [[ -n "$ping_interval" ]] && NORMAL_PING_INTERVAL="$ping_interval"
            
            write_log "SUCCESS" "配置文件加载成功"
        else
            write_log "WARN" "jq未安装，无法解析JSON配置文件，使用默认配置"
        fi
    else
        write_log "WARN" "配置文件不存在，使用默认配置"
    fi
}

# 测试网络连接
test_network_connection() {
    local target_ip="$1"
    ping -c 1 -W "$PING_TIMEOUT" "$target_ip" >/dev/null 2>&1
    return $?
}

# 清理旧日志文件
cleanup_old_logs() {
    if [[ -d "$LOG_DIRECTORY" ]]; then
        find "$LOG_DIRECTORY" -name "network_monitor_*.log" -type f -mtime +$MAX_LOG_DAYS -exec rm -f {} \; 2>/dev/null
    fi
}

# 信号处理函数
cleanup_and_exit() {
    write_log "INFO" "接收到退出信号，正在清理..."
    write_log "INFO" "========== 服务退出 =========="
    exit 0
}

# ==================== 主程序开始 ====================

# 设置信号处理
trap cleanup_and_exit SIGINT SIGTERM

# 清理旧日志
cleanup_old_logs

# 加载配置
load_configuration

# 获取系统信息
running_user=$(whoami)
local_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
[[ -z "$local_ip" ]] && local_ip="未知"

write_log "INFO" "========== 系统级网络监控服务启动 =========="
write_log "INFO" "运行用户: $running_user"
write_log "INFO" "本机IP: $local_ip"
write_log "INFO" "监控目标: $TARGET_IP"
write_log "INFO" "监控窗口: ${MONITOR_WINDOW_SECONDS}秒"
write_log "INFO" "关机倒计时: ${SHUTDOWN_COUNTDOWN}秒"
write_log "INFO" "日志目录: $LOG_DIRECTORY"
write_log "INFO" "配置文件: $CONFIG_FILE"

# 主循环
failure_start_time=""

while true; do
    # 测试网络连接
    if test_network_connection "$TARGET_IP"; then
        # 网络连接正常
        if [[ -n "$failure_start_time" ]]; then
            write_log "SUCCESS" "网络连接已恢复"
            failure_start_time=""
            NORMAL_LOG_COUNTER=0
        else
            # 减少正常连接时的日志频率
            ((NORMAL_LOG_COUNTER++))
            if [[ $NORMAL_LOG_COUNTER -ge $NORMAL_LOG_INTERVAL ]]; then
                write_log "INFO" "网络连接正常（定期状态报告）"
                NORMAL_LOG_COUNTER=0
            fi
        fi
        
        sleep "$NORMAL_PING_INTERVAL"
        
    else
        # 网络连接失败
        write_log "FAIL" "Ping失败 - 目标: $TARGET_IP"
        
        if [[ -z "$failure_start_time" ]]; then
            failure_start_time=$(date +%s)
            write_log "WARN" "网络首次中断，开始进入监控窗口计时"
        fi
        
        current_time=$(date +%s)
        failure_duration=$((current_time - failure_start_time))
        write_log "INFO" "网络已持续中断 $failure_duration / ${MONITOR_WINDOW_SECONDS} 秒"
        
        if [[ $failure_duration -ge $MONITOR_WINDOW_SECONDS ]]; then
            write_log "CRITICAL" "网络持续中断已超过 ${MONITOR_WINDOW_SECONDS} 秒，开始关机流程"
            
            shutdown_cancelled=false
            countdown_end_time=$((current_time + SHUTDOWN_COUNTDOWN))
            
            while [[ $(date +%s) -lt $countdown_end_time && "$shutdown_cancelled" == "false" ]]; do
                current_time=$(date +%s)
                remaining_seconds=$((countdown_end_time - current_time))
                
                if [[ $remaining_seconds -le 0 ]]; then
                    break
                fi
                
                write_log "WARN" "距离关机还有 $remaining_seconds 秒... 正在快速检测网络"
                
                # 在倒计时中再次检测网络
                if test_network_connection "$TARGET_IP"; then
                    write_log "SUCCESS" "网络在倒计时期间恢复！取消关机"
                    failure_start_time=""
                    shutdown_cancelled=true
                    break
                fi
                
                sleep "$COUNTDOWN_PING_INTERVAL"
            done
            
            if [[ "$shutdown_cancelled" == "false" ]]; then
                write_log "CRITICAL" "关机倒计时完成，执行系统关机命令"
                
                # 执行实际关机命令
                shutdown -h now
                write_log "CRITICAL" "关机命令已执行"
                
                exit 0
            fi
        else
            sleep "$NORMAL_PING_INTERVAL"
        fi
    fi
done
EOF

# 设置脚本权限
chmod +x "$PROGRAM_PATH/smart_shutdown_system.sh"
echo -e "${GREEN}[OK] 创建系统脚本: $PROGRAM_PATH/smart_shutdown_system.sh${NC}"

# 创建默认配置文件
echo -e "${YELLOW}正在创建配置文件...${NC}"

cat > "$CONFIG_PATH/config.json" << EOF
{
    "TargetIP": "192.168.3.3",
    "MonitorWindowSeconds": 180,
    "ShutdownCountdown": 60,
    "NormalPingInterval": 15
}
EOF

echo -e "${GREEN}[OK] 创建配置文件: $CONFIG_PATH/config.json${NC}"

# 创建systemd服务文件
echo -e "${YELLOW}正在配置systemd服务...${NC}"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Smart Network Monitor Service
Documentation=https://github.com/example/smart-network-monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$PROGRAM_PATH/smart_shutdown_system.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# 安全设置
NoNewPrivileges=false
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$LOG_PATH

# 环境变量
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}[OK] 创建systemd服务文件: $SERVICE_FILE${NC}"

# 重新加载systemd配置
echo -e "${YELLOW}正在重新加载systemd配置...${NC}"
systemctl daemon-reload
echo -e "${GREEN}[OK] systemd配置已重新加载${NC}"

# 启用服务
echo -e "${YELLOW}正在启用服务开机自启动...${NC}"
systemctl enable "$SERVICE_NAME"
echo -e "${GREEN}[OK] 服务已设置为开机自启动${NC}"

# 创建管理脚本
echo -e "${YELLOW}正在创建管理工具...${NC}"

cat > "$PROGRAM_PATH/manage.sh" << 'EOF'
#!/bin/bash

#
# 智能网络监控脚本 - 管理工具
#

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SERVICE_NAME="smart-network-monitor"
CONFIG_FILE="/etc/smart-network-monitor/config.json"
LOG_PATH="/var/log/smart-network-monitor"

echo -e "${CYAN}智能网络监控脚本 - 管理工具${NC}"
echo -e "${CYAN}==============================${NC}"
echo ""

echo -e "${YELLOW}可用操作:${NC}"
echo "1. 查看服务状态"
echo "2. 启动服务"
echo "3. 停止服务"
echo "4. 重启服务"
echo "5. 查看今天的日志"
echo "6. 查看实时日志"
echo "7. 查看配置文件"
echo "8. 编辑配置文件"
echo "9. 查看系统日志"
echo ""

read -p "请选择操作 (1-9): " choice

case "$choice" in
    "1")
        systemctl status "$SERVICE_NAME"
        ;;
    "2")
        sudo systemctl start "$SERVICE_NAME"
        echo -e "${GREEN}服务已启动${NC}"
        ;;
    "3")
        sudo systemctl stop "$SERVICE_NAME"
        echo -e "${GREEN}服务已停止${NC}"
        ;;
    "4")
        sudo systemctl restart "$SERVICE_NAME"
        echo -e "${GREEN}服务已重启${NC}"
        ;;
    "5")
        log_file="$LOG_PATH/network_monitor_$(date '+%Y%m%d').log"
        if [[ -f "$log_file" ]]; then
            cat "$log_file"
        else
            echo -e "${RED}今天的日志文件不存在${NC}"
        fi
        ;;
    "6")
        log_file="$LOG_PATH/network_monitor_$(date '+%Y%m%d').log"
        if [[ -f "$log_file" ]]; then
            tail -f "$log_file"
        else
            echo -e "${RED}今天的日志文件不存在，显示systemd日志：${NC}"
            journalctl -u "$SERVICE_NAME" -f
        fi
        ;;
    "7")
        if [[ -f "$CONFIG_FILE" ]]; then
            cat "$CONFIG_FILE"
        else
            echo -e "${RED}配置文件不存在${NC}"
        fi
        ;;
    "8")
        if [[ -f "$CONFIG_FILE" ]]; then
            sudo nano "$CONFIG_FILE"
            echo -e "${YELLOW}配置已修改，重启服务使配置生效：${NC}"
            echo "sudo systemctl restart $SERVICE_NAME"
        else
            echo -e "${RED}配置文件不存在${NC}"
        fi
        ;;
    "9")
        journalctl -u "$SERVICE_NAME" -n 50
        ;;
    *)
        echo -e "${RED}无效选择${NC}"
        ;;
esac

echo ""
echo -e "${YELLOW}常用命令:${NC}"
echo -e "${BLUE}查看服务状态:${NC} systemctl status $SERVICE_NAME"
echo -e "${BLUE}启动服务:${NC} sudo systemctl start $SERVICE_NAME"
echo -e "${BLUE}停止服务:${NC} sudo systemctl stop $SERVICE_NAME"
echo -e "${BLUE}重启服务:${NC} sudo systemctl restart $SERVICE_NAME"
echo -e "${BLUE}查看今天日志:${NC} cat $LOG_PATH/network_monitor_\$(date '+%Y%m%d').log"
echo -e "${BLUE}实时查看日志:${NC} tail -f $LOG_PATH/network_monitor_\$(date '+%Y%m%d').log"
echo -e "${BLUE}查看系统日志:${NC} journalctl -u $SERVICE_NAME -f"
echo -e "${BLUE}编辑配置:${NC} sudo nano $CONFIG_FILE"
echo ""
EOF

chmod +x "$PROGRAM_PATH/manage.sh"
echo -e "${GREEN}[OK] 创建管理脚本: $PROGRAM_PATH/manage.sh${NC}"

# 创建符号链接到系统PATH
if [[ ! -L "/usr/local/bin/smart-monitor" ]]; then
    ln -s "$PROGRAM_PATH/manage.sh" "/usr/local/bin/smart-monitor"
    echo -e "${GREEN}[OK] 创建管理工具快捷命令: smart-monitor${NC}"
fi

echo ""
echo -e "${GREEN}[INFO] 系统级部署完成！${NC}"
echo ""
echo -e "${CYAN}部署摘要:${NC}"
echo -e "${GREEN}[OK]${NC} 程序文件已部署到: $PROGRAM_PATH"
echo -e "${GREEN}[OK]${NC} 配置目录已创建: $CONFIG_PATH"
echo -e "${GREEN}[OK]${NC} 日志目录已创建: $LOG_PATH"
echo -e "${GREEN}[OK]${NC} systemd服务已配置: $SERVICE_NAME"
echo -e "${GREEN}[OK]${NC} 开机自启动已启用"
echo ""
echo -e "${YELLOW}管理工具:${NC}"
echo -e "- 管理脚本: $PROGRAM_PATH/manage.sh"
echo -e "- 快捷命令: ${CYAN}smart-monitor${NC}"
echo -e "- 配置文件: $CONFIG_PATH/config.json"
echo -e "- 今天日志: $LOG_PATH/network_monitor_$(date '+%Y%m%d').log"
echo ""
echo -e "${GREEN}下次重启后，服务将自动运行！${NC}"
echo ""

# 询问是否立即启动
read -p "是否立即启动监控服务？(Y/n): " response
if [[ "$response" == "Y" || "$response" == "y" || "$response" == "" ]]; then
    if systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}[OK] 监控服务已启动${NC}"
        echo -e "${CYAN}使用以下命令查看服务状态:${NC}"
        echo -e "${BLUE}systemctl status $SERVICE_NAME${NC}"
        echo -e "${BLUE}journalctl -u $SERVICE_NAME -f${NC}"
    else
        echo -e "${RED}[X] 启动服务失败${NC}"
    fi
fi

echo ""
echo -e "${CYAN}使用 'smart-monitor' 命令来管理服务${NC}"