# 局域网 RTSP 摄像头推流服务器

把本机电脑的**摄像头**变成标准 **RTSP 流**，供同一局域网内其他电脑/设备实时拉流观看。

## 架构原理

```
摄像头 ──①采集+编码────► MediaMTX(服务器) ──②多协议广播──► 任意拉流端
        FFmpeg(dshow)      同一份流,对外同时开放：       VLC / ffplay / 浏览器
                          ├─ RTSP   :8554/live
                          ├─ SRT    :8890 (streamid=read:live)
                          └─ WebRTC :8889 (WHEP)
```

- **FFmpeg**：采集摄像头 → H.264 编码 → 推流给服务器（只推一次）
- **媒体服务器 (MediaMTX)**：接收后，把**同一份流**同时以 RTSP / SRT / WebRTC 三种协议对外广播，谁想用哪种连哪种

职责分离的好处：服务器只看一种流格式，换采集源（摄像头/屏幕/文件）无需改服务器；客户端多协议按需选择。

---

## 一、已就绪环境（当前这台机器）

| 项目 | 值 |
|------|------|
| 摄像头设备名 | `Integrated Camera`（1920×1080 @30fps） |
| RTSP 服务 | MediaMTX v1.21.1，端口 **8554** |
| 流路径 | `/live` |
| 本机局域网 IP（示例） | `192.168.0.103`（重启后可能变，运行时以 `ipconfig` 为准） |
| 推流地址 | `rtsp://localhost:8554/live` |
| 远程拉流地址 | `rtsp://192.168.0.103:8554/live` |

### 目录结构

```
build_rtsp/
├── mediamtx.exe       # RTSP 服务器主程序
├── mediamtx.yml       # 服务器配置（含摄像头自动推流）
├── start_rtsp.bat     # 一键启动服务器
├── stop_rtsp.bat      # 一键停止
├── start_web_player.bat # 启动 node 静态服务(8080)，提供 player.html
├── serve.js           # 极简静态文件服务器(零依赖)
├── player.html        # WebRTC 浏览器播放器(经 http://IP:8080/player.html 访问)
├── play_srt.bat       # SRT 低延迟播放（另台电脑的 VLC 用）
├── LICENSE
└── .gitignore
```

### 日常使用

**启动**：双击 `start_rtsp.bat`，或命令行 `mediamtx.exe`。
启动后自动拉起 FFmpeg 推流；出现日志 `[path live] stream is available and online` 即为成功。

**停止**：双击 `stop_rtsp.bat`（结束 mediamtx 与 ffmpeg 进程）。

**本机自测**（无需 VLC）：
```cmd
ffplay rtsp://localhost:8554/live
```

**其他电脑拉流**：VLC → 媒体 → 打开网络串流，输入
```
rtsp://192.168.0.103:8554/live
```

---

## 二、换新设备复现步骤

以下为在**另一台/新电脑**上从零搭建的完整步骤。

### 1. 安装 FFmpeg（负责采集+编码）

1. 下载 Windows 版：[gyan.dev 官方构建](https://www.gyan.dev/ffmpeg/builds/) 的 `ffmpeg-release-full.zip`（或 [GitHub Releases](https://github.com/BtbN/FFmpeg-Builds/releases)）。
2. 解压到任意目录（如 `C:\ffmpeg`）。
3. 把 `C:\ffmpeg\bin` 加入系统环境变量 `Path`：
   - 设置 → 系统 → 关于 → 高级系统设置 → 环境变量
   - 编辑 `Path` → 新建 → 填入 `C:\ffmpeg\bin` → 确定
   - **重开**命令提示符后验证：`ffmpeg -version` 能看到版本即成功。

### 2. 下载 MediaMTX（RTSP 服务器）

1. 到 [bluenviron/mediamtx Releases](https://github.com/bluenviron/mediamtx/releases) 下载**最新**版本：
   `mediamtx_<版本>_windows_amd64.zip`
2. 解压到一个专用目录（本仓库建议放在本项目目录下）。
3. 该 zip 内含 `mediamtx.exe` 和默认 `mediamtx.yml`，无需安装，双击即可用。

### 3. 检测本机摄像头设备名

打开命令提示符，运行：
```cmd
ffmpeg -list_devices true -f dshow -i dummy
```
在输出里找到 `(video)` 那行，例如 `"Integrated Camera"`、`"USB2.0 HD UVC WebCam"`。
**记下这个名字**（含引号内的完整名称），下一步要用。

> 摄像头名称里通常带空格；不同的摄像头名称不一样，这步不能跳过。

### 4. 修改 `mediamtx.yml`，填入你的摄像头名

用编辑器打开 `mediamtx.yml`，找到 `paths:` 段的 `live` 条目，把 `video="..."` 里的名字**替换成你自己的摄像头名**：

```yaml
paths:
  live:
    runOnInit: ffmpeg -f dshow -rtbufsize 64M -i video="你的摄像头名" -c:v libx264 -preset ultrafast -tune zerolatency -f rtsp rtsp://localhost:8554/live
    runOnInitRestart: yes
```

参数说明：
- `-f dshow`：Windows 采集方式
- `-rtbufsize 64M`：加大输入缓冲，避免 1080p 下实时缓冲满丢帧
- `-c:v libx264`：H.264 编码（兼容性最好）
- `-preset ultrafast -tune zerolatency`：实时低延迟编码
- `rtsp://localhost:8554/live`：推流目标；`live` 是访问路径，可自定义

> **Mac / Linux 用户**：Windows dshow 命令不适用。
> - Mac：把 `-f dshow -i video="..."` 换成 `-f avfoundation -i "0"`（索引用 `ffmpeg -f avfoundation -list_devices true -i ""` 查）
> - Linux：换成 `-f v4l2 -i /dev/video0`

### 5. 放行防火墙端口（关键，其他电脑连不上多半卡这）

1. 控制面板 → Windows Defender 防火墙 → 高级设置
2. 入站规则 → 新建规则 → **端口** → **TCP** → 本地端口填 **`8554`**
3. 选 **允许连接** → 配置文件勾选**专用(Private)** → 完成

### 6. 启动服务器

```cmd
cd /d 解压目录
mediamtx.exe
```
看到 `[RTSP] listener opened on :8554` 和 `[path live] stream is available and online` 即为成功。

> **关于证书 auto.crt / auto.key（无需你处理）**：
> - MediaMTX 首次运行会自动生成一对**自签名 TLS 证书**，用于它的加密传输协议（如 MoQ，以及未开启的 HTTPS / `rtsps://`）。
> - 本项目用的是**明文 RTSP**（`rtsp://`，`rtspEncryption: "no"`），**摄像头推流不依赖证书**。
> - `auto.key` 是**私钥**，须保密，已在 `.gitignore` 中排除，不入库。
> - **换新设备无需手动拷贝**：检测到证书缺失时会自动重新生成。

### 7. 获取本机局域网 IP

```cmd
ipconfig
```
找到"IPv4 地址"（通常是 `192.168.0.x` 或 `192.168.1.x`）。

### 8. 在其他电脑验证拉流

确保拉流电脑与服务器**同一局域网**（同一路由器/Wi-Fi）。VLC → 打开网络串流：
```
rtsp://<服务器IP>:8554/live
```
能出画面即打通。

---

## 三、多种拉流方式（RTSP / SRT / WebRTC）

一台服务器同时开启三种协议，按需选择：

| 协议 | 地址 | 播放方式 | 延迟 |
|------|------|----------|------|
| **RTSP** | `rtsp://<IP>:8554/live` | VLC | 高（需调 VLC 缓存） |
| **SRT** | `srt://<IP>:8890?mode=caller&streamid=read:live&latency=120000` | VLC | 中（UDP，实时性好） |
| **WebRTC** | `http://<IP>:8889/live/whep`（WHEP 端点） | 浏览器 | **低（~100ms）** |

### SRT（VLC 播放，延迟中等）
另一台电脑的 VLC → 打开网络串流，填：
```
srt://192.168.0.103:8890?mode=caller&streamid=read:live&latency=120000
```
- `mode=caller`：本端作为发起方连服务器的 SRT 监听端口 8890
- `streamid=read:live`：告诉服务器"我来读 `live` 这条流"
- `latency=120000`：SRT 延迟设为 120ms（默认较大）。局域网可再调小，越大越抗网络抖动、越多延迟

也可直接双击本目录 `play_srt.bat`（会自动带好参数打开 VLC；IP 变了要改脚本里的地址）。

### WebRTC（浏览器播放，延迟最低）
VLC 不支持 WebRTC，需用浏览器。**不要用 file:// 直接双击打开 player.html**（CORS 会拦截导致连不上），而是用 HTTP 方式访问（需要 node 环境，本机已具备）：

1. 服务器端先启动静态服务：双击 **`start_web_player.bat`**（用 node 在 8080 端口提供 `player.html`）
2. 另台电脑浏览器打开：
   ```
   http://192.168.0.103:8080/player.html
   ```
3. 页面里默认 WHEP 地址 `http://192.168.0.103:8889/live/whep`，IP 变了改一下再点播放。首次出画面需 1~2 秒。

> **为何不能 file:// 打开**：浏览器用 `file://` 打开时请求来源是 `null`，需服务器的
> `apiAllowOrigins` 放行，而 MediaMTX 对 `null` 来源不回发 CORS 头，浏览器会报
> "Failed to fetch"。用 `http://` 访问后来源变成真实 http，配合 `apiAllowOrigins: ["*"]` 即可通。

> 浏览器要求 H.264 流为 **4:2:0 采样 + Baseline 基线**（浏览器解码器不支持 4:2:2 / High profile），已在推流命令里用 `-pix_fmt yuv420p -profile:v baseline` 强制处理，三协议通用。

---

## 四、端口一览与安全

### 4.1 端口清单

服务器监听多个端口，每个对应一种对外能力：

| 端口 | 协议 | 用途 | 内容是否加密 |
|------|------|------|:---:|
| **8554** | TCP | RTSP 流（VLC/ffplay 拉流） | 明文 |
| **8000 / 8001** | UDP | RTSP 的 RTP/RTCP 媒体（一般用不到，走 8554 TCP 为主） | 明文 |
| **8890** | UDP | SRT 流（VLC 低延迟拉流） | SRT 可加密，默认 off |
| **8889** | TCP | WebRTC **信令**（WHEP 协商，只交换参数） | 明文参数 |
| **8080** | TCP | 静态播放页 `player.html`（node serve.js） | 明文 |
| 8892/8893 | TCP/UDP | MoQ 协议（本项目未用） | — |

### 4.2 安全性怎么评

分两件事看，结论不一样：

- **内容加密**：WebRTC（8189 媒体）走 **DTLS/SRTP 强加密**，抓包看到的是密文；而 **RTSP（8554）是明文裸流**，抓包直接能看视频。所以**论"画面不被旁路偷看"，WebRTC 反而比 RTSP 更安全**。
- **访问控制**：本项目**没有账号密码**，`apiAllowOrigins: ["*"]` 意味着**任何能连到端口的人都能看摄像头**。这一点 RTSP / SRT / WebRTC 全都一样。

**核心风险是"暴露范围"**：`192.168.0.x` 是私有地址，正常情况下**只在局域网内可见**，风险 = "局域网内的人能看你的摄像头"。但一旦这台机器被**端口转发 / DMZ / 公网 IP** 暴露出去，以上所有端口都会变成**无鉴权的公网摄像头**，必须警惕。

### 4.3 防火墙：放行与关闭命令（管理员运行）

`netsh` 修改防火墙需**以管理员身份**运行命令提示符。

**查询某规则是否存在：**
```cmd
netsh advfirewall firewall show rule name="WebRTC-Player-HTTP-8080"
```

**放行（按需，也可只放行你要用的协议）：**
```cmd
REM RTSP
netsh advfirewall firewall add rule name="MTX-RTSP-8554"    dir=in action=allow protocol=TCP localport=8554 enable=yes
REM SRT
netsh advfirewall firewall add rule name="MTX-SRT-8890"     dir=in action=allow protocol=UDP localport=8890 enable=yes
REM WebRTC 信令 + 媒体
netsh advfirewall firewall add rule name="MTX-WebRTC-8889"  dir=in action=allow protocol=TCP localport=8889 enable=yes
netsh advfirewall firewall add rule name="MTX-WebRTC-8189"  dir=in action=allow protocol=UDP localport=8189 enable=yes
REM WebRTC 静态播放页
netsh advfirewall firewall add rule name="WebRTC-Player-HTTP-8080" dir=in action=allow protocol=TCP localport=8080 enable=yes
```

**关闭（删除）——与放行一一对应，改 `add` 为 `delete rule name=all protocol=... localport=...`：**
```cmd
netsh advfirewall firewall delete rule name=all protocol=TCP localport=8554
netsh advfirewall firewall delete rule name=all protocol=UDP localport=8890
netsh advfirewall firewall delete rule name=all protocol=TCP localport=8889
netsh advfirewall firewall delete rule name=all protocol=UDP localport=8189
netsh advfirewall firewall delete rule name=all protocol=TCP localport=8080
```

> `delete rule name=` 要求名称完全一致；`delete rule name=all protocol=... localport=...` 则按端口兜底删除。
> 删除是永久的；正在连接的会话不受影响，仅新连接被拦。

**更稳的做法——只对局域网网段开放**（推荐用这个，别对全网段放行）。

把下面每条命令的 `192.168.0.0/24` 换成你自己的网段（`ipconfig` 里 IPv4 的前三段 + `.0/24`，例如 `192.168.0.103` → `192.168.0.0/24`）。这样**只有该网段的机器能访问**，其他网段和外网一律拦掉。

**放行（完整清单，覆盖全部端口的 TCP/UDP 与远程网段）：**
```cmd
REM RTSP 流
netsh advfirewall firewall add rule name="LAN-RTSP-8554" dir=in action=allow protocol=TCP localport=8554 remoteip=192.168.0.0/24 enable=yes

REM SRT 流
netsh advfirewall firewall add rule name="LAN-SRT-8890" dir=in action=allow protocol=UDP localport=8890 remoteip=192.168.0.0/24 enable=yes

REM WebRTC 信令 (TCP)
netsh advfirewall firewall add rule name="LAN-WebRTC-SIG-8889" dir=in action=allow protocol=TCP localport=8889 remoteip=192.168.0.0/24 enable=yes

REM WebRTC 媒体 (UDP)
netsh advfirewall firewall add rule name="LAN-WebRTC-MEDIA-8189" dir=in action=allow protocol=UDP localport=8189 remoteip=192.168.0.0/24 enable=yes

REM WebRTC 静态播放页
netsh advfirewall firewall add rule name="LAN-WEB-8080" dir=in action=allow protocol=TCP localport=8080 remoteip=192.168.0.0/24 enable=yes
```

> 除非你确实用 RTSP 的 UDP 媒体（VLC 走 TCP 时用不到 8554 已够），否则 8000/8001 一般不必放行——本清单**刻意不含**它们，减少暴露面。

**关闭（删除）——与放行**按规则名一一对应**，安全精确，不会误删同一端口的其他规则**：
```cmd
netsh advfirewall firewall delete rule name="LAN-RTSP-8554"
netsh advfirewall firewall delete rule name="LAN-SRT-8890"
netsh advfirewall firewall delete rule name="LAN-WebRTC-SIG-8889"
netsh advfirewall firewall delete rule name="LAN-WebRTC-MEDIA-8189"
netsh advfirewall firewall delete rule name="LAN-WEB-8080"
```

**先查后删（确认规则是否存在、方向/协议/网段是否正确）：**
```cmd
netsh advfirewall firewall show rule name="LAN-WebRTC-SIG-8889"
```

> 精确安全删除的要点：**用 `delete rule name="..."` 且名字必须与放行时完全一致**（含引号、大小写），它只删这一条，绝不动别的。若想整网段一次性清空某端口的所有规则，退回用 `delete rule name=all protocol=TCP localport=8889`——但那种会连该端口上其他用途的规则一起删，非必要别用。

### 4.4 进一步加固（可选）

- 若需**从公网**访问：先给 MediaMTX 配置路径鉴权（`paths.live.readUser/readPass`），再考虑端口转发，否则不要暴露公网。
- 平时若只用 VLC（RTSP/SRT），可不放行 8889/8189/8080，减少暴露面。
- 尽量保持防火墙放行规则带 `remoteip` 限定在局域网网段。

---

## 五、延迟优化（本次已应用）

| 手段 | 位置 | 效果 |
|------|------|------|
| VLC **网络缓存降到 200ms** | 播放端 | 降幅最大（VLC 默认 1~2s） |
| `writeQueueSize 128` | 服务器端 | 裁掉读端写队列最坏情况缓冲 |
| `-preset ultrafast -tune zerolatency` | 编码端 | 实时编码 |
| `-rtbufsize 64M` | 编码端 | 防丢帧（保留，去掉会重新掉帧） |

VLC 改缓冲方法：工具 → 偏好设置 → 显示设置切**全部** → 输入/编解码器 → **网络缓存**填 `200`。

> RTSP 本身不是低延迟协议，局域网下稳定约 300~500ms 属正常。要更低需改用 WebRTC / SRT。

---

## 六、故障排查

| 现象 | 排查 |
|------|------|
| 其他电脑连不上 | ① 两机同局域网？`ping <服务器IP>` ② 防火墙 8554 端口放行了？③ 服务器进程活着？`tasklist /fi "imagename eq mediamtx.exe"` |
| 本机能连、他机不能 | 基本是防火墙，或他机用了 `localhost`（`localhost` 只指本机，他机要填服务器局域网 IP） |
| 镜像画面 | 这是预览镜像，RTSP 流本身正常 |
| 有画面但卡顿/丢帧 | 1080p 编码吃 CPU；可把命令里 `-vf scale=1280:720` 降到 720p 更稳 |
| `dshow 缓冲 full` 警告 | 已用 `-rtbufsize 64M` 缓解；持续出现考虑降分辨率 |
| WebRTC 报 "Failed to fetch" | 别用 `file://` 双击打开 `player.html`（Origin 为 null 被 CORS 拦）；改用 `http://<服务器IP>:8080/player.html` 打开 |
| 自测能连、跨机连不上 | 本机用 `localhost` 测只能证明服务在跑；跨机要填**服务器局域网 IP**，且确认服务器防火墙已放行对应端口 |
| 机器能上外网但局域网互访失败 | 多半是 Windows 把网络识别成了**公用(Public)**，会拦截入站 RDP/局域网访问。设置→网络→把网络配置文件从"公用"切回"专用" |
| `409/400/405` 类似报错 | WHEP 端点 `:8889/live/whep` 只接受 **POST**（带 SDP）；浏览器地址栏直接打开发 GET 会报 method not allowed，属正常 |

---

## 七、版本记录

```
c7a6024 fix: 修复 WebRTC 跨机 Failed to fetch (CORS + 静态服务)
e93acfc feat: 新增 SRT 与 WebRTC 低延迟拉流
46383f4 docs: 补充证书 auto.crt/auto.key 说明
0d83fde docs: 新增完整 README
a4f9ee6 tune: 降低 MediaMTX 写队列以缩减局域网延迟
4b73b43 feat: 建立局域网 RTSP 摄像头推流服务器
```