#Requires -RunAsAdministrator

<#
.SYNOPSIS
    智能网络监控脚本 - 系统卸载脚本

.DESCRIPTION
    完全卸载系统级部署的智能网络监控脚本
#>

$ProgramPath = "C:\Program Files\SmartNetworkMonitor"
$DataPath = "C:\ProgramData\SmartNetworkMonitor"

Write-Host "==========================================" -ForegroundColor Red
Write-Host "智能网络监控脚本 - 系统卸载" -ForegroundColor Red
Write-Host "==========================================" -ForegroundColor Red
Write-Host ""

Write-Host "将要删除:" -ForegroundColor Yellow
Write-Host "- 程序目录: $ProgramPath" -ForegroundColor White
Write-Host "- 数据目录: $DataPath (包含日志文件)" -ForegroundColor White
Write-Host "- 任务计划程序条目" -ForegroundColor White
Write-Host "- 事件日志源" -ForegroundColor White
Write-Host ""

$confirmation = Read-Host "确定要继续吗？这将删除所有相关文件和配置 (y/N)"

if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "卸载已取消" -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "正在卸载..." -ForegroundColor Yellow

# 停止并删除任务计划程序
try {
    $task = Get-ScheduledTask -TaskName "Smart Network Shutdown Monitor" -ErrorAction SilentlyContinue
    if ($task) {
        Stop-ScheduledTask -TaskName "Smart Network Shutdown Monitor" -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName "Smart Network Shutdown Monitor" -Confirm:$false
        Write-Host "[OK] 任务计划程序已删除" -ForegroundColor Green
    }
}
catch {
    Write-Host "[X] 删除任务计划程序失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 删除事件日志源
try {
    if ([System.Diagnostics.EventLog]::SourceExists("SmartNetworkMonitor")) {
        [System.Diagnostics.EventLog]::DeleteEventSource("SmartNetworkMonitor")
        Write-Host "[OK] 事件日志源已删除" -ForegroundColor Green
    }
}
catch {
    Write-Host "[X] 删除事件日志源失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 删除程序目录
try {
    if (Test-Path $ProgramPath) {
        Remove-Item -Path $ProgramPath -Recurse -Force
        Write-Host "[OK] 程序目录已删除: $ProgramPath" -ForegroundColor Green
    }
}
catch {
    Write-Host "[X] 删除程序目录失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 询问是否删除数据目录（包含日志）
Write-Host ""
$deleteData = Read-Host "是否同时删除数据目录和所有日志文件？(y/N)"

if ($deleteData -eq 'y' -or $deleteData -eq 'Y') {
    try {
        if (Test-Path $DataPath) {
            Remove-Item -Path $DataPath -Recurse -Force
            Write-Host "[OK] 数据目录已删除: $DataPath" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[X] 删除数据目录失败: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[INFO] 数据目录保留: $DataPath" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "[OK] 卸载完成！" -ForegroundColor Green
Read-Host "按任意键退出"
