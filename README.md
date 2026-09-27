# 局域网 RTSP 摄像头推流服务器

把本机电脑的**摄像头**变成标准 **RTSP 流**，供同一局域网内其他电脑/设备实时拉流观看。

## 架构原理

```
摄像头 ──①采集+编码──► MediaMTX(RTSP服务器) ──②广播──► 任意拉流端(VLC/ffplay)
        FFmpeg(dshow)      :8554/live          RTSP
```

- **FFmpeg**：采集摄像头 → H.264 编码 → 推流给服务器
- **媒体服务器 (MediaMTX)**：接收并向外广播，对访问者提供标准 RTSP 地址

职责分离的好处：服务器只看一种流格式，换采集源（摄像头/屏幕/文件）无需改服务器。

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

## 三、延迟优化（本次已应用）

| 手段 | 位置 | 效果 |
|------|------|------|
| VLC **网络缓存降到 200ms** | 播放端 | 降幅最大（VLC 默认 1~2s） |
| `writeQueueSize 128` | 服务器端 | 裁掉读端写队列最坏情况缓冲 |
| `-preset ultrafast -tune zerolatency` | 编码端 | 实时编码 |
| `-rtbufsize 64M` | 编码端 | 防丢帧（保留，去掉会重新掉帧） |

VLC 改缓冲方法：工具 → 偏好设置 → 显示设置切**全部** → 输入/编解码器 → **网络缓存**填 `200`。

> RTSP 本身不是低延迟协议，局域网下稳定约 300~500ms 属正常。要更低需改用 WebRTC / SRT。

---

## 四、故障排查

| 现象 | 排查 |
|------|------|
| 其他电脑连不上 | ① 两机同局域网？`ping <服务器IP>` ② 防火墙 8554 端口放行了？③ 服务器进程活着？`tasklist /fi "imagename eq mediamtx.exe"` |
| 本机能连、他机不能 | 基本是防火墙，或他机用了 `localhost`（`localhost` 只指本机，他机要填服务器局域网 IP） |
| 镜像画面 | 这是预览镜像，RTSP 流本身正常 |
| 有画面但卡顿/丢帧 | 1080p 编码吃 CPU；可把命令里 `-vf scale=1280:720` 降到 720p 更稳 |
| `dshow 缓冲 full` 警告 | 已用 `-rtbufsize 64M` 缓解；持续出现考虑降分辨率 |

---

## 五、版本记录

```
a4f9ee6 tune: 降低 MediaMTX 写队列以缩减局域网延迟
4b73b43 feat: 建立局域网 RTSP 摄像头推流服务器
```