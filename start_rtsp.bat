@echo off
title MediaMTX RTSP Server
echo ============================================
echo  RTSP server starting...
echo  LAN clients connect to:
echo    rtsp://<this-PC-IP>:8554/live
echo  Local test: rtsp://localhost:8554/live
echo  Press Ctrl+C to stop
echo ============================================
cd /d "%~dp0"
mediamtx.exe
pause