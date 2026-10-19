@echo off
chcp 65001 >nul
setlocal
set "bootstrap=%~dp0app\scripts\Manage.ps1"
if not exist "%bootstrap%" set "bootstrap=%~dp0scripts\Manage.ps1"
if not exist "%bootstrap%" goto missing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%bootstrap%" -Action Enable
set "result=%errorlevel%"
echo.
if not "%result%"=="0" echo 启用未完成，请保留此目录和原始备份，并查看上方提示。
pause
exit /b %result%
:missing
echo 发布包不完整，请先完整解压，再运行“启用主题”。
pause
exit /b 1
