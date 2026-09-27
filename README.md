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
| 服务器本地 IP（示例） | `192.168.0.103`（重启后可能变，运行时以 `ipconfig` 为准） |
| 推流地址 | `rtsp://localhost:8554/live` |
| 远程拉流地址 | `rtsp://192.168.0.103:8554/live` |

> **`192.168.0.103` 是什么**：是运行 `start_rtsp.bat`（即"摄像头+服务器"所在**这台电脑**）自己的局域网 IPv4，**不是**播放端/其他电脑的地址。文档里所有出现 `192.168.0.103` 或 `<IP>` 的地方，都指这个**服务器本机 IP**，由服务器上 `ipconfig` 查得（常见 `192.168.0.x` / `192.168.1.x`）。其他电脑拉流时把它替换成该值即可。

### 目录结构

```
build_rtsp/
├── mediamtx.exe       # RTSP 服务器主程序
├── mediamtx.yml       # 服务器配置（含摄像头自动推流）
├── start_rtsp.bat     # 一键启动主服务(mediamtx,自动带出 ffmpeg)
├── stop_rtsp.bat      # 一键停止主服务(mediamtx + ffmpeg)
├── start_web_player.bat # 启动 node 静态服务(8080)，提供 player.html
├── stop_web_player.bat  # 按 8080 端口精确停止 serve.js(不误伤其他 node)
├── serve.js           # 极简静态文件服务器(零依赖)
├── player.html        # WebRTC 浏览器播放器(经 http://IP:8080/player.html 访问)
├── firewall_lan_open.bat  # 一键放行局域网网段的全部端口(自动提权)
├── firewall_lan_close.bat # 一键精确删除上述规则(按规则名,安全)
├── LICENSE
└── .gitignore
```

### 日常使用

**启停关系（先了解架构再操作）**：服务分两个**独立**部分，按需启动/停止——
- **主服务** = `mediamtx.exe`（RTSP/SRT/WebRTC 服务端），它启动时会**自动再拉起** `ffmpeg.exe`（采集推流子进程，**无需手动启动**）。由 `start_rtsp.bat` / `stop_rtsp.bat` 管理。
- **WebRTC 静态服务** = `node serve.js`（8080 播放页），**只有**要用浏览器 WebRTC 看时才需要。由 `start_web_player.bat` / `stop_web_player.bat` 管理。

**启动**：
```cmd
REM 用 RTSP 看（另台电脑 ffplay/VLC）→ 只开主服务即可
start_rtsp.bat

REM 还要浏览器 WebRTC 看 → 再另开一个窗口启动静态服务
start_web_player.bat
```
启动后出现日志 `[path live] stream is available and online` 即为推流成功。

**停止**：
```cmd
REM 停主服务(mediamtx + ffmpeg)
stop_rtsp.bat

REM 若开过 WebRTC 静态服务，另停它(按 8080 端口精确结束,不误伤其他 node)
stop_web_player.bat
```

**本机自测（低延迟命令，推荐）**：
```cmd
ffplay -fflags nobuffer -flags low_delay -probesize 32 -analyzeduration 0 -framedrop -rtsp_transport tcp -i "rtsp://localhost:8554/live"
```

**其他电脑拉流（推荐 ffplay，比 VLC 延迟低不少）**：把 `localhost` 换成服务器局域网 IP
```cmd
ffplay -fflags nobuffer -flags low_delay -probesize 32 -analyzeduration 0 -framedrop -rtsp_transport tcp -i "rtsp://192.168.0.103:8554/live"
```
参数作用：`-fflags nobuffer`+`-flags low_delay` 关缓冲、走低延迟；`-probesize 32`/`-analyzeduration 0` 不做长探测；`-framedrop` 跟不上就丢帧不积压；`-rtsp_transport tcp` 局域网取 TCP。如需更极限可改 `udp`（更低但 1080p 可能丢帧）。

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

确保拉流电脑与服务器**同一局域网**（同一路由器/Wi-Fi）。ffplay 打开（低延迟命令，把 IP 换成服务器 IP）：
```
ffplay -fflags nobuffer -flags low_delay -probesize 32 -analyzeduration 0 -framedrop -rtsp_transport tcp -i "rtsp://<服务器IP>:8554/live"
```
能出画面即打通。

---

## 三、多种拉流方式（RTSP / SRT / WebRTC）

一台服务器同时开启三种协议，按需选择：

| 协议 | 地址 | 播放方式 | 延迟 |
|------|------|----------|------|
| **RTSP** | `rtsp://<IP>:8554/live` | VLC / ffplay | **中（稳定，局域网首选）** |
| **SRT** | `srt://<IP>:8890?mode=caller&streamid=read:live&latency=500000` | **ffplay / MPV**（别用 VLC） | 较高（重传窗口下限 ~500ms，局域网反而不如 RTSP） |
| **WebRTC** | `http://<IP>:8889/live/whep`（WHEP 端点） | 浏览器 | **低（~100ms）** |

### SRT（ffplay/MPV 播放，延迟较高，局域网不推荐）
**⚠ 不要用 VLC 测 SRT**：VLC 的 SRT 实现有缺陷，实测表现为"等几十秒才出画面、出一帧后卡死、周期性地动几秒又卡死"。同样这条流用 ffplay/MPV 完全正常——已确认服务器侧 SRT 链路本身健康，问题在 VLC。

另台电脑用 **ffplay**（ffmpeg 自带，装了 ffmpeg 就有）播放：
```
ffplay -infbuf -fflags nobuffer -probesize 32 -analyzeduration 0 -framedrop -i "srt://192.168.0.103:8890?mode=caller&streamid=read:live&latency=500000"
```
- `mode=caller`：本端作为发起方连服务器的 SRT 监听端口 8890
- `streamid=read:live`：告诉服务器"我来读 `live` 这条流"
- `latency=500000`：SRT 接收窗口 500ms，是**重传窗口下限**——SRT 靠它做丢包重传，**压不掉**，所以局域网里 SRT 反而比 RTSP 慢
- `-infbuf -fflags nobuffer -probesize 32 -analyzeduration 0 -framedrop`：关闭缓冲/长时间探测、跟不上就丢帧，强制实时（**不加这些 ffplay 默认会攒几秒缓冲，延迟会飙到好几秒**）

> **SRT 在局域网价值很小**：它专为"跨不可靠公网、丢包还能靠重传保住画面"设计，代价就是这个重传窗口。干净的局域网几乎不丢包，等于白付这 ~500ms 成本。**局域网低延迟请用 RTSP / WebRTC**；SRT 只在需要跨公网/跨运营商拉流时才有意义。

### WebRTC（浏览器播放，延迟最低）
VLC 不支持 WebRTC，需用浏览器。**不要用 file:// 直接双击打开 player.html**（CORS 会拦截导致连不上），而是用 HTTP 方式访问（需要 node 环境，本机已具备）：

1. 服务器端先启动静态服务：双击 **`start_web_player.bat`**（用 node 在 8080 端口提供 `player.html`）
2. 另台电脑浏览器打开：
   ```
   http://192.168.0.103:8080/player.html
   ```
3. 页面会**自动按你访问的服务器 IP 生成 WHEP 地址**，无需手动改；点播放即可，首次出画面需 1~2 秒。若自动生成的地址不对，也可手动改输入框。

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
| **8890** | UDP | SRT 流（局域网不如 RTSP，跨公网才用） | SRT 可加密，默认 off |
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

> **⚠ 这个网段和上面那个服务器 IP 是一套的，必须联动**：`192.168.0.0/24` 由服务器本机 IP（`192.168.0.103`）取前三段得出，二者同源。**一旦局域网网段变了**（比如服务器 IP 变到 `192.168.1.x`），放行网段就要**同步改成 `192.168.1.0/24`**——否则旧规则放行的是原网段，新网段的机器仍连不上。改法：先 `firewall_lan_close.bat`（或按名删旧规则），再改 `firewall_lan_open.bat` 顶部的 `SUBNET=192.168.1.0/24` 后重新放行。

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

**一键化（推荐）**：以上"放行/删除"已封装成两个脚本，双击即用（会自动请求管理员权限，端口清单与本页一致）：
- `firewall_lan_open.bat` —— 放行局域网网段（默认 `192.168.0.0/24`，网段不同就改文件顶部 `SUBNET`）
- `firewall_lan_close.bat` —— 精确删除上面那 5 条 `LAN-*` 规则，不影响其他规则

### 4.4 迁移：清理旧的"整网段"规则，统一改用脚本

早期文档给过一套**不带 `remoteip` 的整网段放行规则**（`MTX-RTSP-8554`、`MTX-SRT-8890`、`MTX-WebRTC-8889`、`MTX-WebRTC-8189`、`WebRTC-Player-HTTP-8080`）。它们对**所有来源**开放，暴露面比局域网限定更大。建议清掉后统一用脚本管理。

**① 先看有哪些旧规则**（管理员运行）：
```cmd
netsh advfirewall firewall show rule name=all | findstr /i "MTX- WebRTC- Player- LAN-"
```

**② 确认后，按名删除旧的整网段规则**（`delete rule name=...` 只删指定这条）：
```cmd
netsh advfirewall firewall delete rule name="MTX-RTSP-8554"
netsh advfirewall firewall delete rule name="MTX-SRT-8890"
netsh advfirewall firewall delete rule name="MTX-WebRTC-8889"
netsh advfirewall firewall delete rule name="MTX-WebRTC-8189"
netsh advfirewall firewall delete rule name="WebRTC-Player-HTTP-8080"
```

> 若之前还按更早的示例建过 `WebRTC-IN-LAN` / `WebRTC-UDP-LAN`，也一并删掉：
> ```cmd
> netsh advfirewall firewall delete rule name="WebRTC-IN-LAN"
> netsh advfirewall firewall delete rule name="WebRTC-UDP-LAN"
> ```

**③ 用脚本重建局域网限定规则**：
```cmd
双击 firewall_lan_open.bat
```

**④ 核对最终状态**——应看到 `LAN-*` 五条，且不再有 `MTX-*` / `WebRTC-Player-HTTP-8080`：
```cmd
netsh advfirewall firewall show rule name=all | findstr /i "LAN- MTX- WebRTC- Player-"
```

### 4.5 进一步加固（可选）

- 若需**从公网**访问：先给 MediaMTX 配置路径鉴权（`paths.live.readUser/readPass`），再考虑端口转发，否则不要暴露公网。
- 平时若只要 RTSP（VLC/ffplay）看，可不放行 8889/8189/8080，减少暴露面（注意 SRT 的 VLC 客户端不可用）。
- 尽量保持防火墙放行规则带 `remoteip` 限定在局域网网段。

---

## 五、延迟优化（本次已应用）

| 手段 | 位置 | 效果 |
|------|------|------|
| **ffplay 低延迟参数**（`-fflags nobuffer -flags low_delay -probesize 32 -analyzeduration 0 -framedrop -rtsp_transport tcp`） | 播放端 | 比 VLC 延迟低不少；推荐用它测（见"本机/其他电脑拉流"） |
| VLC **网络缓存降到 200ms** | 播放端 | 若坚持用 VLC：默认 1~2s → 200ms |
| `-g 30`（关键帧 1 秒一个） | 编码端 | 起播/续帧更快（需重启服务器生效） |
| `writeQueueSize 128` | 服务器端 | 裁掉读端写队列最坏情况缓冲 |
| `-preset ultrafast -tune zerolatency` | 编码端 | 实时编码 |
| `-rtbufsize 64M` | 编码端 | 防丢帧（保留，去掉会重新掉帧） |

VLC 改缓冲方法：工具 → 偏好设置 → 显示设置切**全部** → 输入/编解码器 → **网络缓存**填 `200`。

> RTSP 本身不是低延迟协议，局域网下稳定、带轻微延迟（约 300~500ms）属正常，已比 SRT 快。
> 要更低延迟用 WebRTC（~100ms）。**SRT 有 ~500ms 重传窗口下限，局域网里反而比 RTSP 慢**，仅适合跨公网/丢包链路。

---

## 六、故障排查

| 现象 | 排查 |
|------|------|
| 其他电脑连不上 | ① 两机同局域网？`ping <服务器IP>` ② 防火墙 8554 端口放行了？③ 服务器进程活着？`tasklist /fi "imagename eq mediamtx.exe"` |
| 本机能连、他机不能 | 基本是防火墙，或他机用了 `localhost`（`localhost` 只指本机，他机要填服务器局域网 IP） |
| 镜像画面 | 这是预览镜像，RTSP 流本身正常 |
| SRT 用 VLC 播一帧卡死/周期性卡顿 | 属 VLC 的 SRT 实现缺陷，非服务器问题；改用 ffplay/MPV（见"多种拉流方式"SRT 段） |
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