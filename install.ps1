# Smart Network Shutdown Monitor - Windows Installer
# Usage: irm https://raw.githubusercontent.com/UnbalancedCat/smart-shutdown/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

# Check admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[FAIL] 此安装脚本必须以管理员身份运行。请右键 PowerShell 选择「以管理员身份运行」后重试。" -ForegroundColor Red
    exit 1
}

$arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
$fileName = "smart-shutdown_windows_${arch}.exe"
$downloadUrl = "https://github.com/UnbalancedCat/smart-shutdown/releases/latest/download/$fileName"
$tempPath = Join-Path $env:TEMP "smart-shutdown.exe"

Write-Host "正在下载最新版本: $fileName ..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -UseBasicParsing

Write-Host "正在执行安装与服务注册..." -ForegroundColor Cyan
& $tempPath install

Write-Host "正在启动后台服务..." -ForegroundColor Cyan
smart-shutdown start

Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
Write-Host "安装完成。此后可在管理员终端中直接使用 smart-shutdown 命令。" -ForegroundColor Green
