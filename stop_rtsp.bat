@echo off
echo Stopping MediaMTX server...
taskkill /IM mediamtx.exe /F
taskkill /IM ffmpeg.exe /F
echo Stopped.
pause