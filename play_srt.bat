@echo off
title SRT 低延迟播放
echo 正在通过 SRT (低延迟) 打开摄像头流...
echo 若服务器 IP 变了，请修改本文件里的 192.168.0.103
start "SRT低延迟播放" "C:\Program Files\VideoLAN\VLC\vlc.exe" "srt://192.168.0.103:8890?mode=caller&streamid=read:live&latency=120000"