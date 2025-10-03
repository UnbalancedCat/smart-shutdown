#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    一个智能网络监控脚本，当检测到与目标IP的网络持续中断后，会自动关闭计算机。

.DESCRIPTION
    该脚本会定期测试与指定目标IP的网络连通性。
    如果在设定的“监控窗口”时间内连接持续失败，脚本将启动一个可取消的关机倒计时。
    如果在倒计时期间网络恢复，关机将被中止。
    所有操作都会被记录在日志文件中。
#>

# ==================== 配置参数 ====================

# 监控的目标IP地址
[string]$TargetIP = "192.168.3.15"

# 正常监控时的ping间隔（秒）
[int]$NormalPingInterval = 15

# 监控窗口时长（秒） - 在此期间持续失败则触发关机
[int]$MonitorWindowSeconds = 60

# 关机倒计时时长（秒）
[int]$ShutdownCountdown = 60

# 关机倒计时阶段的ping间隔（秒）
[int]$CountdownPingInterval = 3

# ping超时时间（秒）
[int]$PingTimeout = 3

# 日志配置
[string]$LogDirectory = Join-Path -Path $PSScriptRoot -ChildPath "logs"
#[string]$LogFile = Join-Path -Path $LogDirectory -ChildPath "network_monitor_$(Get-Date -Format 'yyyyMMdd').log"
[int]$MaxLogDays = 30

# =================================================

# --- 函数定义 ---

# 日志写入函数
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("INFO", "SUCCESS", "FAIL", "WARN", "CRITICAL", "DEBUG")]
        [string]$Level,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    # ===================== V0.2update =====================
    # 每次写日志时，都重新根据当前日期确定日志文件名
    $LogFile = Join-Path -Path $LogDirectory -ChildPath "network_monitor_$(Get-Date -Format 'yyyyMMdd').log"
    # ====================================================

    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$logTimestamp] [$Level] $Message"

    # 尝试写入日志文件
    try {
        if (-not (Test-Path -Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory -ErrorAction Stop | Out-Null
        }
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Host "[$logTimestamp] [CRITICAL] 日志文件写入失败！请检查权限或磁盘空间。" -ForegroundColor Red
    }

    # 根据日志级别在控制台输出不同颜色的信息
    switch ($Level) {
        "SUCCESS"  { Write-Host $logEntry -ForegroundColor Green }
        "FAIL"     { Write-Host $logEntry -ForegroundColor Red }
        "WARN"     { Write-Host $logEntry -ForegroundColor Yellow }
        "CRITICAL" { Write-Host $logEntry -ForegroundColor DarkRed }
        default    { Write-Host $logEntry }
    }
}

# 获取本机的最佳IP地址
function Get-LocalIP {
    param($TargetIP)
    try {
        # 尝试寻找与目标IP在同一个子网的本机IP地址
        $targetSubnet = ($TargetIP.Split('.')[0..2]) -join '.'
        $ip = Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred | Where-Object { $_.IPAddress -like "$targetSubnet.*" } | Select-Object -First 1 -ExpandProperty IPAddress
        
        if ($ip) { return $ip }

        # 如果找不到，则返回任意一个非环回的私有IP地址
        $ip = Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred | Where-Object { $_.IPAddress -notlike "127.0.0.1" -and $_.InterfaceAlias -notlike "Loopback*" } | Select-Object -First 1 -ExpandProperty IPAddress
        return $ip
    }
    catch {
        return "未知"
    }
}


# --- 脚本主逻辑 ---

# 清理旧日志
if (Test-Path -Path $LogDirectory) {
    Get-ChildItem -Path $LogDirectory -Filter "*.log" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$MaxLogDays) } | Remove-Item
}

# 初始化
Clear-Host
$localIP = Get-LocalIP -TargetIP $TargetIP
Write-Log -Level "INFO" -Message "========== 脚本启动 =========="
Write-Log -Level "INFO" -Message "本机IP: $localIP"
Write-Log -Level "INFO" -Message "监控目标: $TargetIP"
Write-Log -Level "INFO" -Message "监控窗口: ${MonitorWindowSeconds}秒"
Write-Log -Level "INFO" -Message "关机倒计时: ${ShutdownCountdown}秒"
Write-Log -Level "INFO" -Message "日志文件: $LogFile"
Write-Log -Level "INFO" -Message "脚本已启动，按 Ctrl+C 退出..."
Write-Host "========================================"

# 主循环
$failureStartTime = $null
$normalStatusCounter = 0  # 正常状态计数器，用于定期记录正常运行日志
$normalStatusLogInterval = 24  # 每24次正常检测记录一次日志（约6分钟）

while ($true) {# 测试网络连接
    try {
        # 使用兼容性更好的ping方法
        $pingResult = Test-Connection -ComputerName $TargetIP -Count 1 -Quiet -ErrorAction SilentlyContinue
        $isOnline = $pingResult
    }    catch {
        Write-Log -Level "FAIL" -Message "网络测试出现异常: $($_.Exception.Message)"
        $isOnline = $false
    }    if ($isOnline) {
        if ($failureStartTime) {
            Write-Log -Level "SUCCESS" -Message "网络连接已恢复。"
            Write-Host "[OK] 网络连接已恢复，重置监控窗口" -ForegroundColor Green
            $failureStartTime = $null # 重置失败计时器
            $normalStatusCounter = 0  # 重置正常状态计数器
        } else {
            Write-Host "[OK] 网络连接正常" -ForegroundColor Green
            # 正常连接时减少日志频率，只定期记录
            $normalStatusCounter++
            if ($normalStatusCounter -ge $normalStatusLogInterval) {
                Write-Log -Level "INFO" -Message "网络连接持续正常（已检测 $normalStatusCounter 次）"
                $normalStatusCounter = 0  # 重置计数器
            }
        }
        # 只在控制台显示等待信息，不写入日志文件
        Write-Host "等待 ${NormalPingInterval}秒后继续监控..." -ForegroundColor Cyan
        Start-Sleep -Seconds $NormalPingInterval

    } else {
        # 如果网络不通
        Write-Log -Level "FAIL" -Message "Ping失败 - 目标: $TargetIP"
        
        if (-not $failureStartTime) {
            # 记录首次失败的时间
            $failureStartTime = Get-Date
            Write-Log -Level "WARN" -Message "网络首次中断，开始进入监控窗口计时。"
        }        # 计算网络已中断的时间
        $failureDuration = (New-TimeSpan -Start $failureStartTime -End (Get-Date)).TotalSeconds
        Write-Log -Level "INFO" -Message "网络已持续中断 $([math]::Round($failureDuration)) / ${MonitorWindowSeconds} 秒。"
        
        # 显示详细状态
        $remainingTime = $MonitorWindowSeconds - [math]::Round($failureDuration)
        Write-Host "监控状态 - 已中断: $([math]::Round($failureDuration))/${MonitorWindowSeconds}秒，剩余: ${remainingTime}秒" -ForegroundColor Yellow

        if ($failureDuration -ge $MonitorWindowSeconds) {
            # 持续失败时间超过监控窗口，开始关机倒计时
            Write-Log -Level "CRITICAL" -Message "网络持续中断已超过 ${MonitorWindowSeconds} 秒，开始关机流程。"
            Write-Host "========================================" -ForegroundColor Yellow
              $shutdownCancelled = $false
            $countdownEndTime = (Get-Date).AddSeconds($ShutdownCountdown)
              while ((Get-Date) -lt $countdownEndTime -and -not $shutdownCancelled) {
                $remainingSeconds = [math]::Ceiling(($countdownEndTime - (Get-Date)).TotalSeconds)
                if ($remainingSeconds -le 0) { break }
                
                Write-Log -Level "WARN" -Message "距离关机还有 $remainingSeconds 秒... 正在快速检测网络。"
                Write-Host "----------------------------------------" -ForegroundColor Yellow
                Write-Host "距离关机还有 $remainingSeconds 秒..." -ForegroundColor Yellow
                Write-Host "正在快速检测网络连接... 按任意键可手动取消关机" -ForegroundColor Yellow                # 在倒计时中再次检测网络
                try {
                    if (Test-Connection -ComputerName $TargetIP -Count 1 -Quiet -ErrorAction SilentlyContinue) {
                        Write-Log -Level "SUCCESS" -Message "网络在倒计时期间恢复！取消关机。"
                        Write-Host "========================================" -ForegroundColor Green
                        Write-Host "[OK] 网络连接已恢复！取消关机操作" -ForegroundColor Green
                        Write-Host "========================================" -ForegroundColor Green
                        $failureStartTime = $null
                        $shutdownCancelled = $true
                        break
                    } else {
                        Write-Host "[X] 网络仍然中断" -ForegroundColor Red
                    }
                }
                catch {
                    Write-Log -Level "WARN" -Message "倒计时期间网络测试出现异常: $($_.Exception.Message)"
                    Write-Host "[X] 网络测试异常" -ForegroundColor Red
                }
                  # 检查是否有按键输入（手动取消）
                $timeout = $CountdownPingInterval
                $startTime = Get-Date
                while (((Get-Date) - $startTime).TotalSeconds -lt $timeout -and -not $shutdownCancelled) {
                    if ([Console]::KeyAvailable) {
                        $null = [Console]::ReadKey($true)  # 读取按键但不使用
                        Write-Log -Level "WARN" -Message "用户手动取消了关机操作"                        Write-Host ""
                        Write-Host "========================================" -ForegroundColor Cyan
                        Write-Host "[INFO] 用户已手动取消关机，返回监控模式" -ForegroundColor Cyan
                        Write-Host "========================================" -ForegroundColor Cyan
                        $failureStartTime = $null
                        $shutdownCancelled = $true
                        break                    }
                    Start-Sleep -Milliseconds 100
                }
            }
            
            if (-not $shutdownCancelled) {
                Write-Log -Level "CRITICAL" -Message "关机倒计时完成，执行系统关机命令。"
                try {
                    # 取消注释下一行以启用实际关机
                    # Stop-Computer -Force
                    Write-Host "模拟关机：Stop-Computer -Force （为防止意外，此行已注释）" -ForegroundColor Red
                    Write-Log -Level "CRITICAL" -Message "关机命令已执行（模拟模式）。"
                }
                catch {
                    Write-Log -Level "CRITICAL" -Message "关机命令执行失败: $($_.Exception.Message)"
                }
                # 脚本执行完关机命令后可以退出
                exit
            }
        } else {
            # 在监控窗口期内，继续等待
            Write-Log -Level "INFO" -Message "等待 ${NormalPingInterval}秒后继续..."
            Start-Sleep -Seconds $NormalPingInterval
        }
    }
}
