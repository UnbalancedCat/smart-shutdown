#!/bin/bash

#
# 智能网络监控脚本 - Ubuntu版本
# 
# 功能描述：
# 该脚本会定期测试与指定目标IP的网络连通性。
# 如果在设定的"监控窗口"时间内连接持续失败，脚本将启动一个可取消的关机倒计时。
# 如果在倒计时期间网络恢复，关机将被中止。
# 所有操作都会被记录在日志文件中。
#
# 使用方法：
# sudo ./smart_shutdown.sh
#
# 要求：需要root权限来执行关机命令
#

# ==================== 配置参数 ====================

# 监控的目标IP地址
TARGET_IP="192.168.3.15"

# 正常监控时的ping间隔（秒）
NORMAL_PING_INTERVAL=15

# 监控窗口时长（秒） - 在此期间持续失败则触发关机
MONITOR_WINDOW_SECONDS=180

# 关机倒计时时长（秒）
SHUTDOWN_COUNTDOWN=60

# 关机倒计时阶段的ping间隔（秒）
COUNTDOWN_PING_INTERVAL=3

# ping超时时间（秒）
PING_TIMEOUT=3

# 日志配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIRECTORY="$SCRIPT_DIR/logs"
MAX_LOG_DAYS=30

# 配置文件路径
CONFIG_FILE="$SCRIPT_DIR/config.json"

# ==================== 函数定义 ====================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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
    echo "$log_entry" >> "$log_file"
    
    # 根据日志级别在控制台输出不同颜色的信息
    case "$level" in
        "SUCCESS")
            echo -e "${GREEN}$log_entry${NC}"
            ;;
        "FAIL")
            echo -e "${RED}$log_entry${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}$log_entry${NC}"
            ;;
        "CRITICAL")
            echo -e "${PURPLE}$log_entry${NC}"
            ;;
        "INFO")
            echo -e "$log_entry"
            ;;
        *)
            echo -e "$log_entry"
            ;;
    esac
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
        # 创建默认配置文件
        create_default_config
    fi
}

# 创建默认配置文件
create_default_config() {
    cat > "$CONFIG_FILE" << EOF
{
    "TargetIP": "$TARGET_IP",
    "MonitorWindowSeconds": $MONITOR_WINDOW_SECONDS,
    "ShutdownCountdown": $SHUTDOWN_COUNTDOWN,
    "NormalPingInterval": $NORMAL_PING_INTERVAL
}
EOF
    write_log "INFO" "创建默认配置文件: $CONFIG_FILE"
}

# 获取本机IP地址
get_local_ip() {
    local local_ip
    # 尝试获取默认路由接口的IP地址
    local_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
    
    if [[ -z "$local_ip" ]]; then
        # 备用方法：获取第一个非环回接口的IP
        local_ip=$(ip addr show | grep -E 'inet [0-9]' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d'/' -f1)
    fi
    
    [[ -n "$local_ip" ]] && echo "$local_ip" || echo "未知"
}

# 测试网络连接
test_network_connection() {
    local target_ip="$1"
    # 使用ping命令测试连接，发送1个包，超时时间为PING_TIMEOUT秒
    ping -c 1 -W "$PING_TIMEOUT" "$target_ip" >/dev/null 2>&1
    return $?
}

# 清理旧日志文件
cleanup_old_logs() {
    if [[ -d "$LOG_DIRECTORY" ]]; then
        # 删除超过MAX_LOG_DAYS天的日志文件
        find "$LOG_DIRECTORY" -name "network_monitor_*.log" -type f -mtime +$MAX_LOG_DAYS -exec rm -f {} \; 2>/dev/null
    fi
}

# 信号处理函数
cleanup_and_exit() {
    write_log "INFO" "接收到退出信号，正在清理..."
    write_log "INFO" "========== 脚本退出 =========="
    exit 0
}

# 检查root权限
check_root_permission() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误：此脚本需要root权限才能执行关机操作${NC}"
        echo -e "${YELLOW}请使用以下命令运行：${NC}"
        echo -e "${CYAN}sudo $0${NC}"
        exit 1
    fi
}

# ==================== 主程序开始 ====================

# 设置信号处理
trap cleanup_and_exit SIGINT SIGTERM

# 检查权限
check_root_permission

# 清理旧日志
cleanup_old_logs

# 加载配置
load_configuration

# 初始化
clear
local_ip=$(get_local_ip)
write_log "INFO" "========== 脚本启动 =========="
write_log "INFO" "运行用户: $(whoami)"
write_log "INFO" "本机IP: $local_ip"
write_log "INFO" "监控目标: $TARGET_IP"
write_log "INFO" "监控窗口: ${MONITOR_WINDOW_SECONDS}秒"
write_log "INFO" "关机倒计时: ${SHUTDOWN_COUNTDOWN}秒"
write_log "INFO" "日志目录: $LOG_DIRECTORY"
write_log "INFO" "配置文件: $CONFIG_FILE"
write_log "INFO" "脚本已启动，按 Ctrl+C 退出..."

echo "========================================"

# 主循环变量
failure_start_time=""
normal_status_counter=0
normal_status_log_interval=24  # 每24次正常检测记录一次日志（约6分钟）

# 主循环
while true; do
    # 测试网络连接
    if test_network_connection "$TARGET_IP"; then
        # 网络连接正常
        if [[ -n "$failure_start_time" ]]; then
            write_log "SUCCESS" "网络连接已恢复"
            echo -e "${GREEN}[OK] 网络连接已恢复，重置监控窗口${NC}"
            failure_start_time=""  # 重置失败计时器
            normal_status_counter=0  # 重置正常状态计数器
        else
            echo -e "${GREEN}[OK] 网络连接正常${NC}"
            # 正常连接时减少日志频率，只定期记录
            ((normal_status_counter++))
            if [[ $normal_status_counter -ge $normal_status_log_interval ]]; then
                write_log "INFO" "网络连接持续正常（已检测 $normal_status_counter 次）"
                normal_status_counter=0  # 重置计数器
            fi
        fi
        
        # 只在控制台显示等待信息，不写入日志文件
        echo -e "${CYAN}等待 ${NORMAL_PING_INTERVAL}秒后继续监控...${NC}"
        sleep "$NORMAL_PING_INTERVAL"
        
    else
        # 网络连接失败
        write_log "FAIL" "Ping失败 - 目标: $TARGET_IP"
        
        if [[ -z "$failure_start_time" ]]; then
            # 记录首次失败的时间
            failure_start_time=$(date +%s)
            write_log "WARN" "网络首次中断，开始进入监控窗口计时"
        fi
        
        # 计算网络已中断的时间
        current_time=$(date +%s)
        failure_duration=$((current_time - failure_start_time))
        write_log "INFO" "网络已持续中断 $failure_duration / ${MONITOR_WINDOW_SECONDS} 秒"
        
        # 显示详细状态
        remaining_time=$((MONITOR_WINDOW_SECONDS - failure_duration))
        echo -e "${YELLOW}监控状态 - 已中断: ${failure_duration}/${MONITOR_WINDOW_SECONDS}秒，剩余: ${remaining_time}秒${NC}"
        
        if [[ $failure_duration -ge $MONITOR_WINDOW_SECONDS ]]; then
            # 持续失败时间超过监控窗口，开始关机倒计时
            write_log "CRITICAL" "网络持续中断已超过 ${MONITOR_WINDOW_SECONDS} 秒，开始关机流程"
            echo "========================================"
            
            shutdown_cancelled=false
            countdown_end_time=$((current_time + SHUTDOWN_COUNTDOWN))
            
            while [[ $(date +%s) -lt $countdown_end_time && "$shutdown_cancelled" == "false" ]]; do
                current_time=$(date +%s)
                remaining_seconds=$((countdown_end_time - current_time))
                
                if [[ $remaining_seconds -le 0 ]]; then
                    break
                fi
                
                write_log "WARN" "距离关机还有 $remaining_seconds 秒... 正在快速检测网络"
                echo "----------------------------------------"
                echo -e "${YELLOW}距离关机还有 $remaining_seconds 秒...${NC}"
                echo -e "${YELLOW}正在快速检测网络连接... 按 Ctrl+C 可取消关机${NC}"
                
                # 在倒计时中再次检测网络
                if test_network_connection "$TARGET_IP"; then
                    write_log "SUCCESS" "网络在倒计时期间恢复！取消关机"
                    echo "========================================"
                    echo -e "${GREEN}[OK] 网络连接已恢复！取消关机操作${NC}"
                    echo "========================================"
                    failure_start_time=""
                    shutdown_cancelled=true
                    break
                else
                    echo -e "${RED}[X] 网络仍然中断${NC}"
                fi
                
                # 等待下一次检测
                sleep "$COUNTDOWN_PING_INTERVAL"
            done
            
            if [[ "$shutdown_cancelled" == "false" ]]; then
                write_log "CRITICAL" "关机倒计时完成，执行系统关机命令"
                
                # 执行关机命令
                # 注意：为了安全起见，默认注释掉实际的关机命令
                # 如需启用，请取消下面一行的注释
                # shutdown -h now
                
                echo -e "${RED}模拟关机：shutdown -h now （为防止意外，此行已注释）${NC}"
                write_log "CRITICAL" "关机命令已执行（模拟模式）"
                
                # 脚本执行完关机命令后可以退出
                exit 0
            fi
        else
            # 在监控窗口期内，继续等待
            write_log "INFO" "等待 ${NORMAL_PING_INTERVAL}秒后继续..."
            sleep "$NORMAL_PING_INTERVAL"
        fi
    fi
done