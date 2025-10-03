# 智能网络监控脚本 - Ubuntu版本

## 📁 项目结构

```
smart-shutdown/
├── smart_shutdown.sh           # 主监控脚本（用户模式）
├── deploy_system.sh            # 系统级部署脚本
├── uninstall_system.sh         # 系统级卸载脚本
├── manage.sh                   # 管理工具脚本
├── README.md                   # 本文件
└── logs/                       # 本地运行时的日志目录
    └── network_monitor_YYYYMMDD.log
```

## 🚀 快速开始

### 系统级部署（推荐）

```bash
# 1. 克隆或下载项目到本地
cd /path/to/smart-shutdown/

# 2. 以root权限运行部署脚本
sudo ./deploy_system.sh
```

**部署效果：**
- 程序文件：`/opt/smart-network-monitor/`
- 配置文件：`/etc/smart-network-monitor/config.json`
- 日志文件：`/var/log/smart-network-monitor/`
- systemd服务：`smart-network-monitor.service`
- 开机自启动，无需用户登录

### 用户级运行

```bash
# 以root权限直接运行（需要用户登录）
sudo ./smart_shutdown.sh
```

## 🎯 系统部署后的文件位置

### 程序文件位置
```
/opt/smart-network-monitor/
├── smart_shutdown_system.sh    # 系统优化版监控脚本
└── manage.sh                   # 管理工具脚本
```

### 配置文件位置
```
/etc/smart-network-monitor/
└── config.json                 # 配置文件
```

### 日志文件位置
```
/var/log/smart-network-monitor/
└── network_monitor_YYYYMMDD.log # 日志文件
```

## 🔧 管理命令

### 使用管理工具（推荐）
```bash
# 使用快捷命令（系统安装后可用）
smart-monitor

# 或者直接运行管理脚本
sudo /opt/smart-network-monitor/manage.sh
```

### 直接使用systemctl命令

#### 查看服务状态
```bash
systemctl status smart-network-monitor
```

#### 启动/停止/重启服务
```bash
sudo systemctl start smart-network-monitor
sudo systemctl stop smart-network-monitor
sudo systemctl restart smart-network-monitor
```

#### 启用/禁用开机自启动
```bash
sudo systemctl enable smart-network-monitor
sudo systemctl disable smart-network-monitor
```

### 查看日志

#### 查看今天的应用日志
```bash
cat /var/log/smart-network-monitor/network_monitor_$(date '+%Y%m%d').log
```

#### 实时监控应用日志
```bash
tail -f /var/log/smart-network-monitor/network_monitor_$(date '+%Y%m%d').log
```

#### 查看系统日志
```bash
# 查看最近的系统日志
journalctl -u smart-network-monitor -n 50

# 实时监控系统日志
journalctl -u smart-network-monitor -f
```

## ⚙️ 配置说明

系统部署后，配置文件位于：`/etc/smart-network-monitor/config.json`

### 默认配置
```json
{
    "TargetIP": "192.168.3.3",
    "MonitorWindowSeconds": 180,
    "ShutdownCountdown": 60,
    "NormalPingInterval": 15
}
```

### 配置参数说明
- `TargetIP`: 监控的目标IP地址
- `MonitorWindowSeconds`: 监控窗口时长（秒），网络持续中断超过此时间将触发关机
- `ShutdownCountdown`: 关机倒计时时长（秒）
- `NormalPingInterval`: 正常监控时的ping间隔（秒）

### 修改配置
```bash
# 使用管理工具编辑（推荐）
smart-monitor

# 或直接编辑配置文件
sudo nano /etc/smart-network-monitor/config.json

# 修改配置后重启服务使配置生效
sudo systemctl restart smart-network-monitor
```

## 🗑️ 卸载

```bash
# 运行卸载脚本
sudo ./uninstall_system.sh
```

卸载脚本会询问是否删除配置文件和日志文件，您可以选择保留或删除。

## 📊 功能特性

- ✅ 开机自启动，无需用户登录
- ✅ 系统级权限运行
- ✅ 智能日志管理（应用日志 + 系统日志）
- ✅ JSON配置文件支持
- ✅ 自动日志清理（30天）
- ✅ 网络恢复自动取消关机
- ✅ 完整的错误处理和信号处理
- ✅ 彩色终端输出
- ✅ 交互式管理工具

## 🔧 系统要求

### 必需软件包
- `ping` (通常已预装)
- `systemctl` (systemd)
- `journalctl` (systemd)

### 推荐软件包
```bash
# 安装jq以获得更好的JSON配置支持
sudo apt-get update
sudo apt-get install jq
```

### 支持的系统
- Ubuntu 16.04+ (带systemd)
- Debian 8+ (带systemd)
- 其他使用systemd的Linux发行版

## 🔐 安全说明

- 脚本需要root权限以执行关机操作
- systemd服务以root权限运行
- 所有操作都会记录在应用日志和系统日志中
- 支持通过systemd进行完整的服务管理和监控

## 📝 使用示例

### 1. 基本使用流程

```bash
# 1. 部署系统级服务
sudo ./deploy_system.sh

# 2. 检查服务状态
systemctl status smart-network-monitor

# 3. 查看实时日志
journalctl -u smart-network-monitor -f

# 4. 使用管理工具
smart-monitor
```

### 2. 自定义配置示例

```bash
# 编辑配置文件
sudo nano /etc/smart-network-monitor/config.json

# 修改为监控路由器
{
    "TargetIP": "192.168.1.1",
    "MonitorWindowSeconds": 300,
    "ShutdownCountdown": 120,
    "NormalPingInterval": 30
}

# 重启服务应用配置
sudo systemctl restart smart-network-monitor
```

### 3. 故障排除

```bash
# 查看服务详细状态
systemctl status smart-network-monitor -l

# 查看最近的错误日志
journalctl -u smart-network-monitor --since "1 hour ago"

# 测试网络连接
ping -c 4 192.168.3.3

# 手动运行脚本进行调试
sudo /opt/smart-network-monitor/smart_shutdown_system.sh
```

## 🚨 注意事项

1. **关机权限**：脚本需要root权限才能执行关机操作
2. **网络依赖**：确保目标IP地址可达且稳定响应ping
3. **测试模式**：默认脚本在关机时会输出模拟信息，取消注释 `shutdown -h now` 行以启用实际关机
4. **备份重要数据**：在启用实际关机功能前，请确保重要数据已备份
5. **防火墙设置**：确保ICMP ping包不被防火墙阻挡

## 🔗 相关命令速查

```bash
# 服务管理
sudo systemctl start smart-network-monitor      # 启动
sudo systemctl stop smart-network-monitor       # 停止
sudo systemctl restart smart-network-monitor    # 重启
sudo systemctl status smart-network-monitor     # 状态
sudo systemctl enable smart-network-monitor     # 开机启动
sudo systemctl disable smart-network-monitor    # 禁用启动

# 日志查看
journalctl -u smart-network-monitor             # 所有日志
journalctl -u smart-network-monitor -f          # 实时日志
journalctl -u smart-network-monitor -n 50       # 最近50行
tail -f /var/log/smart-network-monitor/network_monitor_$(date '+%Y%m%d').log  # 应用日志

# 配置管理
sudo nano /etc/smart-network-monitor/config.json  # 编辑配置
cat /etc/smart-network-monitor/config.json        # 查看配置

# 管理工具
smart-monitor                                    # 交互式管理
```

## 📞 技术支持

如果您在使用过程中遇到问题，请：

1. 检查系统日志：`journalctl -u smart-network-monitor -n 100`
2. 验证网络连接：`ping 目标IP`
3. 检查配置文件格式：`jq . /etc/smart-network-monitor/config.json`
4. 查看服务状态：`systemctl status smart-network-monitor -l`

---

**享受智能网络监控带来的便利！** 🎉