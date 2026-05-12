"""Device discovery: manual add + mDNS broadcast scanner."""

import threading
import requests
from dataclasses import dataclass, field
from typing import Optional, Callable
from zeroconf import ServiceBrowser, Zeroconf, ServiceInfo


@dataclass
class Device:
    ip:      str
    port:    int   = 7777
    name:    str   = ""
    udid:    str   = ""
    model:   str   = ""
    ios_ver: str   = ""
    width:   int   = 0
    height:  int   = 0

    @property
    def label(self) -> str:
        return self.name or self.ip

    def stream_url(self) -> str:
        return f"http://{self.ip}:{self.port}/stream"

    def info_url(self) -> str:
        return f"http://{self.ip}:{self.port}/info"

    def screenshot_url(self) -> str:
        return f"http://{self.ip}:{self.port}/screenshot"


class DeviceManager:
    """Manages a set of known devices; calls on_change when the list updates."""

    def __init__(self, on_change: Callable[[], None]):
        self._on_change = on_change
        self._devices: dict[str, Device] = {}   # keyed by ip:port
        self._lock = threading.Lock()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def add_device(self, ip: str, port: int = 7777) -> Optional[Device]:
        """Ping /info and register device. Returns Device or None on failure."""
        key = f"{ip}:{port}"
        with self._lock:
            if key in self._devices:
                return self._devices[key]

        dev = Device(ip=ip, port=port)
        if self._fetch_info(dev):
            with self._lock:
                self._devices[key] = dev
            self._on_change()
            return dev
        return None

    def remove_device(self, ip: str, port: int = 7777):
        key = f"{ip}:{port}"
        with self._lock:
            self._devices.pop(key, None)
        self._on_change()

    def all_devices(self) -> list[Device]:
        with self._lock:
            return list(self._devices.values())

    def refresh_info(self, dev: Device):
        threading.Thread(target=self._fetch_info, args=(dev,), daemon=True).start()

    # ------------------------------------------------------------------

    def _fetch_info(self, dev: Device) -> bool:
        try:
            r = requests.get(dev.info_url(), timeout=3)
            if r.status_code == 200:
                d = r.json()
                dev.name    = d.get("name",    dev.ip)
                dev.udid    = d.get("udid",    "")
                dev.model   = d.get("model",   "")
                dev.ios_ver = d.get("ios_version", "")
                dev.width   = d.get("screen_w", 0)
                dev.height  = d.get("screen_h", 0)
                dev.port    = d.get("server_port", dev.port)
                return True
        except Exception:
            pass
        return False


# ---------------------------------------------------------------------------
# Optional: mDNS scanner (passive — iPhones don't broadcast by default,
# but if you add Bonjour advertisement to the iOS daemon this will find them)
# ---------------------------------------------------------------------------

class MDNSScanner:
    SERVICE = "_iphone-farm._tcp.local."

    def __init__(self, on_found: Callable[[str, int], None]):
        self._on_found = on_found
        self._zc: Optional[Zeroconf] = None
        self._browser = None

    def start(self):
        self._zc      = Zeroconf()
        self._browser = ServiceBrowser(self._zc, self.SERVICE, self)

    def stop(self):
        if self._zc:
            self._zc.close()

    # zeroconf callbacks
    def add_service(self, zc, type_, name):
        info = zc.get_service_info(type_, name)
        if info and info.addresses:
            import socket
            ip   = socket.inet_ntoa(info.addresses[0])
            port = info.port
            self._on_found(ip, port)

    def remove_service(self, zc, type_, name): pass
    def update_service(self, zc, type_, name): pass
