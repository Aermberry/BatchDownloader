# main.ps1
# 主调用程序：整合 aria2_task_manager.ps1 + aria2_downloader.bat
# 功能：提供用户交互界面，管理下载任务并触发批量下载

$ErrorActionPreference = "Stop"
$AddScript   = "aria2_task_manager.ps1"
$RunBat      = "aria2_downloader.bat"
$TaskFile    = "aria2_download_tasks.txt"

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