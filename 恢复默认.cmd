@echo off
chcp 65001 >nul
setlocal
set "bootstrap=%~dp0app\scripts\Manage.ps1"
if not exist "%bootstrap%" set "bootstrap=%~dp0scripts\Manage.ps1"
if not exist "%bootstrap%" goto missing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%bootstrap%" -Action Restore
set "result=%errorlevel%"
echo.
if not "%result%"=="0" echo 恢复需要进一步处理，原始备份已保留，请查看上方提示。
pause
exit /b %result%
:missing
echo 发布包不完整，请先完整解压，再运行“恢复默认”。
pause
exit /b 1
