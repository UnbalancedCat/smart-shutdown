# 智能网络监控脚本 - 系统部署版

## 📁 文件结构

```
smart_shutdown/
├── smart_shutdown.ps1          # 原始监控脚本（用户模式）
├── deploy_system.ps1           # 系统级部署脚本
├── uninstall_system.ps1        # 系统级卸载脚本
├── TEST_REPORT.md              # 测试报告
├── README.md                   # 本文件
└── logs/                       # 本地测试日志目录
    └── network_monitor_20250606.log
```

## 🚀 快速部署

### 系统级部署（推荐）
```powershell
# 以管理员身份运行
.\deploy_system.ps1
```

**部署效果：**
- 程序部署到：`C:\Program Files\SmartNetworkMonitor\`
- 配置和日志：`C:\ProgramData\SmartNetworkMonitor\`
- 开机自启动，无需用户登录
- 以 SYSTEM 权限运行

### 用户级运行
```powershell
# 以管理员身份运行（需要用户登录）
.\smart_shutdown.ps1
```

## 🎯 系统部署后的文件位置

### 程序文件位置
```
C:\Program Files\SmartNetworkMonitor\
├── smart_shutdown_system.ps1   # 系统优化版监控脚本
└── manage.ps1                  # 管理工具脚本
```

### 数据文件位置
```
C:\ProgramData\SmartNetworkMonitor\
├── config.json                 # 配置文件
└── logs\                       # 系统日志目录
    └── network_monitor_YYYYMMDD.log
```

## 🔧 管理命令

### 查看任务状态
```powershell
Get-ScheduledTask -TaskName "Smart Network Shutdown Monitor"
```

### 启动/停止监控
```powershell
Start-ScheduledTask -TaskName "Smart Network Shutdown Monitor"
Stop-ScheduledTask -TaskName "Smart Network Shutdown Monitor"
```

### 查看日志
```powershell
# 查看今天的日志
Get-Content "C:\ProgramData\SmartNetworkMonitor\logs\network_monitor_$(Get-Date -Format 'yyyyMMdd').log"

# 实时监控日志
Get-Content "C:\ProgramData\SmartNetworkMonitor\logs\network_monitor_$(Get-Date -Format 'yyyyMMdd').log" -Wait
```

### 查看系统事件日志
```powershell
Get-EventLog -LogName Application -Source SmartNetworkMonitor -Newest 20
```

## ⚙️ 配置说明

系统部署后，配置文件位于：`C:\ProgramData\SmartNetworkMonitor\config.json`

默认配置：
```json
{
    "TargetIP": "192.168.3.3",
    "MonitorWindowSeconds": 180,
    "ShutdownCountdown": 60,
    "NormalPingInterval": 15
}
```

修改配置文件后，重启监控任务使配置生效：
```powershell
Stop-ScheduledTask -TaskName "Smart Network Shutdown Monitor"
Start-ScheduledTask -TaskName "Smart Network Shutdown Monitor"
```

## 🗑️ 卸载

```powershell
# 以管理员身份运行
.\uninstall_system.ps1
```

## 📊 特性

- ✅ 开机自启动，无需用户登录
- ✅ 系统级权限运行
- ✅ 智能日志管理
- ✅ 配置文件支持
- ✅ 事件日志备份
- ✅ 自动日志清理（30天）
- ✅ 网络恢复自动取消关机
- ✅ 完整的错误处理

## 🔐 安全说明

- 脚本以 SYSTEM 权限运行，具有执行关机的完整权限
- 所有操作都会记录在日志和系统事件日志中
- 支持通过任务计划程序进行管理和监控
