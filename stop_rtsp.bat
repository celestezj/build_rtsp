@echo off
echo 停止 MediaMTX 进程...
taskkill /IM mediamtx.exe /F
taskkill /IM ffmpeg.exe /F
echo 已停止。
pause