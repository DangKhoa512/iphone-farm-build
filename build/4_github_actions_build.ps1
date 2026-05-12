# =============================================================================
# Build DEB bang GitHub Actions (khong can reboot)
# Can: tai khoan GitHub + internet
# =============================================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Build DEB qua GitHub Actions"                   -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

$projectDir = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# Buoc 1: Lay thong tin GitHub
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[1] Thong tin GitHub" -ForegroundColor Cyan
$ghUser  = Read-Host "    GitHub username"
$ghRepo  = Read-Host "    Ten repo moi (vd: iphone-farm)"
$ghToken = Read-Host "    Personal Access Token (github.com -> Settings -> Developer settings -> PAT -> Classic -> repo scope)" -AsSecureString
$plainToken = [System.Net.NetworkCredential]::new("", $ghToken).Password

if (-not $ghUser -or -not $ghRepo -or -not $plainToken) {
    Write-Host "[ERR] Thieu thong tin" -ForegroundColor Red; exit 1
}

# ---------------------------------------------------------------------------
# Buoc 2: Tao repo tren GitHub qua API
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[2] Tao repo GitHub: $ghUser/$ghRepo ..." -ForegroundColor Cyan

$headers = @{
    Authorization = "token $plainToken"
    Accept        = "application/vnd.github.v3+json"
    "User-Agent"  = "iphone-farm-builder"
}

$body = @{ name = $ghRepo; private = $false; auto_init = $false } | ConvertTo-Json
try {
    $resp = Invoke-RestMethod -Uri "https://api.github.com/user/repos" `
        -Method POST -Headers $headers -Body $body -ContentType "application/json"
    Write-Host "    Tao repo OK: $($resp.html_url)" -ForegroundColor Green
    $repoUrl = $resp.clone_url
} catch {
    # Repo co the da ton tai
    $repoUrl = "https://github.com/$ghUser/$ghRepo.git"
    Write-Host "    [!] Repo co the da ton tai, dung: $repoUrl" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Buoc 3: Push code
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[3] Push code len GitHub..." -ForegroundColor Cyan

cd $projectDir

# Them remote (bo qua neu da co)
git remote remove origin 2>$null
$authUrl = "https://${ghUser}:${plainToken}@github.com/$ghUser/$ghRepo.git"
git remote add origin $authUrl

# Push
git branch -M main 2>$null
git push -u origin main --force 2>&1 | Select-Object -Last 5

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERR] Push that bai" -ForegroundColor Red; exit 1
}
Write-Host "    Push OK" -ForegroundColor Green

# Xoa token khoi remote URL (bao mat)
git remote set-url origin "https://github.com/$ghUser/$ghRepo.git"

# ---------------------------------------------------------------------------
# Buoc 4: Kich hoat workflow
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4] Kich hoat GitHub Actions workflow..." -ForegroundColor Cyan
Start-Sleep -Seconds 3   # cho GitHub xu ly push

$wfBody = @{ ref = "main" } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$ghUser/$ghRepo/actions/workflows/build_deb.yml/dispatches" `
        -Method POST -Headers $headers -Body $wfBody -ContentType "application/json"
    Write-Host "    Workflow da chay!" -ForegroundColor Green
} catch {
    Write-Host "    [!] Workflow tu chay khi push (khong can trigger thu cong)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Buoc 5: Theo doi va tai artifact
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[5] Doi build hoan thanh (co the mat 5-10 phut)..." -ForegroundColor Cyan
Write-Host "    Xem tren: https://github.com/$ghUser/$ghRepo/actions"
Write-Host ""

$outputDir = Join-Path $PSScriptRoot "output"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$maxWait = 600   # giay
$waited  = 0
$runId   = $null

while ($waited -lt $maxWait) {
    Start-Sleep -Seconds 10
    $waited += 10

    try {
        $runs = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/$ghUser/$ghRepo/actions/runs?per_page=5" `
            -Headers $headers
        $run = $runs.workflow_runs | Where-Object { $_.name -match "Build" -or $_.path -match "build_deb" } |
               Select-Object -First 1

        if ($run) {
            $runId = $run.id
            Write-Host "    [$waited s] Status: $($run.status) | Conclusion: $($run.conclusion)" -ForegroundColor Gray

            if ($run.status -eq "completed") {
                if ($run.conclusion -eq "success") {
                    Write-Host "    Build THANH CONG! Dang tai artifact..." -ForegroundColor Green
                    break
                } else {
                    Write-Host "[ERR] Build that bai: $($run.conclusion)" -ForegroundColor Red
                    Write-Host "      Chi tiet: https://github.com/$ghUser/$ghRepo/actions/runs/$runId"
                    exit 1
                }
            }
        }
    } catch { }
}

# Tai artifact
if ($runId) {
    try {
        $artifacts = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/$ghUser/$ghRepo/actions/runs/$runId/artifacts" `
            -Headers $headers
        $artifact = $artifacts.artifacts | Where-Object { $_.name -match "deb" } | Select-Object -First 1

        if ($artifact) {
            $zipPath = "$outputDir\iphone-farm-deb.zip"
            Invoke-WebRequest -Uri $artifact.archive_download_url `
                -Headers $headers -OutFile $zipPath
            Expand-Archive -Path $zipPath -DestinationPath $outputDir -Force
            Remove-Item $zipPath

            $debFiles = Get-ChildItem $outputDir -Filter "*.deb"
            Write-Host ""
            Write-Host "=================================================" -ForegroundColor Green
            Write-Host "  DEB DA TAI XONG!" -ForegroundColor Green
            Write-Host "=================================================" -ForegroundColor Green
            foreach ($f in $debFiles) {
                Write-Host "  $($f.FullName)" -ForegroundColor White
            }
            Start-Process explorer.exe $outputDir
        }
    } catch {
        Write-Host "[!] Tai artifact that bai. Vao GitHub de tai thu cong:"
        Write-Host "    https://github.com/$ghUser/$ghRepo/actions/runs/$runId"
    }
}
