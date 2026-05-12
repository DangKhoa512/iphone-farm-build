# iPhone Farm Monitor

Stream & monitor multiple iPhone screens simultaneously on PC.

## Architecture

```
iPhone (jailbroken)                  PC
┌─────────────────────────┐         ┌──────────────────────────────┐
│  LaunchDaemon (root)    │  WiFi   │  PyQt6 Grid UI               │
│  ├─ ScreenCapture       │ ──────► │  ├─ DeviceTile × N           │
│  │   UIWindow rendering │  :7777  │  │   MJPEG frame decode       │
│  └─ HTTPServer          │         │  └─ DeviceManager             │
│      /stream  MJPEG     │         │      add/remove devices       │
│      /screenshot JPEG   │         └──────────────────────────────┘
│      /info    JSON      │
└─────────────────────────┘
```

---

## iPhone DEB (Jailbreak required — iOS 14+)

### Build requirements
- [Theos](https://theos.dev) installed on macOS/Linux
- Xcode command-line tools

### Build & install
```bash
cd ios-deb
make package          # builds .deb in packages/
make do               # build + scp to device (set THEOS_DEVICE_IP)
```

### What it installs
| File | Purpose |
|------|---------|
| `/usr/local/bin/iphone-farm-server` | Daemon binary |
| `/Library/LaunchDaemons/com.iphone-farm.server.plist` | Auto-start at boot |

### HTTP API (port 7777)
| Endpoint | Response |
|----------|---------|
| `GET /stream` | MJPEG multipart stream |
| `GET /screenshot` | Single JPEG |
| `GET /info` | JSON device info (name, UDID, screen size, IP) |

### Configure FPS / quality
Edit the plist arguments or restart with custom flags:
```bash
iphone-farm-server --port 7777 --fps 20 --quality 80
```

---

## PC Tool (Windows / macOS / Linux)

### Install
```bash
cd pc-tool
pip install -r requirements.txt
```

### Run
```bash
# Open GUI, add devices manually
python main.py

# Auto-add devices on startup
python main.py --devices 192.168.1.10 192.168.1.11 192.168.1.12 --cols 4
```

### Controls
- **+ Add Device** — enter IP + port, pings `/info` to verify
- **Columns** spinner — adjust grid width live
- **Reconnect** button — appears on each tile when stream drops
- **Remove All** — disconnect all

---

## Network setup (WiFi farm)
1. All iPhones on same WiFi as PC
2. Note each iPhone's IP from **Settings → Wi-Fi → (i)**
3. The `/info` endpoint also reports `wifi_ip`

## Scaling tips
| Devices | Recommended FPS | Quality |
|---------|----------------|---------|
| 1–10    | 20             | 80      |
| 10–30   | 15             | 70      |
| 30–100  | 10             | 60      |
| 100+    | 5              | 50      |
