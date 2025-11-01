# BatchDownloader (Aria2 Project Builder & Batch Downloader)

[中文文档](README.md) | English

**Introduction**
- A batch download tool based on Aria2, providing task management, resume capability, and logging functionality.
- Core components: `main.ps1` (Main Console), `aria2_task_manager.ps1` (Task Manager), `aria2_downloader.bat` (Batch Downloader), `aria2_download_tasks.txt` (Task File).
- Optional components: `install/aria2_project_builder.ps1` (Project Builder), `install/batch_downloader_installer.bat` (One-click Installer).

**Directory Structure**
```
.
├── main.ps1                      # Main console (menu operations)
├── aria2_task_manager.ps1        # Task manager (batch parsing, duplicate prevention, expired link cleanup)
├── aria2_downloader.bat          # Batch downloader (executes tasks using aria2c)
├── aria2_download_tasks.txt      # Task file (UTF-8 without BOM)
├── downloads/                    # Download directory (auto-created)
├── logs/                         # Log directory (auto-created)
└── install/
    ├── aria2_project_builder.ps1 # Project builder (one-click generation/update of core files)
    └── batch_downloader_installer.bat # One-click installation script
```

**Installation & Startup**
- Prerequisites:
  1. `aria2c` installed and added to system `PATH`
  2. [LinkSwift](https://github.com/hmjz100/LinkSwift) browser extension installed for generating aria2c commands

- One-click Installation (Recommended, using Release version): Execute the following command in PowerShell.
```powershell
iwr "https://github.com/Aermberry/BatchDownloader/releases/download/v1.0.0/batch_downloader_installer.bat" -OutFile "$env:TEMP\install.bat"; & "$env:TEMP\install.bat"
```

**Usage Instructions (Console)**

1. Run `main.ps1` to start the console.
2. First use LinkSwift browser extension to generate aria2c commands from your download links.
3. Select `[1] Add Download Tasks`, paste aria2c commands into the console (one command per line), press Enter when finished.
4. Select `[2] Start Batch Download` to invoke `aria2_downloader.bat` to execute tasks.
5. Select `[3] View Current Task List` to check the contents of `aria2_download_tasks.txt`.
6. Select `[4] Exit`.

**Example: aria2c Command**
```bash
aria2c "https://example.com/video.mp4" \
  --out "video.mp4" \
  --header "Referer: https://example.com" \
  --header "User-Agent: Mozilla/5.0"
```
- The task manager parses commands and writes them to `aria2_download_tasks.txt` (UTF-8 without BOM), automatically prevents duplicates, adds empty line separators, and cleans up expired links containing `Expires=`.

**Downloads & Logs**
- Download directory: `downloads/`
- Task file: `aria2_download_tasks.txt`
- Log file: `logs/aria2_quark.log`

**Troubleshooting**
- "aria2c not found" error: Verify it's installed and in the `PATH`.
- Empty task file: First execute menu option `[1] Add Download Tasks`.
- Download failure due to expired links: Regenerate links; the task manager will automatically clean up expired entries.
- Execution policy restriction: Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` in PowerShell.
- Cannot generate aria2c commands: Make sure the LinkSwift browser extension is installed from [GitHub repository](https://github.com/hmjz100/LinkSwift).

**Acknowledgments**
- Author: Alerm
- Thanks to Aria2 community.