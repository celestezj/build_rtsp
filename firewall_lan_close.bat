@echo off
setlocal EnableDelayedExpansion

REM =====================================================================
REM  SAFELY close (delete) ONLY the LAN-scoped camera rules created by
REM  firewall_lan_open.bat. Deletes by exact rule name, so it never touches
REM  other rules on the same ports. Nothing else is modified.
REM =====================================================================

REM --- Auto-elevate to Administrator ---
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Requesting administrator privileges...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

echo Deleting LAN-scoped camera firewall rules...
echo.

netsh advfirewall firewall delete rule name="LAN-RTSP-8554"
netsh advfirewall firewall delete rule name="LAN-SRT-8890"
netsh advfirewall firewall delete rule name="LAN-WebRTC-SIG-8889"
netsh advfirewall firewall delete rule name="LAN-WebRTC-MEDIA-8189"
netsh advfirewall firewall delete rule name="LAN-WEB-8080"

echo.
echo Done. Rules removed (delete of an absent rule prints a harmless
echo "No rules match" message and continues).
pause