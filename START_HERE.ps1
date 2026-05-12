# =============================================================================
# iPhone Farm -- Huong dan nhanh
# Double-click file nay de bat dau
# =============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   iPhone Farm Monitor -- Start Here"    -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Chon buoc ban muon thuc hien:" -ForegroundColor White
Write-Host ""
Write-Host "  [1] Kiem tra moi truong build"
Write-Host "  [2] Cai WSL2 + Theos  (can Administrator, chay 1 lan)"
Write-Host "  [3] Build file .deb"
Write-Host "  [4] Cai DEB len iPhone qua SSH"
Write-Host "  [5] Chay PC Tool (farm monitor)"
Write-Host "  [6] Xem huong dan GitHub Actions"
Write-Host "  [Q] Thoat"
Write-Host ""

$choice = Read-Host "  Nhap lua chon"

$BuildDir = Join-Path $PSScriptRoot "build"

switch ($choice.ToUpper()) {
    "1" {
        powershell -ExecutionPolicy Bypass -File (Join-Path $BuildDir "check_environment.ps1")
    }
    "2" {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$(Join-Path $BuildDir '1_setup_wsl_theos.ps1')`"" -Verb RunAs
    }
    "3" {
        powershell -ExecutionPolicy Bypass -File (Join-Path $BuildDir "2_build_deb.ps1")
    }
    "4" {
        powershell -ExecutionPolicy Bypass -File (Join-Path $BuildDir "3_install_to_iphone.ps1")
    }
    "5" {
        $pcTool = Join-Path $PSScriptRoot "pc-tool"
        Write-Host ""
        Write-Host "  Chay lenh sau:" -ForegroundColor Green
        Write-Host "    cd $pcTool"
        Write-Host "    pip install -r requirements.txt"
        Write-Host "    python main.py"
        Write-Host ""
        Set-Location $pcTool
        Write-Host "  Da chuyen vao thu muc pc-tool. Chay: python main.py"
    }
    "6" {
        Write-Host ""
        Write-Host "  === GitHub Actions ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1. Tao repo GitHub moi (neu chua co):"
        Write-Host "     git init"
        Write-Host "     git remote add origin https://github.com/TEN/iphone-farm.git"
        Write-Host ""
        Write-Host "  2. Push code len GitHub:"
        Write-Host "     git add ."
        Write-Host "     git commit -m 'initial'"
        Write-Host "     git push -u origin main"
        Write-Host ""
        Write-Host "  3. Tren GitHub: vao tab Actions -> 'Build iPhone DEB' -> Run workflow"
        Write-Host ""
        Write-Host "  4. Sau khi chay xong, tai .deb tu Artifacts (goc phai man hinh)"
        Write-Host ""
        Write-Host "  File workflow: .github\workflows\build_deb.yml"
    }
    "Q" { exit 0 }
    default {
        Write-Host "  Lua chon khong hop le." -ForegroundColor Yellow
    }
}

Write-Host ""
pause
