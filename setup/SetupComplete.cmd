@echo off
rem LiteWin: runs once as SYSTEM at the end of Windows Setup (before first logon).
if not exist "%ProgramData%\LiteWin\logs" mkdir "%ProgramData%\LiteWin\logs"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WINDIR%\Setup\Scripts\PostInstall.ps1" >> "%ProgramData%\LiteWin\logs\SetupComplete.log" 2>&1
exit /b 0
