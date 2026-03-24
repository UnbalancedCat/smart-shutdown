# API Reference — Smart Network Shutdown Monitor

完整的 CLI 命令说明与参数参考文档。

> **注意：** 服务管理相关指令（`start`, `stop`, `restart`, `install`, `uninstall`）均需在**管理员 (Windows) / root (Linux)** 权限下执行。

---

## 服务生命周期

### `start`
唤起并注册后台监控守护进程，服务将随系统开机自动启动。

```bash
smart-shutdown start
```

### `stop`
停止当前运行的后台网络探测服务。

```bash
smart-shutdown stop
```

### `restart`
重启后台服务（配置变更后需执行此命令以应用新配置）。

```bash
smart-shutdown restart
```

### `status`
输出当前服务存活状态、载入的配置参数、日志存放路径及最近 10 条日志。

```bash
smart-shutdown status
```

---

## 安装与卸载

### `install`
将可执行文件复制至系统目录并写入全局环境变量，同时注册为开机自启服务。

```bash
smart-shutdown install
```

### `uninstall`
停止并注销后台服务，清理系统目录中的程序副本与环境变量。执行时将询问是否同时清除配置文件与日志。

```bash
smart-shutdown uninstall
```

---

## 配置管理

### `config set <Key> <Value>`
直接修改指定配置项，并执行合法性校验。改写后需执行 `restart` 使其生效。

```bash
# 修改目标监控 IP 地址
smart-shutdown config set TargetIP 192.168.0.1

# 修改断网容忍时长（秒）
smart-shutdown config set MonitorWindowSeconds 300

# 修改关机倒计时缓冲（秒）
smart-shutdown config set ShutdownCountdown 60

# 修改探测发包间隔（秒）
smart-shutdown config set NormalPingInterval 15
```

**可用配置项：**

| 参数项 | 含义 | 默认值 |
|:---|:---|:---|
| `TargetIP` | 目标 IPv4 地址，程序向其发送 ICMP 包检测联通性。 | `192.168.3.1` |
| `MonitorWindowSeconds` | 网络中断超出此时长（秒）则触发关机流程。 | `180` |
| `ShutdownCountdown` | 正式关机前的倒计时缓冲时间（秒）。 | `60` |
| `NormalPingInterval` | 网络正常时的探测发包间隔（秒）。 | `15` |

**配置文件路径：**
- Windows: `C:\ProgramData\SmartNetworkMonitor\config.json`
- Linux: `/etc/smart-network-monitor/config.json`

---

## 后台休眠控制

### `pause`
向正在运行的后台守护进程发送休眠指令，后台停止发包但**不启动前台监控**。必须指定 `--stop-after` 或 `--stop-at` 之一（或同时指定，以先到达的时间为准）。

```bash
# 休眠 2 小时后自动唤醒
smart-shutdown pause --stop-after 2h

# 休眠至明早 8 点自动唤醒
smart-shutdown pause --stop-at "2026-03-25 08:00:00"

# 同时指定两个时间，取较早者
smart-shutdown pause --stop-after 3h --stop-at "2026-03-25 08:00:00"
```

| Flag | 说明 | 格式示例 |
|:---|:---|:---|
| `--stop-after` | 休眠时长，到期自动唤醒。 | `30m`, `2h`, `1h30m` |
| `--stop-at` | 休眠至指定绝对时间自动唤醒。 | `"2026-03-25 08:00:00"` |

### `resume`
立即撤销休眠指令，后台将在下一轮探测周期（约 15 秒内）重新激活。

```bash
smart-shutdown resume
```

---

## 前台临时监控模式

直接执行 `smart-shutdown`（不带子命令）可进入前台临时监控模式，日志将写入 `network_monitor_front.log` 与原后台日志隔离。

- 监控参数（`--target-ip` 等）未指定时，使用配置文件中的值。
- **运行时长参数**（`--stop-after` / `--stop-at`）均未指定时，前台监控将**一直运行**，直到手动按 `Ctrl+C` 终止。

```bash
smart-shutdown [flags]
```

| Flag | 说明 | 示例 |
|:---|:---|:---|
| `--target-ip` | 临时覆盖目标监控 IP | `--target-ip 8.8.8.8` |
| `--window-sec` | 临时覆盖断网容忍时长（秒） | `--window-sec 60` |
| `--shutdown-cnt` | 临时覆盖关机倒计时（秒） | `--shutdown-cnt 10` |
| `--ping-interval` | 临时覆盖探测发包间隔（秒） | `--ping-interval 5` |
| `--override-bg` | 挂起后台守护进程，由前台全面接管，退出时自动恢复后台 | `--override-bg` |
| `--stop-after` | 前台运行指定时长后自动退出 | `--stop-after 2h30m` |
| `--stop-at` | 前台运行至指定时间自动退出 | `--stop-at "2026-03-25 08:00:00"` |

**使用示例：**

```bash
# 临时将目标 IP 改为 8.8.8.8，60 秒无响应触发
smart-shutdown --target-ip 8.8.8.8 --window-sec 60

# 接管后台，30 分钟后自动退出并恢复后台
smart-shutdown --override-bg --stop-after 30m

# 接管后台，运行至明早 8 点自动退出并恢复后台
smart-shutdown --override-bg --stop-at "2026-03-25 08:00:00"
```

---

## 其他

### `update`
联网拉取最新版本并热部署更新。

```bash
smart-shutdown update
```

### `--version` / `-V`
查看当前版本号并拉取最新发布状态。

```bash
smart-shutdown --version
```

### `--verbose` / `-v`
打印底层部署及环境追溯 Debug 信息（对所有子命令生效）。

```bash
smart-shutdown status --verbose
```

---

## 日志文件位置

| 场景 | Windows | Linux |
|:---|:---|:---|
| 后台服务日志 | `C:\ProgramData\SmartNetworkMonitor\logs\network_monitor.log` | `/var/log/smart-network-monitor/network_monitor.log` |
| 前台临时监控日志 | `C:\ProgramData\SmartNetworkMonitor\logs\network_monitor_front.log` | `/var/log/smart-network-monitor/network_monitor_front.log` |

程序按日自动切割日志，默认保留最近 30 天。
