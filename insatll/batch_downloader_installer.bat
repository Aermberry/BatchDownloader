@echo off
chcp 65001 >nul
echo.
echo ========================================
echo    aria2批处理脚本 网盘下载器 - 一键部署
echo ========================================
echo.

:: 1. 设置执行策略（仅当前用户）
powershell -Command "if ((Get-ExecutionPolicy) -eq 'Restricted') { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force }"

:: 2. 下载并执行脚本
powershell -Command "IEX (Invoke-WebRequest -Uri 'https://github.com/Aermberry/BatchDownloader/raw/refs/heads/main/insatll/aria2_project_builder.ps1' -UseBasicParsing).Content"

echo.
echo 部署完成！正在启动主程序...
timeout /t 2 >nul
powershell -File "main.ps1"