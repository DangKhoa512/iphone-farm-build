# =============================================================================
# Build DEB bằng Docker Desktop (thay thế cho WSL nếu đã có Docker)
# =============================================================================

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$IosDeb      = Join-Path $ProjectRoot "ios-deb"
$OutputDir   = Join-Path $ScriptDir "output"

# Tạo output dir
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host ""
Write-Host "=== iPhone Farm DEB Builder (Docker) ===" -ForegroundColor Cyan

# Kiểm tra Docker
try {
    docker version | Out-Null
} catch {
    Write-Host "[ERR] Docker Desktop chưa chạy. Hãy mở Docker Desktop trước." -ForegroundColor Red
    exit 1
}

Write-Host "[>>] Building Docker image..." -ForegroundColor Cyan
docker build -t iphone-farm-builder "$ScriptDir"

Write-Host "[>>] Building DEB package..." -ForegroundColor Cyan
docker run --rm `
    -v "${IosDeb}:/project" `
    -v "${OutputDir}:/output" `
    iphone-farm-builder

$debFiles = Get-ChildItem -Path $OutputDir -Filter "*.deb"
if ($debFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "=== BUILD THÀNH CÔNG ===" -ForegroundColor Green
    foreach ($f in $debFiles) {
        Write-Host "  $($f.FullName)" -ForegroundColor White
    }
    Start-Process explorer.exe $OutputDir
} else {
    Write-Host "[ERR] Không tìm thấy .deb output" -ForegroundColor Red
}
