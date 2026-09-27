@echo off
title WebRTC player server (port 8080)
echo Player page - open in another PC browser (change IP):
echo   http://<server-IP>:8080/player.html
echo   e.g. http://192.168.0.103:8080/player.html
echo Press Ctrl+C to stop
cd /d "%~dp0"
node serve.js
pause