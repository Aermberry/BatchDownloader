@echo off
chcp 65001 >nul
echo.
echo ========================================
echo    aria2批处理脚本 网盘下载器 - 一键部署
echo ========================================
echo.

:: 优先使用 PowerShell 7 (pwsh)，彻底避开 profile.ps1
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    set "PS=pwsh"
    set "PS_ARGS=-NoProfile"
) else (
    set "PS=powershell"
    set "PS_ARGS=-NoProfile -ExecutionPolicy Bypass"
)

:: 设置执行策略（仅在需要时）
%PS% %PS_ARGS% -Command "if ((Get-ExecutionPolicy) -eq 'Restricted') { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force }"

:: 下载并执行脚本
%PS% %PS_ARGS% -Command "IEX (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Aermberry/BatchDownloader/refs/heads/main/install/aria2_project_builder.ps1' -UseBasicParsing).Content"

echo.
echo 部署完成！正在启动主程序...
timeout /t 2 >nul
%PS% %PS_ARGS% -File "main.ps1"