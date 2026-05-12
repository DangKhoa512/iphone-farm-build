# Script tu dong chay sau khi reboot -- dung 1 lan
# Duoc dat lich boi setup_wsl_theos.ps1

$LogFile = "$env:TEMP\iphone-farm-setup.log"
function Log { param($m) $t = Get-Date -Format "HH:mm:ss"; "$t $m" | Tee-Object -FilePath $LogFile -Append | Write-Host }

Log "=== iPhone Farm -- Tiep tuc cai dat sau reboot ==="

# ---------------------------------------------------------------------------
# Dat WSL2 la mac dinh
# ---------------------------------------------------------------------------
Log "[1] Dat WSL2 default version..."
wsl --set-default-version 2
Log "    OK"

# ---------------------------------------------------------------------------
# Cai Ubuntu 22.04
# ---------------------------------------------------------------------------
Log "[2] Cai Ubuntu 22.04 (co the mat 5-10 phut)..."
wsl --install -d Ubuntu-22.04 --no-launch
if ($LASTEXITCODE -ne 0) {
    Log "[!] wsl --install that bai, thu cach khac..."
    # Thu qua wsl store
    wsl --install -d Ubuntu --no-launch
}
Log "    Ubuntu da cai xong"

# Cho Ubuntu khoi dong lan dau
Log "[3] Khoi dong Ubuntu lan dau de setup user..."
$ubuntuSetup = @'
#!/usr/bin/env bash
# Tao user mac dinh khong can tuong tac (cho automation)
echo "root:farm2024" | chpasswd 2>/dev/null || true
echo "Ubuntu setup done"
'@
$tmpInit = "$env:TEMP\ubuntu_init.sh"
$ubuntuSetup | Set-Content -Path $tmpInit -Encoding UTF8 -NoNewline
$wslPath = wsl wslpath -u ($tmpInit -replace "\\", "/")
wsl -d Ubuntu-22.04 bash $wslPath 2>$null
Log "    Ubuntu ready"

# ---------------------------------------------------------------------------
# Cai Theos
# ---------------------------------------------------------------------------
Log "[4] Cai Theos trong Ubuntu WSL..."

$theosScript = @'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Cap nhat apt ==="
sudo apt-get update -qq 2>&1 | tail -2

echo "=== Cai packages ==="
sudo apt-get install -y -qq \
    curl git make clang ca-certificates \
    libplist-utils zip unzip xz-utils bzip2 \
    python3 rsync fakeroot dpkg-dev 2>&1 | tail -5

echo "=== Cai Theos ==="
if [ ! -d "$HOME/theos" ]; then
    export THEOS="$HOME/theos"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
else
    echo "Theos da co"
fi

# Set env
grep -q "THEOS" "$HOME/.bashrc" 2>/dev/null || {
    echo 'export THEOS=$HOME/theos' >> "$HOME/.bashrc"
    echo 'export PATH=$THEOS/bin:$PATH' >> "$HOME/.bashrc"
}

echo "THEOS_SETUP_DONE"
'@

$tmpTheos = "$env:TEMP\install_theos.sh"
$theosScript -replace "`r`n", "`n" | Set-Content -Path $tmpTheos -Encoding UTF8 -NoNewline
$theosWSL = wsl wslpath -u ($tmpTheos -replace "\\", "/")
wsl -d Ubuntu-22.04 bash $theosWSL

if ($LASTEXITCODE -eq 0) {
    Log "    Theos cai xong!"
} else {
    Log "[ERR] Theos that bai"
    exit 1
}

# ---------------------------------------------------------------------------
# Build DEB
# ---------------------------------------------------------------------------
Log "[5] Build DEB..."

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$IosDeb      = Join-Path $ProjectRoot "ios-deb"
$BuildSh     = Join-Path $ScriptDir "build_inside_wsl.sh"

$IosDeb_WSL  = wsl wslpath -u ($IosDeb  -replace "\\", "/")
$BuildSh_WSL = wsl wslpath -u ($BuildSh -replace "\\", "/")
wsl -d Ubuntu-22.04 chmod +x $BuildSh_WSL

wsl -d Ubuntu-22.04 bash $BuildSh_WSL $IosDeb_WSL

if ($LASTEXITCODE -eq 0) {
    Log "=== BUILD THANH CONG! ==="
    $OutputDir = Join-Path $ScriptDir "output"
    Start-Process explorer.exe $OutputDir
    [System.Windows.Forms.MessageBox]::Show(
        "iPhone Farm DEB da build xong!`nFile .deb trong:`n$OutputDir",
        "Build Thanh Cong", "OK", "Information")
} else {
    Log "[ERR] Build that bai"
}

# Xoa task sau khi chay
Unregister-ScheduledTask -TaskName "iPhoneFarmSetup" -Confirm:$false -ErrorAction SilentlyContinue
