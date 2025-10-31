# aria2_task_manager.ps1 - Aria2 下载任务管理工具（支持批量粘贴）
# author: Alerm | 功能: 防粘连 + 防重 + 自动解码 + 自动修复 + 清理过期 + 无 BOM 写入

$ErrorActionPreference = "Stop"

# 自动定位脚本目录
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$inputFile = Join-Path $scriptDir "aria2_download_tasks.txt"

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