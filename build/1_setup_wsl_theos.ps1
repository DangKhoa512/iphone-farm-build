# =============================================================================
# iPhone Farm -- Buoc 1: Cai WSL2 + Ubuntu + Theos
# Can chay voi quyen Administrator:
#   Right-click script -> "Run as administrator"
# =============================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "`n[>>] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "[ OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[!]  $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "[ERR] $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=================================================" -ForegroundColor DarkCyan
Write-Host "  iPhone Farm -- Setup WSL2 + Theos"             -ForegroundColor DarkCyan
Write-Host "=================================================" -ForegroundColor DarkCyan

# ---------------------------------------------------------------------------
# 1. Bat WSL + VirtualMachinePlatform
# ---------------------------------------------------------------------------
Write-Step "Kiem tra / bat WSL2..."

$wslState = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State
$vmpState = (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State

$needReboot = $false

if ($wslState -ne "Enabled") {
    Write-Warn "Dang bat Windows Subsystem for Linux..."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
    $needReboot = $true
}

if ($vmpState -ne "Enabled") {
    Write-Warn "Dang bat Virtual Machine Platform..."
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
    $needReboot = $true
}

if ($needReboot) {
    Write-Host ""
    Write-Host "  [!] Can REBOOT de hoan tat. Sau khi reboot chay lai script nay." -ForegroundColor Yellow
    $r = Read-Host "  Reboot ngay? (y/n)"
    if ($r -eq "y") { Restart-Computer -Force }
    exit 0
}

Write-OK "WSL feature da bat"

# Dat WSL2 la mac dinh
wsl --set-default-version 2
Write-OK "WSL2 la phien ban mac dinh"

# ---------------------------------------------------------------------------
# 2. Cai Ubuntu 22.04 neu chua co
# ---------------------------------------------------------------------------
Write-Step "Kiem tra Ubuntu 22.04..."

# Lay danh sach distro (PS5.1: stdout tu native cmd co the co BOM/null chars)
$rawList  = wsl --list --quiet 2>$null
$distroList = ($rawList | Out-String) -replace "`0", ""
$hasUbuntu  = $distroList -match "Ubuntu"

if (-not $hasUbuntu) {
    Write-Warn "Chua co Ubuntu. Dang cai Ubuntu 22.04 (co the mat 5-10 phut)..."
    Write-Host ""
    Write-Host "  [!] Sau khi cua so Ubuntu mo ra:" -ForegroundColor Yellow
    Write-Host "      1. Tao username va password (nho mat khau nay!)" -ForegroundColor Yellow
    Write-Host "      2. Dong cua so Ubuntu lai"  -ForegroundColor Yellow
    Write-Host "      3. Chay lai script nay" -ForegroundColor Yellow
    Write-Host ""
    Start-Process "wsl" -ArgumentList "--install -d Ubuntu-22.04" -Wait
    exit 0
} else {
    Write-OK "Ubuntu da co san"
}

# ---------------------------------------------------------------------------
# 3. Cai Theos trong Ubuntu
# ---------------------------------------------------------------------------
Write-Step "Cai Theos trong WSL Ubuntu (co the mat 10-20 phut lan dau)..."

# Viet script bash ra file tam (tranh van de encoding qua pipeline)
$bashScript = @'
#!/usr/bin/env bash
set -e

echo ""
echo "=== [1/4] Cap nhat apt ==="
sudo apt-get update -qq

echo ""
echo "=== [2/4] Cai dependencies ==="
sudo apt-get install -y -qq \
    curl git make clang ca-certificates \
    libplist-utils zip unzip xz-utils bzip2 \
    python3 rsync fakeroot dpkg-dev pkg-config

echo ""
echo "=== [3/4] Cai Theos ==="
if [ -d "$HOME/theos" ]; then
    echo "Theos da co tai $HOME/theos -- cap nhat..."
    git -C "$HOME/theos" pull --ff-only 2>&1 | tail -3
else
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
fi

echo ""
echo "=== [4/4] Thiet lap bien moi truong ==="
if ! grep -q "THEOS" "$HOME/.bashrc" 2>/dev/null; then
    echo 'export THEOS=$HOME/theos'  >> "$HOME/.bashrc"
    echo 'export PATH=$THEOS/bin:$PATH' >> "$HOME/.bashrc"
    echo "Da them THEOS vao .bashrc"
else
    echo "THEOS da co trong .bashrc"
fi

echo ""
THEOS_BIN="$HOME/theos/bin"
if [ -d "$THEOS_BIN" ] || [ -d "/opt/theos/bin" ]; then
    echo "=============================="
    echo "  Theos cai thanh cong!"
    echo "=============================="
else
    echo "[!] Khong tim thay thu muc theos -- vui long kiem tra loi ben tren"
    exit 1
fi
'@

$tmpFile = "$env:TEMP\setup_theos.sh"
# Ghi file voi LF line endings (bash yeu cau)
$bashScript.Replace("`r`n", "`n") | Set-Content -Path $tmpFile -Encoding UTF8 -NoNewline

# Chuyen path sang WSL format
$wslPath = wsl wslpath -u ($tmpFile -replace "\\", "/")

# Chay trong WSL
wsl bash $wslPath

if ($LASTEXITCODE -ne 0) {
    Write-Fail "Cai Theos that bai. Xem loi ben tren."
}

Write-OK "Theos da cai xong!"
Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  SETUP HOAN TAT!"                               -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  Buoc tiep theo: chay  2_build_deb.ps1"
Write-Host ""
