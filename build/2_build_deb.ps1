# Build file .deb — yeu cau da chay 1_setup_wsl_theos.ps1 truoc
# KHONG can quyen Administrator

. "$PSScriptRoot\_common.ps1"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$OutputDir   = Join-Path $ScriptDir "output"

Write-Host ""
Write-Host "=================================================" -ForegroundColor DarkCyan
Write-Host "  iPhone Farm DEB Builder (WSL2)"                  -ForegroundColor DarkCyan
Write-Host "=================================================" -ForegroundColor DarkCyan

$wslTest = wsl echo "ok" 2>$null
if ($wslTest -ne "ok") {
    Write-Host "[ERR] WSL chua san sang. Hay chay 1_setup_wsl_theos.ps1 truoc." -ForegroundColor Red
    exit 1
}

$IosDeb_WSL  = Convert-ToWSLPath (Join-Path $ProjectRoot "ios-deb")
$BuildSh_WSL = Convert-ToWSLPath (Join-Path $ScriptDir "build_inside_wsl.sh")

if (-not $IosDeb_WSL -or $IosDeb_WSL -notmatch "^/") {
    Write-Host "[ERR] Khong the chuyen duong dan sang WSL format." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "`n[>>] Dang build DEB..." -ForegroundColor Cyan
Write-Host ""

wsl bash -c "chmod +x $BuildSh_WSL && bash $BuildSh_WSL $IosDeb_WSL"

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    $deb = Show-BuildResult $OutputDir
    if ($deb) {
        $sizeKB = [math]::Round($deb.Length / 1024, 1)
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host "  BUILD THANH CONG!" -ForegroundColor Green
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host "  $($deb.Name)  ($sizeKB KB)" -ForegroundColor White
        Write-Host ""
        Write-Host "  Cai len iPhone:  .\3_install_to_iphone.ps1"
        Write-Host "  Cai thu cong:    copy .deb vao Filza -> tap de cai"
    } else {
        Write-Host "[ERR] Build OK nhung khong co .deb output." -ForegroundColor Red
    }
} else {
    Write-Host "[ERR] Build that bai (exit $LASTEXITCODE). Xem loi phia tren." -ForegroundColor Red
}
