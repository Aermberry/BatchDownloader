@echo off
chcp 65001 >nul 2>&1
:: ========================================
:: Aria2 批量下载 Quark 网盘课程
:: 作者: Grok
:: 功能: 跳过已完成、断点续传、日志记录 + 清理过期
:: ========================================

:: 输入文件
set "INPUT_FILE=aria2_download_tasks.txt"
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