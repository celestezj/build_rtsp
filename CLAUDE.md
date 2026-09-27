# CLAUDE.md — 局域网摄像头推流项目

## 这是什么

把**一台 Windows 电脑的摄像头**变成一台局域网流媒体服务器：同一份 H.264 画面，同时以 **RTSP / SRT / WebRTC** 三种协议对外提供，供局域网内其他电脑/设备实时观看。

```
摄像头 ──①FFmpeg 采集+编码──► MediaMTX(服务器) ──②多协议广播──► 任意播放端
                               ├─ RTSP   :8554/live   ── ffplay / VLC
                               ├─ SRT    :8890         ── ffplay / MPV(VLC 不可用!)
                               └─ WebRTC :8889 (WHEP)  ── 浏览器(http://IP:8080/player.html)
```

- **FFmpeg**：采集摄像头 → H.264 编码 → 推流给服务器（只推一次）
- **MediaMTX**：接收后把同一份流以三种协议广播

完整文档看 **`README.md`**（含换机复现、端口安全、故障排查）。本文件是给新上手者/新对话的核心速查。

## 目录里有什么

| 文件 | 作用 |
|------|------|
| `mediamtx.exe` `mediamtx.yml` | RTSP 服务器主程序 + 配置（含摄像头自动推流命令） |
| `start_rtsp.bat` / `stop_rtsp.bat` | 启停**主服务**(mediamtx，会自动带出 ffmpeg) |
| `start_web_player.bat` / `stop_web_player.bat` | 启停 WebRTC 播放页静态服务(node serve.js, 8080) |
| `player.html` `serve.js` | WebRTC 浏览器播放页 + 极简静态服务器 |
| `firewall_lan_open.bat` / `firewall_lan_close.bat` | 一键放行/删除局域网网段防火墙规则 |
| `README.md` | 完整文档（本文件是速查，深挖看它） |

## 服务器进程架构（先懂这个再操作）

两个**独立**服务，按需启停：
- **主服务** = `mediamtx.exe`（8554/8890/8889…），启动时**自动再拉起** `ffmpeg.exe` 采集推流。**ffmpeg 无需手动启动。**
- **WebRTC 静态服务** = `node serve.js`（8080 播放页），**只有**要用浏览器 WebRTC 看时才需要。

## 端口一览

| 端口 | 协议 | 用途 |
|------|------|------|
| **8554** | TCP | RTSP 流（ffplay/VLC 拉流） |
| **8890** | UDP | SRT 流（跨公网才用） |
| **8889** + **8189** | TCP/UDP | WebRTC（8889 信令 WHEP + 8189 媒体） |
| **8080** | TCP | WebRTC 播放页（node serve.js） |
| 8000/8001/8892/8893 | … | RTSP UDP 媒体 / MoQ（一般不用） |

## 新用户怎么用（三步）

### 1. 启动服务器
```cmd
REM 先进入本项目的根目录(build_rtsp)，再运行脚本
cd /d "<本项目的绝对路径>\build_rtsp"
start_rtsp.bat
```
看日志 `[path live] stream is available and online` 即成功。要 WebRTC 浏览器看再加 `start_web_player.bat`。

### 2. 放行端口（其他电脑连不上，多半卡这）
以**管理员**运行 `firewall_lan_open.bat`（只放行局域网网段）。查看/删除规则用 `firewall_lan_close.bat` 或：
```cmd
netsh advfirewall firewall show rule name="LAN-RTSP-8554"
```

### 3. 适配局域网 IP（重要！几乎每次换环境都要做）
- **服务器本地 IP**（如 `192.168.0.103`）= **运行 `start_rtsp.bat` 那台电脑**自己的 IPv4，用 `ipconfig` 查。
- 文档/命令里所有 `192.168.0.103` / `<IP>` 都指它，其他电脑拉流时替换。
- **防火墙网段 `192.168.0.0/24` 和它是同源一体的**：一旦网段变了（比如到 `192.168.1.x`），必须**同步**：
  1. 跑 `firewall_lan_close.bat` 删旧规则
  2. 把 `firewall_lan_open.bat` 顶部 `set "SUBNET=192.168.0.0/24"` 改成 `192.168.1.0/24`
  3. 重新跑 `firewall_lan_open.bat`

## 各协议怎么播放（推荐命令）

**RTSP（局域网首选，低延迟）**：
```cmd
ffplay -fflags nobuffer -flags low_delay -probesize 32 -analyzeduration 0 -framedrop -rtsp_transport tcp -i "rtsp://192.168.0.103:8554/live"
```
**WebRTC（浏览器，零延迟）**：服务器 `start_web_player.bat` 后，他机浏览器开 `http://192.168.0.103:8080/player.html`
**SRT（仅跨公网）**：用 ffplay/MPV（见下方坑）。

## 关键坑（务必先看这几个，别踩）

1. **`-g 30`（关键帧间隔）在 `mediamtx.yml` 的 `runOnInit` 里**。改推流命令后**必须重启 mediamtx**（`stop_rtsp.bat` → `start_rtsp.bat`）才生效。
2. **所有 `.bat` 必须是纯 ASCII**，不能写中文——中文 Windows 的 cmd 把 UTF-8 中文按 GBK 解析，会乱码甚至报"不是内部或外部命令"。要加注释用英文。
3. **VLC 的 SRT 客户端是坏的**——实测一帧卡死/周期性卡顿。**不要用 VLC 测 SRT**，用 ffplay/MPV。
4. **WebRTC 播放页别用 `file://` 双击打开**（Origin 为 null 被 CORS 拦，"Failed to fetch"），要用 `http://服务器IP:8080/player.html`。
5. **推流是 H264 Baseline + yuv420p**（`-profile:v baseline -pix_fmt yuv420p`），浏览器解码器只吃这个，别改别的采样/等级。
6. **ffmpeg 自动被 mediamtx 拉起**，别单独手动开一个；也注意它的 `-rtbufsize 64M`（防 dshow 缓冲满丢帧）别去掉。

## 排查速查

- 他机连不上：同局域网？`ping` 通？防火墙放行了对应端口？服务器进程活着（`tasklist | findstr mediamtx`）？
- 换 IP 后连不上：优先怀疑**第 3 步的 IP/网段没适配**。
- WebRTC "Failed to fetch"：别用 file://，用 http 打开播放页。
- 卡顿/丢帧：1080p 吃 CPU，推流命令里可加 `-vf scale=1280:720` 降 720p。