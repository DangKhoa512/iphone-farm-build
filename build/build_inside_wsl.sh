#!/usr/bin/env bash
# Chạy bên trong WSL — được gọi tự động bởi 2_build_deb.ps1
set -e

PROJECT_DIR="$1"   # đường dẫn WSL đến ios-deb/

echo ""
echo "=================================================="
echo "  iPhone Farm DEB Builder"
echo "=================================================="
echo "  Project: $PROJECT_DIR"
echo ""

# Xác định thư mục Theos
if   [ -d "$HOME/theos" ];  then THEOS_DIR="$HOME/theos"
elif [ -d "/opt/theos"  ];  then THEOS_DIR="/opt/theos"
else
    echo "[ERR] Không tìm thấy Theos. Hãy chạy 1_setup_wsl_theos.ps1 trước."
    exit 1
fi
export THEOS="$THEOS_DIR"
export PATH="$THEOS/bin:$PATH"
echo "  THEOS = $THEOS"

# ---------------------------------------------------------------------------
# Vào thư mục ios-deb
# ---------------------------------------------------------------------------
cd "$PROJECT_DIR"

# Tự động tải SDK nếu chưa có
SDK_DIR="$THEOS/sdks"
if [ -z "$(ls -A "$SDK_DIR" 2>/dev/null)" ]; then
    echo ""
    echo "[>>] Tải iOS SDK (lần đầu)..."
    git clone --depth=1 https://github.com/theos/sdks "$SDK_DIR" 2>&1 | tail -5
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo ""
echo "[>>] Cleaning..."
make clean 2>/dev/null || true

echo ""
echo "[>>] Building DEB..."
make package FINALPACKAGE=1 2>&1

# ---------------------------------------------------------------------------
# Tìm file DEB output
# ---------------------------------------------------------------------------
DEB_FILE=$(find packages/ -name "*.deb" -newer Makefile 2>/dev/null | head -1)

if [ -z "$DEB_FILE" ]; then
    # Theos rootless packages/
    DEB_FILE=$(find . -name "*.deb" 2>/dev/null | head -1)
fi

if [ -n "$DEB_FILE" ]; then
    echo ""
    echo "=================================================="
    echo "  [OK] Build thành công!"
    echo "  File: $PROJECT_DIR/$DEB_FILE"
    echo "=================================================="
    # Copy sang thư mục build/ output
    mkdir -p "$PROJECT_DIR/../build/output"
    cp "$DEB_FILE" "$PROJECT_DIR/../build/output/"
    echo "  Đã copy sang: build/output/$(basename $DEB_FILE)"
else
    echo "[ERR] Không tìm thấy .deb file sau khi build"
    exit 1
fi
