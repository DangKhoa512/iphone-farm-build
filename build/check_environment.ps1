# =============================================================================
# Kiem tra moi truong va goi y cach build phu hop nhat
# =============================================================================

Write-Host ""
Write-Host "=================================================" -ForegroundColor DarkCyan
Write-Host "  iPhone Farm -- Kiem tra moi truong build"      -ForegroundColor DarkCyan
Write-Host "=================================================" -ForegroundColor DarkCyan
Write-Host ""

$wslScore   = 0
$dockerOK   = $false
$gitOK      = $false

# --- WSL2 ---
Write-Host "[1] WSL2..." -NoNewline
try {
    wsl --status *>$null
    $wslOK = ($LASTEXITCODE -eq 0)
    if (-not $wslOK) {
        $wslOut = wsl --list 2>$null
        $wslOK  = ($LASTEXITCODE -eq 0)
    }

    if ($wslOK) {
        Write-Host " INSTALLED" -ForegroundColor Green
        $wslScore = 1

        $distros = (wsl --list --quiet 2>$null) -join " "
        if ($distros -match "Ubuntu") {
            Write-Host "    Ubuntu: INSTALLED" -ForegroundColor Green
            $wslScore = 2

            # Kiem tra Theos (dung single-quote de PS khong parse bash syntax)
            $theosScript = 'if [ -d "$HOME/theos" ] || [ -d "/opt/theos" ]; then echo YES; else echo NO; fi'
            $theosCheck  = wsl bash -c $theosScript 2>$null
            if ($theosCheck -match "YES") {
                Write-Host "    Theos:  INSTALLED" -ForegroundColor Green
                $wslScore = 3
            } else {
                Write-Host "    Theos:  NOT INSTALLED" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    Ubuntu: NOT INSTALLED" -ForegroundColor Yellow
        }
    } else {
        Write-Host " NOT INSTALLED" -ForegroundColor Yellow
    }
} catch {
    Write-Host " NOT INSTALLED" -ForegroundColor Yellow
}

# --- Docker ---
Write-Host "[2] Docker Desktop..." -NoNewline
try {
    $dockerVer = docker version --format "{{.Server.Version}}" 2>$null
    if ($LASTEXITCODE -eq 0 -and $dockerVer) {
        Write-Host " RUNNING (v$dockerVer)" -ForegroundColor Green
        $dockerOK = $true
    } else {
        Write-Host " NOT RUNNING" -ForegroundColor Yellow
    }
} catch {
    Write-Host " NOT INSTALLED" -ForegroundColor Yellow
}

# --- Git ---
Write-Host "[3] Git..." -NoNewline
try {
    $gitVer = git --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " $gitVer" -ForegroundColor Green
        $gitOK = $true
    } else {
        Write-Host " NOT INSTALLED" -ForegroundColor Yellow
    }
} catch {
    Write-Host " NOT INSTALLED" -ForegroundColor Yellow
}

# --- Goi y ---
Write-Host ""
Write-Host "=================================================" -ForegroundColor DarkCyan
Write-Host "  GOI Y CACH BUILD:"                             -ForegroundColor DarkCyan
Write-Host "=================================================" -ForegroundColor DarkCyan

if ($wslScore -eq 3) {
    Write-Host ""
    Write-Host "  [BEST] Theos da san sang trong WSL!" -ForegroundColor Green
    Write-Host "  Chay ngay:  .\2_build_deb.ps1" -ForegroundColor White

} elseif ($wslScore -ge 1) {
    Write-Host ""
    Write-Host "  [OPTION A] WSL da co, can cai them Theos:" -ForegroundColor Yellow
    Write-Host "  Chay:  .\1_setup_wsl_theos.ps1  (can Administrator)" -ForegroundColor White
    Write-Host "  Sau do: .\2_build_deb.ps1" -ForegroundColor White

} elseif ($dockerOK) {
    Write-Host ""
    Write-Host "  [OPTION B] Dung Docker Desktop:" -ForegroundColor Yellow
    Write-Host "  Chay:  .\2b_build_docker.ps1" -ForegroundColor White

} elseif ($gitOK) {
    Write-Host ""
    Write-Host "  [OPTION C] GitHub Actions (khong can cai gi them):" -ForegroundColor Yellow
    Write-Host "  1. Push code len GitHub"
    Write-Host "  2. Vao tab Actions -> 'Build iPhone DEB' -> Run workflow"
    Write-Host "  3. Tai .deb tu Artifacts"

} else {
    Write-Host ""
    Write-Host "  Chon mot trong cac cach sau:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  A) Cai WSL2 (khuyen nghi):"
    Write-Host "     Chay:  .\1_setup_wsl_theos.ps1  (Administrator)"
    Write-Host ""
    Write-Host "  B) Cai Docker Desktop:"
    Write-Host "     Tai:   docker.com/products/docker-desktop"
    Write-Host "     Sau do: .\2b_build_docker.ps1"
    Write-Host ""
    Write-Host "  C) GitHub Actions (khong can cai gi):"
    Write-Host "     Push len GitHub, dung .github\workflows\build_deb.yml"
}

Write-Host ""
Write-Host "================================================="
