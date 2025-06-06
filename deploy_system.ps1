<#
.SYNOPSIS
    智能网络监控脚本 - 系统级部署脚本

.DESCRIPTION
    将脚本部署到系统级目录，配置为开机自启动，无需用户登录
    
    部署位置：
    - 程序文件: C:\Program Files\SmartNetworkMonitor\
    - 配置文件: C:\ProgramData\SmartNetworkMonitor\
    - 日志文件: C:\ProgramData\SmartNetworkMonitor\logs\
#>

# 定义系统级路径
$ProgramPath = "C:\Program Files\SmartNetworkMonitor"
$DataPath = "C:\ProgramData\SmartNetworkMonitor"
$LogPath = "$DataPath\logs"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "智能网络监控脚本 - 系统级部署" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "部署计划:" -ForegroundColor Yellow
Write-Host "- 程序目录: $ProgramPath" -ForegroundColor White
Write-Host "- 数据目录: $DataPath" -ForegroundColor White
Write-Host "- 日志目录: $LogPath" -ForegroundColor White
Write-Host ""

# 检查源文件
$SourcePath = $PSScriptRoot
$RequiredFiles = @(
    "smart_shutdown.ps1"
)

foreach ($file in $RequiredFiles) {
    if (-not (Test-Path -Path (Join-Path $SourcePath $file))) {
        Write-Error "找不到必需文件: $file"
        exit 1
    }
}

Write-Host "[OK] 源文件检查完成" -ForegroundColor Green

# 创建目录结构
Write-Host "正在创建目录结构..." -ForegroundColor Yellow

try {
    # 创建程序目录
    if (-not (Test-Path -Path $ProgramPath)) {
        New-Item -Path $ProgramPath -ItemType Directory -Force | Out-Null
        Write-Host "[OK] 创建程序目录: $ProgramPath" -ForegroundColor Green
    }

    # 创建数据目录
    if (-not (Test-Path -Path $DataPath)) {
        New-Item -Path $DataPath -ItemType Directory -Force | Out-Null
        Write-Host "[OK] 创建数据目录: $DataPath" -ForegroundColor Green
    }

    # 创建日志目录
    if (-not (Test-Path -Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
        Write-Host "[OK] 创建日志目录: $LogPath" -ForegroundColor Green
    }
}
catch {
    Write-Error "创建目录失败: $($_.Exception.Message)"
    exit 1
}

# 创建系统优化版的主脚本
Write-Host "正在创建系统版本的脚本..." -ForegroundColor Yellow

$SystemScriptContent = @"
#Requires -Version 5.1

<#
.SYNOPSIS
    智能网络监控脚本 - 系统服务版本

.DESCRIPTION
    系统级网络监控脚本，在网络持续中断时自动关机
    
    特点：
    - 开机自启动，无需用户登录
    - 日志存储在系统数据目录
    - 优化的错误处理和权限管理
#>

# ==================== 系统级配置参数 ====================

# 监控的目标IP地址
[string]`$TargetIP = "192.168.3.3"

# 正常监控时的ping间隔（秒）
[int]`$NormalPingInterval = 15

# 监控窗口时长（秒） - 在此期间持续失败则触发关机
[int]`$MonitorWindowSeconds = 180

# 关机倒计时时长（秒）
[int]`$ShutdownCountdown = 60

# 关机倒计时阶段的ping间隔（秒）
[int]`$CountdownPingInterval = 3

# 系统级日志配置
[string]`$LogDirectory = "$LogPath"
[string]`$LogFile = Join-Path -Path `$LogDirectory -ChildPath "network_monitor_`$(Get-Date -Format 'yyyyMMdd').log"
[string]`$ConfigFile = "$DataPath\config.json"
[int]`$MaxLogDays = 30

# 正常连接时的日志记录间隔计数器
[int]`$normalLogInterval = 24  # 每24次循环记录一次状态 (约6分钟)
[int]`$normalLogCounter = 0

# =================================================

# --- 函数定义 ---

# 加载配置文件
function Load-Configuration {
    if (Test-Path -Path `$ConfigFile) {
        try {
            `$config = Get-Content -Path `$ConfigFile | ConvertFrom-Json
            if (`$config.TargetIP) { `$script:TargetIP = `$config.TargetIP }
            if (`$config.MonitorWindowSeconds) { `$script:MonitorWindowSeconds = `$config.MonitorWindowSeconds }
            if (`$config.ShutdownCountdown) { `$script:ShutdownCountdown = `$config.ShutdownCountdown }
            if (`$config.NormalPingInterval) { `$script:NormalPingInterval = `$config.NormalPingInterval }
            Write-Log -Level "INFO" -Message "配置文件加载成功"
        }
        catch {
            Write-Log -Level "WARN" -Message "配置文件格式错误，使用默认配置"
        }
    } else {
        # 创建默认配置文件
        `$defaultConfig = @{
            TargetIP = `$TargetIP
            MonitorWindowSeconds = `$MonitorWindowSeconds
            ShutdownCountdown = `$ShutdownCountdown
            NormalPingInterval = `$NormalPingInterval
        }
        try {
            `$defaultConfig | ConvertTo-Json | Set-Content -Path `$ConfigFile
            Write-Log -Level "INFO" -Message "创建默认配置文件: `$ConfigFile"
        }
        catch {
            Write-Log -Level "WARN" -Message "无法创建配置文件，使用内置默认值"
        }
    }
}

# 日志写入函数
function Write-Log {
    param(
        [Parameter(Mandatory=`$true)]
        [ValidateSet("INFO", "SUCCESS", "FAIL", "WARN", "CRITICAL", "DEBUG")]
        [string]`$Level,

        [Parameter(Mandatory=`$true)]
        [string]`$Message
    )

    `$logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    `$logEntry = "[`$logTimestamp] [`$Level] `$Message"

    # 尝试写入日志文件
    try {
        if (-not (Test-Path -Path `$LogDirectory)) {
            New-Item -Path `$LogDirectory -ItemType Directory -ErrorAction Stop | Out-Null
        }
        Add-Content -Path `$LogFile -Value `$logEntry -ErrorAction Stop
    }
    catch {
        # 如果写入失败，尝试输出到事件日志
        try {
            if (-not [System.Diagnostics.EventLog]::SourceExists("SmartNetworkMonitor")) {
                New-EventLog -LogName "Application" -Source "SmartNetworkMonitor"
            }
            Write-EventLog -LogName "Application" -Source "SmartNetworkMonitor" -EventId 1001 -EntryType Information -Message `$logEntry
        }
        catch {
            # 最后尝试输出到控制台（虽然在服务模式下不可见）
            Write-Host "[`$logTimestamp] [CRITICAL] 日志写入失败！`$Message"
        }
    }

    # 在服务模式下，也输出到事件日志作为备份
    try {
        if (`$Level -eq "CRITICAL" -or `$Level -eq "FAIL") {
            Write-EventLog -LogName "Application" -Source "SmartNetworkMonitor" -EventId 1002 -EntryType Warning -Message `$logEntry -ErrorAction SilentlyContinue
        }
    }
    catch {
        # 忽略事件日志写入错误
    }
}

# 清理旧日志文件
function Remove-OldLogs {
    try {
        `$cutoffDate = (Get-Date).AddDays(-`$MaxLogDays)
        `$oldLogs = Get-ChildItem -Path `$LogDirectory -Filter "network_monitor_*.log" | Where-Object { `$_.LastWriteTime -lt `$cutoffDate }
        foreach (`$oldLog in `$oldLogs) {
            Remove-Item -Path `$oldLog.FullName -Force
            Write-Log -Level "INFO" -Message "删除旧日志文件: `$(`$oldLog.Name)"
        }
    }
    catch {
        Write-Log -Level "WARN" -Message "清理旧日志文件时出错: `$(`$_.Exception.Message)"
    }
}

# =================================================

# --- 主程序开始 ---

# 初始化
Load-Configuration
Remove-OldLogs

# 获取系统信息
try {
    `$runningAs = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    `$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.InterfaceAlias -notmatch "Loopback" } | Select-Object -First 1).IPAddress
}
catch {
    `$runningAs = "Unknown"
    `$localIP = "Unknown"
}

Write-Log -Level "INFO" -Message "========== 系统级网络监控脚本启动 =========="
Write-Log -Level "INFO" -Message "运行账户: `$runningAs"
Write-Log -Level "INFO" -Message "本机IP: `$localIP"
Write-Log -Level "INFO" -Message "监控目标: `$TargetIP"
Write-Log -Level "INFO" -Message "监控窗口: `${MonitorWindowSeconds}秒"
Write-Log -Level "INFO" -Message "关机倒计时: `${ShutdownCountdown}秒"
Write-Log -Level "INFO" -Message "日志目录: `$LogDirectory"
Write-Log -Level "INFO" -Message "配置文件: `$ConfigFile"

# 主循环
`$failureStartTime = `$null

while (`$true) {
    # 测试网络连接
    try {
        `$pingResult = Test-Connection -ComputerName `$TargetIP -Count 1 -Quiet -ErrorAction SilentlyContinue
        `$isOnline = `$pingResult
    }
    catch {
        Write-Log -Level "FAIL" -Message "网络测试出现异常: `$(`$_.Exception.Message)"
        `$isOnline = `$false
    }

    if (`$isOnline) {
        if (`$failureStartTime) {
            Write-Log -Level "SUCCESS" -Message "网络连接已恢复。"
            `$failureStartTime = `$null
        } else {
            # 减少正常连接时的日志频率
            `$normalLogCounter++
            if (`$normalLogCounter -ge `$normalLogInterval) {
                Write-Log -Level "INFO" -Message "网络连接正常 (定期状态报告)"
                `$normalLogCounter = 0
            }
        }
        
        Start-Sleep -Seconds `$NormalPingInterval

    } else {
        # 网络不通时的处理逻辑
        Write-Log -Level "FAIL" -Message "Ping失败 - 目标: `$TargetIP"
        
        if (-not `$failureStartTime) {
            `$failureStartTime = Get-Date
            Write-Log -Level "WARN" -Message "网络首次中断，开始进入监控窗口计时。"
        }

        `$failureDuration = (New-TimeSpan -Start `$failureStartTime -End (Get-Date)).TotalSeconds
        Write-Log -Level "INFO" -Message "网络已持续中断 `$([math]::Round(`$failureDuration)) / `${MonitorWindowSeconds} 秒。"

        if (`$failureDuration -ge `$MonitorWindowSeconds) {
            Write-Log -Level "CRITICAL" -Message "网络持续中断已超过 `${MonitorWindowSeconds} 秒，开始关机流程。"
            
            `$shutdownCancelled = `$false
            `$countdownEndTime = (Get-Date).AddSeconds(`$ShutdownCountdown)
            
            while ((Get-Date) -lt `$countdownEndTime -and -not `$shutdownCancelled) {
                `$remainingSeconds = [math]::Ceiling((`$countdownEndTime - (Get-Date)).TotalSeconds)
                if (`$remainingSeconds -le 0) { break }
                
                Write-Log -Level "WARN" -Message "距离关机还有 `$remainingSeconds 秒... 正在快速检测网络。"
                
                # 在倒计时中再次检测网络
                try {
                    if (Test-Connection -ComputerName `$TargetIP -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                        Write-Log -Level "SUCCESS" -Message "网络在倒计时期间恢复！取消关机。"
                        `$failureStartTime = `$null
                        `$shutdownCancelled = `$true
                        break
                    }
                }
                catch {
                    Write-Log -Level "WARN" -Message "倒计时期间网络测试出现异常: `$(`$_.Exception.Message)"
                }
                
                Start-Sleep -Seconds `$CountdownPingInterval
            }
            
            if (-not `$shutdownCancelled) {
                Write-Log -Level "CRITICAL" -Message "关机倒计时完成，执行系统关机命令。"
                try {
                    # 执行实际关机命令
                    Stop-Computer -Force
                    Write-Log -Level "CRITICAL" -Message "关机命令已执行。"
                }
                catch {
                    Write-Log -Level "CRITICAL" -Message "关机命令执行失败: `$(`$_.Exception.Message)"
                }
                exit
            }
        } else {
            Start-Sleep -Seconds `$NormalPingInterval
        }
    }
}
"@

# 写入系统版本脚本
$SystemScriptPath = Join-Path $ProgramPath "smart_shutdown_system.ps1"
try {
    $SystemScriptContent | Set-Content -Path $SystemScriptPath -Encoding UTF8
    Write-Host "[OK] 创建系统脚本: $SystemScriptPath" -ForegroundColor Green
}
catch {
    Write-Error "创建系统脚本失败: $($_.Exception.Message)"
    exit 1
}

# 创建默认配置文件
Write-Host "正在创建配置文件..." -ForegroundColor Yellow

$DefaultConfig = @{
    TargetIP = "192.168.3.3"
    MonitorWindowSeconds = 180
    ShutdownCountdown = 60
    NormalPingInterval = 15
}

$ConfigPath = Join-Path $DataPath "config.json"
try {
    $DefaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigPath -Encoding UTF8
    Write-Host "[OK] 创建配置文件: $ConfigPath" -ForegroundColor Green
}
catch {
    Write-Error "创建配置文件失败: $($_.Exception.Message)"
    exit 1
}

# 配置任务计划程序
Write-Host "正在配置任务计划程序..." -ForegroundColor Yellow

try {
    # 删除已存在的任务（如果有）
    try {
        Unregister-ScheduledTask -TaskName "Smart Network Shutdown Monitor" -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch {
        # 忽略错误，任务可能不存在
    }

    # 创建触发器（系统启动时）
    $Trigger = New-ScheduledTaskTrigger -AtStartup

    # 创建操作
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SystemScriptPath`""

    # 创建设置
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Days 365)

    # 创建主体（以SYSTEM身份运行）
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # 注册任务
    Register-ScheduledTask -TaskName "Smart Network Shutdown Monitor" -Trigger $Trigger -Action $Action -Settings $Settings -Principal $Principal -Description "智能网络监控脚本 - 系统级运行"

    Write-Host "[OK] 任务计划程序配置完成" -ForegroundColor Green
}
catch {
    Write-Error "配置任务计划程序失败: $($_.Exception.Message)"
    exit 1
}

# 创建管理脚本
Write-Host "正在创建管理工具..." -ForegroundColor Yellow

$ManagementScript = @"
# 智能网络监控脚本 - 管理工具

Write-Host "智能网络监控脚本 - 管理工具" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

Write-Host "可用操作:" -ForegroundColor Yellow
Write-Host "1. 查看任务状态"
Write-Host "2. 启动监控任务"
Write-Host "3. 停止监控任务"
Write-Host "4. 查看今天的日志"
Write-Host "5. 查看实时日志"
Write-Host "6. 查看配置文件"
Write-Host "7. 编辑配置文件"
Write-Host ""

`$choice = Read-Host "请选择操作 (1-7)"

switch (`$choice) {
    "1" {
        Get-ScheduledTask -TaskName "Smart Network Shutdown Monitor" | Format-Table
    }
    "2" {
        Start-ScheduledTask -TaskName "Smart Network Shutdown Monitor"
        Write-Host "任务已启动" -ForegroundColor Green
    }
    "3" {
        Stop-ScheduledTask -TaskName "Smart Network Shutdown Monitor"
        Write-Host "任务已停止" -ForegroundColor Green
    }
    "4" {
        `$logFile = "$LogPath\network_monitor_`$(Get-Date -Format 'yyyyMMdd').log"
        if (Test-Path `$logFile) {
            Get-Content `$logFile
        } else {
            Write-Host "今天的日志文件不存在" -ForegroundColor Red
        }
    }
    "5" {
        `$logFile = "$LogPath\network_monitor_`$(Get-Date -Format 'yyyyMMdd').log"
        if (Test-Path `$logFile) {
            Get-Content `$logFile -Wait
        } else {
            Write-Host "今天的日志文件不存在" -ForegroundColor Red
        }
    }
    "6" {
        Get-Content "$DataPath\config.json"
    }
    "7" {
        notepad "$DataPath\config.json"
    }
    default {
        Write-Host "无效选择" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "常用命令:" -ForegroundColor Yellow
Write-Host "1. 查看任务状态:"
Write-Host "   Get-ScheduledTask -TaskName 'Smart Network Shutdown Monitor'"
Write-Host ""
Write-Host "2. 启动任务:"
Write-Host "   Start-ScheduledTask -TaskName 'Smart Network Shutdown Monitor'"
Write-Host ""
Write-Host "3. 停止任务:"
Write-Host "   Stop-ScheduledTask -TaskName 'Smart Network Shutdown Monitor'"
Write-Host ""
Write-Host "4. 查看今天日志:"
Write-Host "   Get-Content '$LogPath\network_monitor_`$(Get-Date -Format 'yyyyMMdd').log'"
Write-Host ""
Write-Host "5. 实时查看日志:"
Write-Host "   Get-Content '$LogPath\network_monitor_`$(Get-Date -Format 'yyyyMMdd').log' -Wait"
Write-Host ""
Write-Host "6. 查看配置:"
Write-Host "   Get-Content '$DataPath\config.json'"
Write-Host ""
Write-Host "7. 编辑配置文件:"
Write-Host "   notepad '$DataPath\config.json'"
Write-Host ""
"@

$ManagementScriptPath = Join-Path $ProgramPath "manage.ps1"
try {
    $ManagementScript | Set-Content -Path $ManagementScriptPath -Encoding UTF8
    Write-Host "[OK] 创建管理脚本: $ManagementScriptPath" -ForegroundColor Green
}
catch {
    Write-Error "创建管理脚本失败: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Write-Host "[INFO] 系统级部署完成！" -ForegroundColor Green
Write-Host ""
Write-Host "部署摘要:" -ForegroundColor Cyan
Write-Host "[OK] 程序文件已部署到: $ProgramPath" -ForegroundColor White
Write-Host "[OK] 数据目录已创建: $DataPath" -ForegroundColor White
Write-Host "[OK] 日志目录已创建: $LogPath" -ForegroundColor White
Write-Host "[OK] 任务计划程序已配置（系统启动时运行）" -ForegroundColor White
Write-Host "[OK] SYSTEM 权限配置完成" -ForegroundColor White
Write-Host ""
Write-Host "管理工具:" -ForegroundColor Yellow
Write-Host "- 管理脚本: $ManagementScriptPath" -ForegroundColor White
Write-Host "- 配置文件: $DataPath\config.json" -ForegroundColor White
Write-Host "- 今天日志: $LogPath\network_monitor_$(Get-Date -Format 'yyyyMMdd').log" -ForegroundColor White
Write-Host ""
Write-Host "下次重启后，脚本将自动运行！" -ForegroundColor Green
Write-Host ""

# 询问是否立即启动
$response = Read-Host "是否立即启动监控任务？(Y/N)"
if ($response -eq 'Y' -or $response -eq 'y' -or $response -eq '') {
    try {
        Start-ScheduledTask -TaskName "Smart Network Shutdown Monitor"
        Write-Host "[OK] 监控任务已启动" -ForegroundColor Green
    }
    catch {
        Write-Host "[X] 启动任务失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}
