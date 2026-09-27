@echo off
title WebRTC 播放器静态服务 (端口 8080)
echo 播放器地址(另台电脑浏览器打开，把IP换成服务器IP):
echo   http://<服务器IP>:8080/player.html
echo 例如:
echo   http://192.168.0.103:8080/player.html
echo 按 Ctrl+C 停止
cd /d "%~dp0"
node serve.js
pause