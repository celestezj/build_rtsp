@echo off
title SRT low-latency playback
echo Opening SRT stream in VLC (change IP 192.168.0.103 in this file if needed)
start "SRT" "C:\Program Files\VideoLAN\VLC\vlc.exe" "srt://192.168.0.103:8890?mode=caller&streamid=read:live&latency=120000"