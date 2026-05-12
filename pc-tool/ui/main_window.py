"""Main farm window: grid of DeviceTile widgets."""

from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QScrollArea, QLabel, QLineEdit, QPushButton,
    QSpinBox, QMessageBox, QDialog, QDialogButtonBox,
    QFormLayout, QGridLayout, QSizePolicy, QStatusBar,
    QFrame,
)
from PyQt6.QtCore  import Qt, QTimer
from PyQt6.QtGui   import QIcon, QFont

from device_manager import Device, DeviceManager
from ui.device_tile import DeviceTile


COLS_DEFAULT = 4


class AddDeviceDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Add iPhone")
        self.setFixedWidth(300)

        form  = QFormLayout(self)
        self._ip   = QLineEdit()
        self._ip.setPlaceholderText("192.168.1.xxx")
        self._port = QSpinBox()
        self._port.setRange(1, 65535)
        self._port.setValue(7777)
        form.addRow("IP address:", self._ip)
        form.addRow("Port:",       self._port)

        btns = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok |
            QDialogButtonBox.StandardButton.Cancel)
        btns.accepted.connect(self.accept)
        btns.rejected.connect(self.reject)
        form.addRow(btns)

    @property
    def ip(self)   -> str: return self._ip.text().strip()
    @property
    def port(self) -> int: return self._port.value()


# ---------------------------------------------------------------------------

class FarmWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("iPhone Farm Monitor")
        self.resize(1200, 800)
        self.setStyleSheet("QMainWindow { background:#111; }")

        self._tiles: dict[str, DeviceTile] = {}
        self._cols  = COLS_DEFAULT
        self._mgr   = DeviceManager(on_change=self._rebuild_grid)

        self._build_ui()

        # Status bar refresh
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._refresh_status)
        self._timer.start(2000)

    # ------------------------------------------------------------------
    # UI Construction
    # ------------------------------------------------------------------

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(8, 8, 8, 4)
        root.setSpacing(6)

        root.addWidget(self._build_toolbar())
        root.addWidget(self._build_grid_area(), 1)
        self.setStatusBar(QStatusBar())
        self._refresh_status()

    def _build_toolbar(self) -> QWidget:
        bar = QFrame()
        bar.setFixedHeight(44)
        bar.setStyleSheet("QFrame{background:#222;border-radius:6px;}")
        layout = QHBoxLayout(bar)
        layout.setContentsMargins(8, 4, 8, 4)

        title = QLabel("iPhone Farm Monitor")
        title.setStyleSheet("color:#eee; font-size:13px; font-weight:bold;")
        layout.addWidget(title)
        layout.addStretch()

        # Columns spinner
        layout.addWidget(QLabel("Columns:"))
        self._cols_spin = QSpinBox()
        self._cols_spin.setRange(1, 12)
        self._cols_spin.setValue(self._cols)
        self._cols_spin.setFixedWidth(55)
        self._cols_spin.valueChanged.connect(self._set_cols)
        self._cols_spin.setStyleSheet("QSpinBox{background:#333;color:#eee;border:1px solid #444;}")
        layout.addWidget(self._cols_spin)

        layout.addSpacing(12)

        add_btn = QPushButton("+ Add Device")
        add_btn.setFixedHeight(30)
        add_btn.setStyleSheet(
            "QPushButton{background:#1565c0;color:white;border-radius:4px;padding:0 12px;font-size:12px;}"
            "QPushButton:hover{background:#1976d2;}")
        add_btn.clicked.connect(self._add_device)
        layout.addWidget(add_btn)

        remove_btn = QPushButton("Remove All")
        remove_btn.setFixedHeight(30)
        remove_btn.setStyleSheet(
            "QPushButton{background:#b71c1c;color:white;border-radius:4px;padding:0 12px;font-size:12px;}"
            "QPushButton:hover{background:#c62828;}")
        remove_btn.clicked.connect(self._remove_all)
        layout.addWidget(remove_btn)

        return bar

    def _build_grid_area(self) -> QScrollArea:
        self._grid_widget = QWidget()
        self._grid_widget.setStyleSheet("background:#111;")
        self._grid = QGridLayout(self._grid_widget)
        self._grid.setSpacing(8)
        self._grid.setAlignment(Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(self._grid_widget)
        scroll.setStyleSheet("QScrollArea{border:none;background:#111;}")
        return scroll

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------

    def _add_device(self):
        dlg = AddDeviceDialog(self)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        ip, port = dlg.ip, dlg.port
        if not ip:
            return
        self.statusBar().showMessage(f"Connecting to {ip}:{port} …")

        import threading
        def _connect():
            dev = self._mgr.add_device(ip, port)
            if not dev:
                self.statusBar().showMessage(f"Failed to connect to {ip}:{port}")
        threading.Thread(target=_connect, daemon=True).start()

    def _remove_all(self):
        for key, tile in list(self._tiles.items()):
            tile.cleanup()
        self._tiles.clear()
        while self._grid.count():
            item = self._grid.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        for dev in self._mgr.all_devices():
            self._mgr.remove_device(dev.ip, dev.port)

    def _set_cols(self, cols: int):
        self._cols = cols
        self._rebuild_grid()

    # ------------------------------------------------------------------
    # Grid management
    # ------------------------------------------------------------------

    def _rebuild_grid(self):
        # Remove all existing tiles from grid without destroying them
        while self._grid.count():
            item = self._grid.takeAt(0)
            if item.widget():
                item.widget().setParent(None)  # detach, don't delete

        devices = self._mgr.all_devices()
        self.statusBar().showMessage(f"{len(devices)} device(s) connected")

        # Create tiles for new devices, reuse existing ones
        keys_wanted = {f"{d.ip}:{d.port}" for d in devices}
        keys_existing = set(self._tiles.keys())

        for key in keys_existing - keys_wanted:
            self._tiles[key].cleanup()
            del self._tiles[key]

        for dev in devices:
            key = f"{dev.ip}:{dev.port}"
            if key not in self._tiles:
                self._tiles[key] = DeviceTile(dev, self._grid_widget)

        # Re-add to grid
        for idx, dev in enumerate(devices):
            key  = f"{dev.ip}:{dev.port}"
            tile = self._tiles[key]
            row, col = divmod(idx, self._cols)
            self._grid.addWidget(tile, row, col)
            tile.show()

    def _refresh_status(self):
        n = len(self._mgr.all_devices())
        self.statusBar().showMessage(f"{n} device(s)  |  port 7777  |  iPhone Farm Monitor")

    def closeEvent(self, event):
        for tile in self._tiles.values():
            tile.cleanup()
        event.accept()
