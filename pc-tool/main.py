"""
iPhone Farm Monitor — entry point
Usage:  python main.py [--devices ip1 ip2 ...] [--port 7777] [--cols 4]
"""

import sys
import argparse
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore    import Qt
from ui.main_window  import FarmWindow


def parse_args():
    p = argparse.ArgumentParser(description="iPhone Farm Monitor")
    p.add_argument("--devices", nargs="*", default=[],
                   metavar="IP", help="Auto-add devices on startup")
    p.add_argument("--port",    type=int,  default=7777,  help="Default server port")
    p.add_argument("--cols",    type=int,  default=4,     help="Grid columns")
    return p.parse_args()


def main():
    args = parse_args()

    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setApplicationName("iPhone Farm Monitor")

    # Dark palette
    from PyQt6.QtGui import QPalette, QColor
    pal = QPalette()
    pal.setColor(QPalette.ColorRole.Window,          QColor(17, 17, 17))
    pal.setColor(QPalette.ColorRole.WindowText,      QColor(220, 220, 220))
    pal.setColor(QPalette.ColorRole.Base,            QColor(30, 30, 30))
    pal.setColor(QPalette.ColorRole.AlternateBase,   QColor(25, 25, 25))
    pal.setColor(QPalette.ColorRole.Text,            QColor(220, 220, 220))
    pal.setColor(QPalette.ColorRole.Button,          QColor(45, 45, 45))
    pal.setColor(QPalette.ColorRole.ButtonText,      QColor(220, 220, 220))
    pal.setColor(QPalette.ColorRole.Highlight,       QColor(21, 101, 192))
    pal.setColor(QPalette.ColorRole.HighlightedText, QColor(255, 255, 255))
    app.setPalette(pal)

    win = FarmWindow()
    win._cols_spin.setValue(args.cols)

    # Auto-add devices passed via CLI
    if args.devices:
        import threading
        def _add_all():
            for ip in args.devices:
                win._mgr.add_device(ip.strip(), args.port)
        threading.Thread(target=_add_all, daemon=True).start()

    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
