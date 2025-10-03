#!/bin/bash

#
# 智能网络监控脚本 - 管理工具
#
# 功能描述：
# 提供智能网络监控脚本的管理界面
# 包括服务控制、日志查看、配置管理等功能
#
# 使用方法：
# ./manage.sh
# 或者（如果已安装到系统）：smart-monitor
#

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 系统路径配置
SERVICE_NAME="smart-network-monitor"
SYSTEM_CONFIG_FILE="/etc/smart-network-monitor/config.json"
SYSTEM_LOG_PATH="/var/log/smart-network-monitor"
LOCAL_CONFIG_FILE="./config.json"
LOCAL_LOG_PATH="./logs"

# 检测是否为系统级安装
if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
    CONFIG_FILE="$SYSTEM_CONFIG_FILE"
    LOG_PATH="$SYSTEM_LOG_PATH"
    IS_SYSTEM_INSTALL=true
else
    CONFIG_FILE="$LOCAL_CONFIG_FILE"
    LOG_PATH="$LOCAL_LOG_PATH"
    IS_SYSTEM_INSTALL=false
fi

# 显示标题
show_header() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}智能网络监控脚本 - 管理工具${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    
    if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
        echo -e "${GREEN}检测到系统级安装${NC}"
        echo -e "服务名称: ${BLUE}$SERVICE_NAME${NC}"
    else
        echo -e "${YELLOW}使用本地模式${NC}"
        echo -e "配置文件: ${BLUE}$CONFIG_FILE${NC}"
    fi
    echo -e "日志路径: ${BLUE}$LOG_PATH${NC}"
    echo ""
}

# 显示菜单
show_menu() {
    echo -e "${YELLOW}可用操作:${NC}"
    
    if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
        echo "1. 查看服务状态"
        echo "2. 启动服务"
        echo "3. 停止服务"
        echo "4. 重启服务"
        echo "5. 启用开机自启动"
        echo "6. 禁用开机自启动"
        echo "7. 查看今天的日志"
        echo "8. 查看实时日志"
        echo "9. 查看系统日志"
        echo "10. 查看配置文件"
        echo "11. 编辑配置文件"
        echo "12. 测试网络连接"
        echo "13. 显示服务信息"
        echo "0. 退出"
    else
        echo "1. 查看配置文件"
        echo "2. 编辑配置文件"
        echo "3. 查看今天的日志"
        echo "4. 查看实时日志"
        echo "5. 测试网络连接"
        echo "6. 启动本地脚本（前台运行）"
        echo "7. 清理旧日志"
        echo "0. 退出"
    fi
    echo ""
}

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ 服务正在运行${NC}"
        return 0
    else
        echo -e "${RED}✗ 服务未运行${NC}"
        return 1
    fi
}

# 显示服务状态
show_service_status() {
    echo -e "${CYAN}=== 服务状态 ===${NC}"
    systemctl status "$SERVICE_NAME" --no-pager -l
    echo ""
    
    echo -e "${CYAN}=== 服务是否启用 ===${NC}"
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}✓ 开机自启动已启用${NC}"
    else
        echo -e "${YELLOW}✗ 开机自启动未启用${NC}"
    fi
    echo ""
}

# 启动服务
start_service() {
    echo -e "${YELLOW}正在启动服务...${NC}"
    if sudo systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}[OK] 服务已启动${NC}"
    else
        echo -e "${RED}[ERROR] 启动服务失败${NC}"
    fi
}

# 停止服务
stop_service() {
    echo -e "${YELLOW}正在停止服务...${NC}"
    if sudo systemctl stop "$SERVICE_NAME"; then
        echo -e "${GREEN}[OK] 服务已停止${NC}"
    else
        echo -e "${RED}[ERROR] 停止服务失败${NC}"
    fi
}

# 重启服务
restart_service() {
    echo -e "${YELLOW}正在重启服务...${NC}"
    if sudo systemctl restart "$SERVICE_NAME"; then
        echo -e "${GREEN}[OK] 服务已重启${NC}"
    else
        echo -e "${RED}[ERROR] 重启服务失败${NC}"
    fi
}

# 启用开机自启动
enable_service() {
    echo -e "${YELLOW}正在启用开机自启动...${NC}"
    if sudo systemctl enable "$SERVICE_NAME"; then
        echo -e "${GREEN}[OK] 开机自启动已启用${NC}"
    else
        echo -e "${RED}[ERROR] 启用开机自启动失败${NC}"
    fi
}

# 禁用开机自启动
disable_service() {
    echo -e "${YELLOW}正在禁用开机自启动...${NC}"
    if sudo systemctl disable "$SERVICE_NAME"; then
        echo -e "${GREEN}[OK] 开机自启动已禁用${NC}"
    else
        echo -e "${RED}[ERROR] 禁用开机自启动失败${NC}"
    fi
}

# 查看今天的日志
show_today_log() {
    local log_file="$LOG_PATH/network_monitor_$(date '+%Y%m%d').log"
    
    echo -e "${CYAN}=== 今天的日志 ($log_file) ===${NC}"
    if [[ -f "$log_file" ]]; then
        echo -e "${BLUE}文件大小: $(du -h "$log_file" | cut -f1)${NC}"
        echo -e "${BLUE}最后修改: $(stat -c %y "$log_file")${NC}"
        echo ""
        echo -e "${YELLOW}最近20行:${NC}"
        tail -n 20 "$log_file"
        echo ""
        echo -e "${CYAN}按任意键查看所有内容，或按 Ctrl+C 返回菜单${NC}"
        read -n 1 -s
        less "$log_file"
    else
        echo -e "${RED}今天的日志文件不存在${NC}"
        echo -e "${BLUE}日志文件路径: $log_file${NC}"
    fi
}

# 查看实时日志
show_live_log() {
    local log_file="$LOG_PATH/network_monitor_$(date '+%Y%m%d').log"
    
    echo -e "${CYAN}=== 实时日志监控 ===${NC}"
    echo -e "${YELLOW}按 Ctrl+C 退出实时监控${NC}"
    echo ""
    
    if [[ -f "$log_file" ]]; then
        tail -f "$log_file"
    else
        echo -e "${RED}今天的日志文件不存在，监控系统日志...${NC}"
        if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
            journalctl -u "$SERVICE_NAME" -f
        else
            echo -e "${RED}无可用日志${NC}"
        fi
    fi
}

# 查看系统日志
show_system_log() {
    echo -e "${CYAN}=== 系统日志 ===${NC}"
    echo -e "${YELLOW}最近100条系统日志:${NC}"
    journalctl -u "$SERVICE_NAME" -n 100 --no-pager
    echo ""
    echo -e "${CYAN}按任意键查看实时系统日志，或按 Ctrl+C 返回菜单${NC}"
    read -n 1 -s
    journalctl -u "$SERVICE_NAME" -f
}

# 查看配置文件
show_config() {
    echo -e "${CYAN}=== 配置文件 ($CONFIG_FILE) ===${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${BLUE}文件路径: $CONFIG_FILE${NC}"
        echo -e "${BLUE}最后修改: $(stat -c %y "$CONFIG_FILE")${NC}"
        echo ""
        echo -e "${YELLOW}当前配置:${NC}"
        cat "$CONFIG_FILE"
        echo ""
        
        # 如果有jq，则格式化显示
        if command -v jq >/dev/null 2>&1; then
            echo -e "${YELLOW}格式化显示:${NC}"
            jq . "$CONFIG_FILE" 2>/dev/null || echo -e "${RED}JSON格式错误${NC}"
        fi
    else
        echo -e "${RED}配置文件不存在: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}是否创建默认配置文件？ (y/N): ${NC}"
        read -n 1 response
        echo ""
        
        if [[ "$response" == "y" || "$response" == "Y" ]]; then
            create_default_config
        fi
    fi
}

# 创建默认配置文件
create_default_config() {
    local config_dir=$(dirname "$CONFIG_FILE")
    
    # 确保配置目录存在
    if [[ ! -d "$config_dir" ]]; then
        if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
            sudo mkdir -p "$config_dir"
        else
            mkdir -p "$config_dir"
        fi
    fi
    
    local default_config='{
    "TargetIP": "192.168.3.3",
    "MonitorWindowSeconds": 180,
    "ShutdownCountdown": 60,
    "NormalPingInterval": 15
}'
    
    if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
        echo "$default_config" | sudo tee "$CONFIG_FILE" > /dev/null
    else
        echo "$default_config" > "$CONFIG_FILE"
    fi
    
    echo -e "${GREEN}[OK] 默认配置文件已创建: $CONFIG_FILE${NC}"
}

# 编辑配置文件
edit_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}配置文件不存在，是否创建默认配置？ (y/N): ${NC}"
        read -n 1 response
        echo ""
        
        if [[ "$response" == "y" || "$response" == "Y" ]]; then
            create_default_config
        else
            return
        fi
    fi
    
    echo -e "${CYAN}=== 编辑配置文件 ===${NC}"
    echo -e "${YELLOW}使用编辑器编辑配置文件...${NC}"
    
    # 选择编辑器
    local editor=""
    if command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    else
        echo -e "${RED}未找到可用的编辑器${NC}"
        return
    fi
    
    echo -e "${BLUE}使用编辑器: $editor${NC}"
    echo -e "${YELLOW}编辑完成后，如果是系统安装，需要重启服务使配置生效${NC}"
    echo ""
    
    if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
        sudo "$editor" "$CONFIG_FILE"
        echo ""
        echo -e "${YELLOW}配置已修改，是否重启服务使配置生效？ (y/N): ${NC}"
        read -n 1 response
        echo ""
        
        if [[ "$response" == "y" || "$response" == "Y" ]]; then
            restart_service
        fi
    else
        "$editor" "$CONFIG_FILE"
    fi
}

# 测试网络连接
test_network() {
    local target_ip="192.168.3.3"
    
    # 尝试从配置文件读取目标IP
    if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
        local config_ip=$(jq -r '.TargetIP // empty' "$CONFIG_FILE" 2>/dev/null)
        [[ -n "$config_ip" ]] && target_ip="$config_ip"
    fi
    
    echo -e "${CYAN}=== 网络连接测试 ===${NC}"
    echo -e "${BLUE}目标IP: $target_ip${NC}"
    echo ""
    
    echo -e "${YELLOW}正在测试网络连接...${NC}"
    
    for i in {1..5}; do
        echo -n "测试 $i/5: "
        if ping -c 1 -W 3 "$target_ip" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ 连接成功${NC}"
        else
            echo -e "${RED}✗ 连接失败${NC}"
        fi
        [[ $i -lt 5 ]] && sleep 1
    done
    
    echo ""
    echo -e "${CYAN}详细ping测试:${NC}"
    ping -c 4 "$target_ip"
}

# 启动本地脚本
start_local_script() {
    local script_path="./smart_shutdown.sh"
    
    echo -e "${CYAN}=== 启动本地脚本 ===${NC}"
    
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}本地脚本不存在: $script_path${NC}"
        return
    fi
    
    if [[ ! -x "$script_path" ]]; then
        echo -e "${YELLOW}脚本没有执行权限，正在添加...${NC}"
        chmod +x "$script_path"
    fi
    
    echo -e "${YELLOW}即将启动本地脚本（前台运行）${NC}"
    echo -e "${YELLOW}按 Ctrl+C 可以停止脚本${NC}"
    echo -e "${BLUE}3秒后开始...${NC}"
    
    for i in {3..1}; do
        echo -n "$i "
        sleep 1
    done
    echo ""
    echo ""
    
    sudo "$script_path"
}

# 清理旧日志
cleanup_old_logs() {
    echo -e "${CYAN}=== 清理旧日志 ===${NC}"
    
    if [[ ! -d "$LOG_PATH" ]]; then
        echo -e "${RED}日志目录不存在: $LOG_PATH${NC}"
        return
    fi
    
    echo -e "${BLUE}日志目录: $LOG_PATH${NC}"
    echo -e "${YELLOW}查找30天前的日志文件...${NC}"
    
    local old_logs=$(find "$LOG_PATH" -name "network_monitor_*.log" -type f -mtime +30 2>/dev/null)
    
    if [[ -z "$old_logs" ]]; then
        echo -e "${GREEN}没有找到需要清理的旧日志文件${NC}"
        return
    fi
    
    echo -e "${YELLOW}找到以下旧日志文件:${NC}"
    echo "$old_logs"
    echo ""
    
    echo -e "${YELLOW}确定要删除这些文件吗？ (y/N): ${NC}"
    read -n 1 response
    echo ""
    
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        echo "$old_logs" | xargs rm -f
        echo -e "${GREEN}[OK] 旧日志文件已清理${NC}"
    else
        echo -e "${YELLOW}清理已取消${NC}"
    fi
}

# 显示服务信息
show_service_info() {
    echo -e "${CYAN}=== 服务详细信息 ===${NC}"
    
    echo -e "${YELLOW}基本信息:${NC}"
    echo -e "服务名称: ${BLUE}$SERVICE_NAME${NC}"
    echo -e "配置文件: ${BLUE}$CONFIG_FILE${NC}"
    echo -e "日志目录: ${BLUE}$LOG_PATH${NC}"
    echo ""
    
    echo -e "${YELLOW}服务状态:${NC}"
    systemctl show "$SERVICE_NAME" --no-pager
    echo ""
    
    echo -e "${YELLOW}最近的服务日志:${NC}"
    journalctl -u "$SERVICE_NAME" -n 10 --no-pager
}

# 等待用户按键
wait_for_key() {
    echo ""
    echo -e "${CYAN}按任意键继续...${NC}"
    read -n 1 -s
}

# 主程序
main() {
    while true; do
        show_header
        show_menu
        
        read -p "请选择操作: " choice
        echo ""
        
        case "$choice" in
            "1")
                if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
                    show_service_status
                else
                    show_config
                fi
                wait_for_key
                ;;
            "2")
                if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
                    start_service
                else
                    edit_config
                fi
                wait_for_key
                ;;
            "3")
                if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
                    stop_service
                else
                    show_today_log
                fi
                wait_for_key
                ;;
            "4")
                if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
                    restart_service
                else
                    show_live_log
                fi
                ;;
            "5")
                if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
                    enable_service
                else
                    test_network
                fi
                wait_for_key
                ;;
            "6")
                if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
                    disable_service
                else
                    start_local_script
                fi
                wait_for_key
                ;;
            "7")
                if [[ "$IS_SYSTEM_INSTALL" == "true" ]]; then
                    show_today_log
                else
                    cleanup_old_logs
                fi
                ;;
            "8")
                [[ "$IS_SYSTEM_INSTALL" == "true" ]] && show_live_log
                ;;
            "9")
                [[ "$IS_SYSTEM_INSTALL" == "true" ]] && show_system_log
                ;;
            "10")
                [[ "$IS_SYSTEM_INSTALL" == "true" ]] && show_config
                wait_for_key
                ;;
            "11")
                [[ "$IS_SYSTEM_INSTALL" == "true" ]] && edit_config
                wait_for_key
                ;;
            "12")
                [[ "$IS_SYSTEM_INSTALL" == "true" ]] && test_network
                wait_for_key
                ;;
            "13")
                [[ "$IS_SYSTEM_INSTALL" == "true" ]] && show_service_info
                wait_for_key
                ;;
            "0")
                echo -e "${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                wait_for_key
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    # 检查必要命令
    for cmd in ping systemctl journalctl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}缺少必要的命令:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "${RED}  - $dep${NC}"
        done
        echo -e "${YELLOW}请安装缺少的软件包${NC}"
        exit 1
    fi
    
    # 检查可选命令
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}建议安装 jq 以获得更好的JSON配置文件支持${NC}"
        echo -e "${BLUE}安装命令: sudo apt-get install jq${NC}"
        echo ""
    fi
}

# 启动主程序
check_dependencies
main