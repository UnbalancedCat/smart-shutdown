# Smart Network Shutdown Monitor

持续监测目标网络连通性并在网络断开超时后自动关闭系统的跨平台常驻服务程序。

> **注意：** 本程序涉及系统服务注册与网络监控，所有安装、卸载及服务管理操作均**必须在管理员 (Windows) 或 root (Linux) 权限**下执行。

## 安装指南 (Installation)

本程序支持安装为操作系统的后台服务，并自动注册全局环境变量以便统一管理。

### Windows 系统

**以管理员身份打开 PowerShell**，执行以下一键安装命令：

```powershell
irm https://raw.githubusercontent.com/UnbalancedCat/smart-shutdown/main/install.ps1 | iex
```

> **说明：** 该命令会自动下载最新版本，执行 `install` 将程序复制到 `C:\Program Files\SmartShutdown\` 并写入系统 `PATH` 环境变量，同时注册为 Windows 开机自启服务。此后您可在任意管理员终端直接使用 `smart-shutdown` 命令。

### Linux (Ubuntu/Debian/CentOS 等)

在终端中执行以下一键安装命令：

```bash
curl -sSL https://raw.githubusercontent.com/UnbalancedCat/smart-shutdown/main/install.sh | sudo sh
```

## 快速开始

安装完成后，默认会自动运行如下引导，进行初始设置：

```
========== 首次配置 ==========
未检测到配置文件，将引导您完成初始设置。直接按回车使用 [默认值]。

目标监控 IP 地址 [192.168.3.1]: <输入您的目标 IP 或直接回车>
断网容忍超时时长 (秒) [180]:
关机倒计时缓冲 (秒) [60]:
探测发包间隔 (秒) [15]:

配置已保存至: C:\ProgramData\SmartNetworkMonitor\config.json
```

> **提示：** 服务注册后将**随系统开机自动启动**，无需手动干预。如需暂停监控，请执行 `smart-shutdown stop`。

## Windows 注意事项

如您在 Windows 上使用 `sudo` 命令（Windows 11 24H2+ 内置）来执行本程序，请注意：

Windows `sudo` 默认运行在 **ForceNewWindow（强制新窗口）** 模式下，提权进程的输出将打印到一个瞬间关闭的新窗口中，**导致 `status` 等展示类命令的输出不可见。**

**解决方法（任选其一）：**

1. **切换 sudo 为 Inline 模式**：打开 **系统设置 → 开发者选项 → 启用 sudo**，将模式改为 **内联 (Inline)**。此后 `sudo smart-shutdown status` 的输出将正常回显至当前终端。
2. **直接使用管理员终端**：右键点击终端图标，选择 **以管理员身份运行**，随后无需 `sudo` 前缀即可执行所有指令。

## 命令参考

完整的命令说明、参数列表与使用示例，请查阅 [API.md](./API.md)。

常用快捷参考：

| 命令 | 说明 |
|:---|:---|
| `smart-shutdown start` | 启动后台监控服务 |
| `smart-shutdown stop` | 停止后台监控服务 |
| `smart-shutdown restart` | 重启服务 |
| `smart-shutdown status` | 查看服务状态与最近日志 |
| `smart-shutdown config set <Key> <Value>` | 修改配置项 |
| `smart-shutdown pause --stop-after 2h` | 临时挂起后台 2 小时 |
| `smart-shutdown resume` | 立即恢复挂起的后台 |
| `smart-shutdown uninstall` | 卸载服务及环境变量 |

## 免安装便携使用与前台监控模式

如果您只是想临时使用网络检测自动关机功能，而**不想将程序安装为系统常驻服务**，您可以直接下载可执行文件进行免安装的便携式运行（基于前台模式）。

前往 [Releases](https://github.com/UnbalancedCat/smart-shutdown/releases) 页面下载对应您系统的可执行文件后，在同一目录下的终端中，直接带参数执行即可。例如：

```bash
# 临时在前台启动监控（非后台服务），检测目标 IP 8.8.8.8，脱机容忍设为 60 秒
.\smart-shutdown --target-ip 8.8.8.8 --window-sec 60
```

> **提示：** 
> 1. 前台模式下产生的日志将单独写入 `network_monitor_front.log`，不会影响原有数据。关闭当前终端即可停止监控进程。
> 2. 关于前台模式的 `--stop-after` (设定运行多少时间后退出)、`--override-bg` (接管正在运行的后台服务) 等高阶参数详细说明，请参阅 [API.md](./API.md)。

**扩展：手动安装为服务**

如果您下载了二进制文件后改变主意，想手动将其注册为系统服务，也可以直接使用 `install` 命令：

- **Windows**: 
  ```powershell
  .\smart-shutdown install
  ```
- **Linux**: 
  ```bash
  sudo mv ./smart-shutdown_linux_amd64 /usr/local/bin/smart-shutdown
  sudo chmod +x /usr/local/bin/smart-shutdown
  sudo smart-shutdown install
  ```
