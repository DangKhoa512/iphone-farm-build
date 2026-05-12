"""Background thread: connects to an iPhone MJPEG stream and emits frames."""

import threading
import urllib.request
import numpy as np
import cv2
from PyQt6.QtCore import QObject, pyqtSignal, QThread


class StreamWorker(QObject):
    frame_ready = pyqtSignal(np.ndarray)   # emits decoded BGR frame
    error       = pyqtSignal(str)
    connected   = pyqtSignal()
    disconnected = pyqtSignal()

    def __init__(self, ip: str, port: int = 7777, timeout: int = 5):
        super().__init__()
        self.ip      = ip
        self.port    = port
        self.timeout = timeout
        self._stop   = threading.Event()
        self._thread = None

    # ------------------------------------------------------------------

    def start(self):
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()

    # ------------------------------------------------------------------

    def _run(self):
        url = f"http://{self.ip}:{self.port}/stream"
        try:
            req = urllib.request.urlopen(url, timeout=self.timeout)
            self.connected.emit()
        except Exception as e:
            self.error.emit(str(e))
            self.disconnected.emit()
            return

        buf = b""
        SOI = b"\xff\xd8"
        EOI = b"\xff\xd9"

        while not self._stop.is_set():
            try:
                chunk = req.read(65536)
                if not chunk:
                    break
                buf += chunk

                # Parse JPEG frames from MJPEG stream
                while True:
                    start = buf.find(SOI)
                    if start == -1:
                        buf = b""
                        break
                    end = buf.find(EOI, start + 2)
                    if end == -1:
                        buf = buf[start:]   # keep partial frame
                        break

                    jpeg = buf[start : end + 2]
                    buf  = buf[end + 2:]

                    arr   = np.frombuffer(jpeg, dtype=np.uint8)
                    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
                    if frame is not None:
                        self.frame_ready.emit(frame)

            except OSError:
                break

        self.disconnected.emit()
