# Smart Network Shutdown Monitor

持续监测目标网络连通性并在网络断开超时后自动关闭系统的跨平台常驻服务程序。

## 安装指南 (Installation)

本程序支持安装为操作系统的后台服务，并自动注册全局环境变量以便统一管理。

### Windows 系统

推荐以拥有管理员权限的系统服务形式部署。

1. **获取程序**
   前往 [Releases](https://github.com/UnbalancedCat/smart-shutdown/releases) 页面，下载最新的 `smart-shutdown_windows_amd64.exe` (或其它架构版本)。

2. **终端安装**
   在下载目录的空白处右键选择 **以管理员身份打开 PowerShell 或 CMD**，执行如下指令：
   ```powershell
   .\smart-shutdown_windows_amd64.exe install
   smart-shutdown start
   ```
   > **说明：** `install` 指令会自动将程序复制到 `C:\Program Files\SmartShutdown\` 并写入系统 `PATH` 环境变量中，同时注册为 Windows 开机自启服务。此后您可在任意终端直接使用 `smart-shutdown` 命令。

### Linux (Ubuntu/Debian/CentOS 等)

如您具备 `sudo` 权限，可在终端中执行以下单行命令进行自动化下载与 `systemd` 服务部署：

```bash
sudo curl -sSL https://github.com/UnbalancedCat/smart-shutdown/releases/latest/download/smart-shutdown_linux_amd64 -o /usr/local/bin/smart-shutdown && \
sudo chmod +x /usr/local/bin/smart-shutdown && \
sudo smart-shutdown install && \
sudo smart-shutdown start
```

## CLI 终端管理指令 (Commands)

完成服务注册后，可通过以下指令直接管理守护进程状态流。
*(注: 启停服务及修改配置的指令需在 **管理员级别 / root 权限** 终端内执行)*

### 运行状态查询
输出当前服务存活状态、载入的配置参数、日志存放路径及最近 10 条日志：
```bash
smart-shutdown status
```

### 修改系统配置
直接修改配置参数并执行合法性校验。(注: 改写配置后必须执行 `smart-shutdown restart` 重启服务才能应用生效)
```bash
# 修改目标监控 IP 地址
smart-shutdown config set TargetIP 192.168.0.1

# 修改断网响应的容忍监控窗口
smart-shutdown config set MonitorWindowSeconds 300
```

### 服务生命周期控制
```bash
# 停止当前运行的后台网络探测服务
smart-shutdown stop

# 启动后台服务并恢复网络探测
smart-shutdown start

# 重启后台服务
smart-shutdown restart
```

### 服务与环境卸载
停止并注销后台服务，清理系统目录中的程序副本与对应的系统环境变量：
```bash
smart-shutdown uninstall
```

*(如需查看完整的帮助说明，可执行 `smart-shutdown help`)*

## 默认配置参数详情
程序会在对应操作系统的后台数据存放区建立或读取 JSON 配置文件：
- Windows: `C:\ProgramData\SmartNetworkMonitor\config.json`
- Linux: `/etc/smart-network-monitor/config.json`

| 参数项 | 含义与功能说明 | 默认值 |
|:---|:---|:---|
| `TargetIP` | 需发送 ICMP 包验证联通性的目标 IPv4 地址。 | `192.168.3.3` |
| `MonitorWindowSeconds` | 网络中断被判定为异常并触发系统关机前，所能容忍的最长超时时长 (秒)。 | `180` |
| `ShutdownCountdown` | 容忍超限后，执行正式关机系统指令的警告倒计时缓冲时间 (秒)。 | `60` |
| `NormalPingInterval` | 网络连通性正常时，每次静默发包探测的间隔时间 (秒)。 | `15` |

## 本地日志存放位置
程序按日切割保存网络探测及中断记录，默认留存最近 30 天的文件：
- **Windows**: `C:\ProgramData\SmartNetworkMonitor\logs\network_monitor.log`
- **Linux**: `/var/log/smart-network-monitor/network_monitor.log`
