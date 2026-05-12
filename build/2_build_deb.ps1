# =============================================================================
# iPhone Farm -- Buoc 2: Build file .deb
# Yeu cau da chay 1_setup_wsl_theos.ps1 truoc
# KHONG can quyen Administrator
# =============================================================================

$ErrorActionPreference = "Continue"

function Write-Step { param($msg) Write-Host "`n[>>] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "[ OK] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "[ERR] $msg" -ForegroundColor Red }

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$IosDeb      = Join-Path $ProjectRoot "ios-deb"
$BuildSh     = Join-Path $ScriptDir "build_inside_wsl.sh"
$OutputDir   = Join-Path $ScriptDir "output"

Write-Host ""
Write-Host "=================================================" -ForegroundColor DarkCyan
Write-Host "  iPhone Farm DEB Builder (WSL2)"                  -ForegroundColor DarkCyan
Write-Host "=================================================" -ForegroundColor DarkCyan

# ---------------------------------------------------------------------------
# Kiem tra WSL
# ---------------------------------------------------------------------------
Write-Step "Kiem tra WSL2..."
$wslTest = wsl echo "ok" 2>$null
if ($wslTest -ne "ok") {
    Write-Fail "WSL2 chua san sang. Hay chay 1_setup_wsl_theos.ps1 truoc."
    exit 1
}
Write-OK "WSL2 OK"

# ---------------------------------------------------------------------------
# Chuyen duong dan Windows -> WSL
# ---------------------------------------------------------------------------
Write-Step "Chuan bi duong dan..."

# Thay \ thanh / truoc khi chuyen
$IosDeb_Win  = $IosDeb  -replace "\\", "/"
$BuildSh_Win = $BuildSh -replace "\\", "/"

$IosDeb_WSL  = wsl wslpath -u $IosDeb_Win
$BuildSh_WSL = wsl wslpath -u $BuildSh_Win

Write-Host "  ios-deb: $IosDeb_WSL"

if (-not $IosDeb_WSL -or $IosDeb_WSL -notmatch "^/") {
    Write-Fail "Khong the chuyen duong dan sang WSL format."
    exit 1
}

# Gan quyen thuc thi cho build script
wsl chmod +x $BuildSh_WSL

# ---------------------------------------------------------------------------
# Tao output dir
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# ---------------------------------------------------------------------------
# Chay build
# ---------------------------------------------------------------------------
Write-Step "Dang build DEB (co the mat 1-3 phut)..."
Write-Host ""

wsl bash $BuildSh_WSL $IosDeb_WSL

$buildExit = $LASTEXITCODE

# ---------------------------------------------------------------------------
# Ket qua
# ---------------------------------------------------------------------------
Write-Host ""
if ($buildExit -eq 0) {
    $debFiles = Get-ChildItem -Path $OutputDir -Filter "*.deb" -ErrorAction SilentlyContinue
    if ($debFiles.Count -gt 0) {
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host "  BUILD THANH CONG!"                              -ForegroundColor Green
        Write-Host "=================================================" -ForegroundColor Green
        foreach ($f in $debFiles) {
            $sizeKB = [math]::Round($f.Length / 1024, 1)
            Write-Host "  $($f.Name)  ($sizeKB KB)" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  Cai len iPhone (WiFi + SSH):"
        Write-Host "    .\3_install_to_iphone.ps1"
        Write-Host ""
        Write-Host "  Cai thu cong: Copy .deb vao Filza -> tap de cai"
        Write-Host ""
        # Mo thu muc output
        Start-Process explorer.exe $OutputDir
    } else {
        Write-Fail "Build script thanh cong nhung khong co .deb output."
    }
} else {
    Write-Fail "Build that bai (exit code $buildExit). Xem loi phia tren."
}
