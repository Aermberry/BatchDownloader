# setup_quark_downloader.ps1
# 自动化部署 Quark 网盘批量下载器
# 作者: Grok | 功能: 一键构建完整环境

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = $PWD.Path }

# ============ 定义文件内容 ============

$mainPs1 = @'
# QuarkDownloader.ps1
# 主调用程序：整合 aria2_task_manager.ps1 + runer.bat

$ErrorActionPreference = "Stop"
$AddScript   = "aria2_task_manager.ps1"
$RunBat      = "runer.bat"
$TaskFile    = "quark_downloads.txt"

function Show-Menu {
    Clear-Host
    Write-Host "`n"
    Write-Host " =========================================" -ForegroundColor Cyan
    Write-Host "     Quark 网盘批量下载器 - 主控台" -ForegroundColor Cyan
    Write-Host " =========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [1] 添加下载任务（粘贴 aria2c 命令）" -ForegroundColor White
    Write-Host " [2] 开始批量下载" -ForegroundColor White
    Write-Host " [3] 查看当前任务列表" -ForegroundColor White
    Write-Host " [4] 退出" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host " 请选择操作 (1-4)"
    return $choice
}

while ($true) {
    $opt = Show-Menu

    switch ($opt) {
        "1" {
           Clear-Host
    Write-Host "`n 正在启动任务追加工具...`n" -ForegroundColor Yellow

    try {
        # 优先尝试直接用 pwsh（PowerShell 7+）
        $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
        if ($pwsh) {
            & $pwsh -NoProfile -File "$AddScript"
        } else {
            # 降级：用 -EncodedCommand（兼容 PowerShell 5.1）
            $scriptContent = Get-Content "$AddScript" -Raw -Encoding UTF8
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptContent))
            powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded
        }
    } catch {
        Write-Host "启动失败: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "`n 按任意键返回主菜单..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }

        "2" {
            Clear-Host
            if (-not (Test-Path $TaskFile) -or (Get-Content $TaskFile -Raw).Trim() -eq "") {
                Write-Host "任务文件为空或不存在: $TaskFile" -ForegroundColor Red
                Write-Host "请先添加下载任务。" -ForegroundColor Yellow
            } else {
                Write-Host "正在启动 Aria2 批量下载...`n" -ForegroundColor Green
                & cmd /c $RunBat
            }
            Write-Host "`n 按任意键返回主菜单..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }

        "3" {
            Clear-Host
            Write-Host "`n============== 当前任务列表 ==============`n" -ForegroundColor Cyan
            if (Test-Path $TaskFile) {
                Get-Content $TaskFile | ForEach-Object { Write-Host $_ }
            } else {
                Write-Host "[空] 暂无任务" -ForegroundColor Gray
            }
            Write-Host "`n==========================================`n" -ForegroundColor Cyan
            Write-Host " 按任意键返回主菜单..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }

        "4" {
            Write-Host "`n感谢使用，再见！`n" -ForegroundColor Green
            Start-Sleep -Milliseconds 800
            exit
        }

        default {
            Write-Host "输入无效，请重新选择。" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
'@

$runerBat = @'
@echo off
chcp 65001 >nul 2>&1
:: ========================================
:: Aria2 批量下载 Quark 网盘课程
:: 作者: Grok
:: 功能: 跳过已完成、断点续传、日志记录 + 清理过期
:: ========================================

:: 输入文件
set "INPUT_FILE=quark_downloads.txt"
set "MAX_JOBS=5"
set "SPLIT=16"
set "CONN_PER_SERVER=8"

:: 日志
if not exist "logs" mkdir "logs"
set "LOG_FILE=logs\aria2_quark.log"

:: 执行下载
aria2c ^
  -i "%INPUT_FILE%" ^
  -j %MAX_JOBS% ^
  --max-concurrent-downloads=%MAX_JOBS% ^
  -x %SPLIT% -s %SPLIT% ^
  --max-connection-per-server=%CONN_PER_SERVER% ^
  --optimize-concurrent-downloads=true ^
  --continue=true ^
  --allow-overwrite=false ^
  --auto-file-renaming=false ^
  --dir="%~dp0downloads" ^
  --summary-interval=3 ^
  --check-integrity=true ^
  --console-log-level=warn ^
  --log-level=info ^
  --log="%LOG_FILE%" ^
  --file-allocation=none ^
  --retry-wait=5 ^
  --max-tries=10

echo.
echo ========================================
echo     下载任务已完成！
echo     文件保存在: %~dp0downloads
echo     查看日志: %LOG_FILE%
echo ========================================
echo.
pause
'@

$addQuarkPs1 = @'
# aria2_task_manager.ps1 - Aria2 下载任务管理工具（支持批量粘贴）
# 作者: Grok | 功能: 防粘连 + 防重 + 自动解码 + 自动修复 + 清理过期 + 无 BOM 写入

$ErrorActionPreference = "Stop"

# 自动定位脚本目录
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$inputFile = Join-Path $scriptDir "quark_downloads.txt"

# ============ 安全写入 UTF-8 无 BOM ============
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content, [switch]$Append)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    if ($Append -and (Test-Path $Path)) {
        $current = [System.IO.File]::ReadAllText($Path, $utf8NoBom)
        $Content = $current + $Content
    }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# ============ 1. 自动修复旧文件：确保每条任务后有空行 ============
function Repair-TaskSeparator {
    if (-not (Test-Path $inputFile)) {
        Write-Host "创建新文件: $inputFile" -ForegroundColor Cyan
        Write-Utf8NoBom -Path $inputFile -Content ""
        return
    }

    $content = Get-Content $inputFile -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($content)) { return }

    $lines = Get-Content $inputFile -Encoding UTF8
    $newLines = @()
    $inTask = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match "^https?://") {
            if ($inTask -and $newLines[-1] -ne "") {
                $newLines += ""  # 补空行
            }
            $inTask = $true
        }
        $newLines += $line
    }
    if ($inTask) { $newLines += "" }

    $newContent = $newLines -join "`r`n"
    if ($newContent -ne $content) {
        Write-Utf8NoBom -Path $inputFile -Content $newContent
        Write-Host "已修复任务分隔符（补空行）" -ForegroundColor Cyan
    }
}
Repair-TaskSeparator

# ============ 2. 清理过期链接 ============
function Clean-ExpiredUrls {
    if (-not (Test-Path $inputFile)) { return }

    $lines = Get-Content $inputFile -Encoding UTF8
    $newLines = @()
    $currentTask = @()
    $inTask = $false
    $now = [int64](Get-Date -UFormat %s)

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match "^https?://") {
            if ($inTask -and $currentTask.Count -gt 0) {
                if (-not (Is-UrlExpired $currentTask[0] $now)) {
                    $newLines += $currentTask
                    $newLines += ""
                }
            }
            $currentTask = @($line)
            $inTask = $true
        } elseif ($trimmed -ne "") {
            $currentTask += $line
        } else {
            if ($inTask) { $currentTask += $line }
        }
    }
    if ($inTask -and $currentTask.Count -gt 0 -and -not (Is-UrlExpired $currentTask[0] $now)) {
        $newLines += $currentTask
        $newLines += ""
    }

    $newContent = $newLines -join "`r`n"
    $oldContent = Get-Content $inputFile -Raw -Encoding UTF8
    if ($newContent -ne $oldContent) {
        Write-Utf8NoBom -Path $inputFile -Content $newContent
        Write-Host "已清理过期任务" -ForegroundColor Yellow
    }
}
function Is-UrlExpired($url, $now) {
    if ($url -match "Expires=(\d+)") {
        $expire = [int64]$matches[1]
        return $now -gt $expire
    }
    return $false
}
Clean-ExpiredUrls

# ============ 3. 读取用户输入（支持批量粘贴） ============
Write-Host "`n请粘贴 aria2c 命令（支持多条，每条一行，粘贴完按 Enter 两次）:`n" -ForegroundColor White

$lines = @()
do {
    $line = Read-Host
    if ($line.Trim() -ne "") {
        $lines += $line.TrimEnd()
    }
} while ($line -ne "")

if ($lines.Count -eq 0) {
    Write-Host "未输入任何命令，退出。" -ForegroundColor Red
    Read-Host "按 Enter 键退出"
    exit
}

# ============ 4. 批量解析 & 追加 ============
Add-Type -AssemblyName System.Web

$successCount = 0
$skipCount    = 0
$failCount    = 0

foreach ($cmd in $lines) {
    # 跳过非 aria2c 开头的行
    if ($cmd -notmatch '^aria2c\s+["'']') {
        Write-Host "跳过无效行: $cmd" -ForegroundColor Gray
        $failCount++
        continue
    }

    try {
        # 提取 URL
        if ($cmd -notmatch 'aria2c\s+["'']([^''"]+)["'']') {
            throw "无法提取 URL"
        }
        $url = $matches[1]

        # 提取文件名
        if ($cmd -match '--out\s+["'']([^''"]+)["'']') {
            $out = [System.Web.HttpUtility]::UrlDecode($matches[1])
        } else {
            $out = "unknown_$(Get-Random).mp4"
            Write-Warning "未指定 --out，使用随机文件名: $out"
        }

        # 提取所有 header
        $headers = @()
        $headerMatches = [regex]::Matches($cmd, '--header\s+["'']([^''"]+)["'']')
        foreach ($m in $headerMatches) {
            $headers += "  header=" + $m.Groups[1].Value
        }

        # 防重：检查 URL 是否已存在
        if ((Test-Path $inputFile)) {
            $existing = Get-Content $inputFile -Raw -Encoding UTF8
            if ($existing -match [regex]::Escape($url)) {
                Write-Host "已存在，跳过: $out" -ForegroundColor DarkGray
                $skipCount++
                continue
            }
        }

        # 写入单条任务
        $content = @"
$url
  dir=downloads
  out=$out
$($headers -join "`n")

"@
        Write-Utf8NoBom -Path $inputFile -Content $content -Append
        Write-Host "追加成功: $out" -ForegroundColor Green
        $successCount++

    } catch {
        Write-Host "解析失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   问题命令: $cmd" -ForegroundColor DarkGray
        $failCount++
    }
}

# ============ 5. 批量处理总结 ============
Write-Host "`n批量处理完成！" -ForegroundColor Cyan
Write-Host "   成功追加: $successCount 条" -ForegroundColor Green
if ($skipCount -gt 0) { Write-Host "   已跳过: $skipCount 条（重复）" -ForegroundColor Yellow }
if ($failCount -gt 0) { Write-Host "   解析失败: $failCount 条" -ForegroundColor Red }

Write-Host "`n文件路径: $inputFile" -ForegroundColor DarkGray
Write-Host "编码: UTF-8 (无 BOM)" -ForegroundColor DarkGray

Read-Host "`n按 Enter 键退出"
'@

# ============ 安全写入 UTF-8 无 BOM 函数 ============
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# ============ 开始构建 ============
Write-Host "`n正在部署 Quark 网盘批量下载器..." -ForegroundColor Cyan

$files = @(
    @{Path="main.ps1";     Content=$mainPs1}
    @{Path="runer.bat";    Content=$runerBat}
    @{Path="aria2_task_manager.ps1";Content=$addQuarkPs1}
)

foreach ($file in $files) {
    $fullPath = Join-Path $scriptDir $file.Path
    if (Test-Path $fullPath) {
        Write-Host "更新: $($file.Path)" -ForegroundColor Yellow
    } else {
        Write-Host "创建: $($file.Path)" -ForegroundColor Green
    }
    Write-Utf8NoBom -Path $fullPath -Content $file.Content
}

# 创建目录
@("downloads", "logs") | ForEach-Object {
    $dir = Join-Path $scriptDir $_
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "创建文件夹: $_" -ForegroundColor Green
    }
}

# 创建空任务文件
$taskFile = Join-Path $scriptDir "quark_downloads.txt"
if (-not (Test-Path $taskFile)) {
    Write-Utf8NoBom -Path $taskFile -Content ""
    Write-Host "创建任务文件: quark_downloads.txt" -ForegroundColor Green
}

# ============ 完成提示 ============
Write-Host "`n部署完成！" -ForegroundColor Cyan
Write-Host "目录结构:" -ForegroundColor White
Get-ChildItem $scriptDir | Where-Object { $_.Name -match '^(main\.ps1|runer\.bat|add_quark\.ps1|downloads|logs|quark_downloads\.txt)$' } | ForEach-Object {
    if ($_.PSIsContainer) {
        Write-Host "   [$($_.Name)]" -ForegroundColor DarkCyan
    } else {
        Write-Host "   $($_.Name)" -ForegroundColor Gray
    }
}

Write-Host "`n使用方法：" -ForegroundColor Yellow
Write-Host "   1. 双击 main.ps1 启动主程序"
Write-Host "   2. 选择 [1] 添加任务 → 粘贴 aria2c 命令"
Write-Host "   3. 选择 [2] 开始下载（需安装 aria2c）"
Write-Host "`n温馨提示：请确保已安装 aria2c 并加入 PATH" -ForegroundColor Magenta

Read-Host "`n按 Enter 键退出"