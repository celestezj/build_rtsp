@echo off
title SRT low-latency playback

REM Usage: play_srt.bat [server-IP]   e.g.  play_srt.bat 192.168.1.50
REM If no IP given, falls back to the default below.
set "SRVIP=%~1"
if "%SRVIP%"=="" set "SRVIP=192.168.0.103"

echo Opening SRT stream from %SRVIP% in VLC...
start "SRT" "C:\Program Files\VideoLAN\VLC\vlc.exe" "srt://%SRVIP%:8890?mode=caller&streamid=read:live&latency=120000"