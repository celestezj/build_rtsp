@echo off
setlocal EnableDelayedExpansion

REM ---------------------------------------------------------------------
REM  Stop ONLY the WebRTC static player server (node serve.js on port 8080).
REM  Finds the PID listening on 8080 and kills it. Other node apps are
REM  left untouched.
REM ---------------------------------------------------------------------

set "FOUND="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /r /c:"^ *TCP *0\.0\.0\.0:8080.*LISTENING"') do (
  set "FOUND=1"
  echo Stopping PID %%P listening on port 8080 ...
  taskkill /F /PID %%P >nul 2>&1
)

if not defined FOUND (
  echo Port 8080 is not in use. Nothing to stop.
)
echo.
echo Done.
pause