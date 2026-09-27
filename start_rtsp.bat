@echo off
title MediaMTX RTSP 服务器
echo ============================================
echo  RTSP 服务器启动中...
echo  局域网内其他电脑请访问:
echo   rtsp://本机局域网IP:8554/live
echo  本机测试: rtsp://localhost:8554/live
echo  按 Ctrl+C 停止服务器
echo ============================================
cd /d "%~dp0"
mediamtx.exe
pause