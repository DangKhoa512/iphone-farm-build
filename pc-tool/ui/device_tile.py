"""Single iPhone tile: shows live MJPEG stream + status overlay."""

import numpy as np
import cv2
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QLabel,
                              QPushButton, QHBoxLayout, QFrame)
from PyQt6.QtCore    import Qt, QThread, pyqtSlot, QSize
from PyQt6.QtGui     import QImage, QPixmap, QColor, QPainter, QPen

from stream_worker  import StreamWorker
from device_manager import Device

# Tile dimensions (resized to fit grid)
TILE_W, TILE_H = 200, 360


class DeviceTile(QFrame):
    def __init__(self, device: Device, parent=None):
        super().__init__(parent)
        self.device = device
        self._worker: StreamWorker | None = None
        self._thread: QThread | None = None
        self._connected = False
        self._fps_count = 0
        self._fps_display = 0

        self.setFixedSize(TILE_W + 8, TILE_H + 60)
        self.setFrameShape(QFrame.Shape.StyledPanel)
        self.setStyleSheet("""
            QFrame { background:#1a1a1a; border:1px solid #333; border-radius:6px; }
        """)
        self._build_ui()
        self._connect()

    # ------------------------------------------------------------------
    # UI
    # ------------------------------------------------------------------

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(4)

        # Device name
        self._name_lbl = QLabel(self.device.label)
        self._name_lbl.setStyleSheet("color:#ccc; font-size:11px; font-weight:bold;")
        self._name_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self._name_lbl)

        # Stream canvas
        self._canvas = QLabel()
        self._canvas.setFixedSize(TILE_W, TILE_H)
        self._canvas.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._canvas.setStyleSheet("background:#000; border-radius:4px;")
        self._show_placeholder("Connecting…")
        layout.addWidget(self._canvas)

        # Status bar
        bar = QHBoxLayout()
        self._status_lbl = QLabel("•  connecting")
        self._status_lbl.setStyleSheet("color:#888; font-size:9px;")
        bar.addWidget(self._status_lbl)
        bar.addStretch()

        self._fps_lbl = QLabel("-- fps")
        self._fps_lbl.setStyleSheet("color:#888; font-size:9px;")
        bar.addWidget(self._fps_lbl)
        layout.addLayout(bar)

        # Reconnect button (hidden while OK)
        self._reconnect_btn = QPushButton("Reconnect")
        self._reconnect_btn.setFixedHeight(22)
        self._reconnect_btn.setStyleSheet(
            "QPushButton{background:#333;color:#ccc;border-radius:3px;font-size:10px;}"
            "QPushButton:hover{background:#555;}"
        )
        self._reconnect_btn.clicked.connect(self._connect)
        self._reconnect_btn.hide()
        layout.addWidget(self._reconnect_btn)

    def _show_placeholder(self, text: str):
        placeholder = QPixmap(TILE_W, TILE_H)
        placeholder.fill(QColor(20, 20, 20))
        p = QPainter(placeholder)
        p.setPen(QPen(QColor(120, 120, 120)))
        p.drawText(placeholder.rect(), Qt.AlignmentFlag.AlignCenter, text)
        p.end()
        self._canvas.setPixmap(placeholder)

    # ------------------------------------------------------------------
    # Streaming
    # ------------------------------------------------------------------

    def _connect(self):
        self._disconnect_worker()
        self._thread = QThread()
        self._worker = StreamWorker(self.device.ip, self.device.port)
        self._worker.moveToThread(self._thread)

        self._worker.frame_ready.connect(self._on_frame)
        self._worker.connected.connect(self._on_connected)
        self._worker.disconnected.connect(self._on_disconnected)
        self._worker.error.connect(self._on_error)

        self._thread.started.connect(self._worker.start)
        self._thread.start()

        self._reconnect_btn.hide()
        self._show_placeholder("Connecting…")
        self._status_lbl.setText("•  connecting")
        self._status_lbl.setStyleSheet("color:#888; font-size:9px;")

    def _disconnect_worker(self):
        if self._worker:
            self._worker.stop()
        if self._thread:
            self._thread.quit()
            self._thread.wait(2000)
        self._worker = None
        self._thread = None

    def cleanup(self):
        self._disconnect_worker()

    # ------------------------------------------------------------------
    # Slots
    # ------------------------------------------------------------------

    @pyqtSlot(np.ndarray)
    def _on_frame(self, frame: np.ndarray):
        # Resize frame to tile dimensions (keep aspect ratio)
        h, w = frame.shape[:2]
        scale = min(TILE_W / w, TILE_H / h)
        new_w, new_h = int(w * scale), int(h * scale)
        resized = cv2.resize(frame, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
        qimg = QImage(rgb.data, new_w, new_h, new_w * 3, QImage.Format.Format_RGB888)
        pix  = QPixmap.fromImage(qimg)

        # Center on black background
        canvas = QPixmap(TILE_W, TILE_H)
        canvas.fill(QColor(0, 0, 0))
        p = QPainter(canvas)
        p.drawPixmap((TILE_W - new_w) // 2, (TILE_H - new_h) // 2, pix)
        p.end()
        self._canvas.setPixmap(canvas)

        self._fps_count += 1
        # Update FPS counter every 30 frames
        if self._fps_count % 30 == 0:
            self._fps_lbl.setText(f"~{self.device.label[:4]} fps")

    @pyqtSlot()
    def _on_connected(self):
        self._connected = True
        self._status_lbl.setText("●  live")
        self._status_lbl.setStyleSheet("color:#4caf50; font-size:9px;")
        self._reconnect_btn.hide()

    @pyqtSlot()
    def _on_disconnected(self):
        self._connected = False
        self._status_lbl.setText("○  offline")
        self._status_lbl.setStyleSheet("color:#f44336; font-size:9px;")
        self._show_placeholder("Disconnected")
        self._reconnect_btn.show()

    @pyqtSlot(str)
    def _on_error(self, msg: str):
        self._status_lbl.setText(f"⚠  {msg[:28]}")
        self._status_lbl.setStyleSheet("color:#ff9800; font-size:9px;")
        self._reconnect_btn.show()
