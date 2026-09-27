@echo off
setlocal EnableDelayedExpansion

REM =====================================================================
REM  Open inbound firewall rules for the camera stream, LOCKED TO YOUR LAN.
REM  Edit SUBNET below if your LAN differs (ipconfig -> IPv4, first 3 octets
REM  + .0/24). Example: 192.168.1.104 -> 192.168.1.0/24
REM =====================================================================
set "SUBNET=192.168.0.0/24"

REM --- Auto-elevate to Administrator ---
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Requesting administrator privileges...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

echo Opening firewall for subnet %SUBNET% ...
echo.

netsh advfirewall firewall add rule name="LAN-RTSP-8554"       dir=in action=allow protocol=TCP localport=8554 remoteip=%SUBNET% enable=yes
netsh advfirewall firewall add rule name="LAN-SRT-8890"        dir=in action=allow protocol=UDP localport=8890 remoteip=%SUBNET% enable=yes
netsh advfirewall firewall add rule name="LAN-WebRTC-SIG-8889" dir=in action=allow protocol=TCP localport=8889 remoteip=%SUBNET% enable=yes
netsh advfirewall firewall add rule name="LAN-WebRTC-MEDIA-8189" dir=in action=allow protocol=UDP localport=8189 remoteip=%SUBNET% enable=yes
netsh advfirewall firewall add rule name="LAN-WEB-8080"        dir=in action=allow protocol=TCP localport=8080 remoteip=%SUBNET% enable=yes

echo.
echo Done. Rules opened for subnet %SUBNET%.
echo To undo later, run firewall_lan_close.bat
pause