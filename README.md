# BatchDownloader（Aria2 项目构建器与批量下载器）

中文 | [English](README_EN.md)

**简介**
- 基于 Aria2 的批量下载工具，提供任务管理、断点续传、日志记录等能力。
- 核心组件：`main.ps1`（主控台）、`aria2_task_manager.ps1`（任务管理）、`aria2_downloader.bat`（批量下载）、`aria2_download_tasks.txt`（任务文件）。
- 可选组件：`install/aria2_project_builder.ps1`（项目构建器）、`install/batch_downloader_installer.bat`（一键安装）。

**目录结构**
```
.
├── main.ps1                      # 主控台（菜单操作）
├── aria2_task_manager.ps1        # 任务管理器（批量粘贴解析、防重、清理过期）
├── aria2_downloader.bat          # 批量下载（调用 aria2c 执行任务）
├── aria2_download_tasks.txt      # 任务文件（UTF-8 无 BOM）
├── downloads/                    # 下载文件目录（自动创建）
├── logs/                         # 日志目录（自动创建）
└── install/
    ├── aria2_project_builder.ps1 # 项目构建器（一键生成/更新核心文件）
    └── batch_downloader_installer.bat # 一键安装启动脚本
```

**安装与启动**
- 前置条件：
  - 已安装 `aria2c` 并加入系统 `PATH`。
  - 浏览器已安装插件 `LinkSwift`（用于从网盘页面获取直链或生成 `aria2c` 命令）：`https://github.com/hmjz100/LinkSwift`。
- 一键安装（推荐，使用 Release 版本）：在 PowerShell 中执行下列命令。
```powershell
iwr "https://github.com/Aermberry/BatchDownloader/releases/download/v1.0.0/batch_downloader_installer.bat" -OutFile "$env:TEMP\install.bat"; & "$env:TEMP\install.bat"
```


**使用方法（主控台）**

1. 运行 `main.ps1` 启动主控台。
2. 在浏览器中通过 `LinkSwift` 获取直链或生成 `aria2c` 命令。
3. 选择 `[1] 添加下载任务`，将一行一条的 `aria2c` 命令粘贴到控制台，回车结束。
4. 选择 `[2] 开始批量下载`，调用 `aria2_downloader.bat` 执行任务。
5. 选择 `[3] 查看当前任务列表`，检查 `aria2_download_tasks.txt` 内容。
6. 选择 `[4] 退出`。

**示例：aria2c 命令**
```bash
aria2c "https://example.com/video.mp4" \
  --out "video.mp4" \
  --header "Referer: https://example.com" \
  --header "User-Agent: Mozilla/5.0"
```
- 任务管理器会解析命令并写入 `aria2_download_tasks.txt`（UTF-8 无 BOM），自动防重、补空行分隔，并清理含 `Expires=` 的过期链接。

**下载与日志**
- 下载目录：`downloads/`
- 任务文件：`aria2_download_tasks.txt`
- 日志文件：`logs/aria2_quark.log`

**故障排除**
- 提示未找到 `aria2c`：确认已安装并在 `PATH` 中。
- 浏览器未安装 LinkSwift：前往 `https://github.com/hmjz100/LinkSwift` 安装后重试在网盘页面获取直链或生成命令。
- 任务文件为空：先执行菜单 `[1] 添加下载任务`。
- 链接过期导致下载失败：重新生成链接；任务管理器会自动清理过期条目。
- 执行策略受限：在 PowerShell 执行 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`。