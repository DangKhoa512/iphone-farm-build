# =============================================================================
# iPhone Farm -- Buoc 3: Cai DEB len iPhone qua SSH
# iPhone can: jailbreak + OpenSSH installed + cung WiFi voi PC
#
# Cach dung SSH key (khong can nhap password moi lan):
#   ssh-keygen -t ed25519         (tao key neu chua co)
#   ssh-copy-id root@IP_IPHONE   (copy key len iPhone 1 lan)
# =============================================================================

param(
    [string]      $IPhoneIP = "",
    [string]      $SSHPort  = "22",
    [SecureString]$Password = $null   # Bo trong de dung SSH key (khuyen nghi)
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputDir = Join-Path $ScriptDir "output"

Write-Host ""
Write-Host "=================================================" -ForegroundColor DarkCyan
Write-Host "  iPhone Farm -- Cai DEB len iPhone"             -ForegroundColor DarkCyan
Write-Host "=================================================" -ForegroundColor DarkCyan

# ---------------------------------------------------------------------------
# Kiem tra OpenSSH client
# ---------------------------------------------------------------------------
$scpCmd = Get-Command scp -ErrorAction SilentlyContinue
$sshCmd = Get-Command ssh -ErrorAction SilentlyContinue

if (-not $scpCmd -or -not $sshCmd) {
    Write-Host "[ERR] Khong tim thay 'scp'/'ssh'." -ForegroundColor Red
    Write-Host "      Cai OpenSSH Client:"
    Write-Host "      Settings -> Apps -> Optional Features -> Add -> OpenSSH Client"
    exit 1
}

# ---------------------------------------------------------------------------
# Tim file .deb moi nhat
# ---------------------------------------------------------------------------
$debFiles = Get-ChildItem -Path $OutputDir -Filter "*.deb" -ErrorAction SilentlyContinue
if (-not $debFiles -or $debFiles.Count -eq 0) {
    Write-Host "[ERR] Khong tim thay .deb trong build\output\" -ForegroundColor Red
    Write-Host "      Hay chay 2_build_deb.ps1 truoc."
    exit 1
}
$deb = $debFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "  DEB: $($deb.Name)"

# ---------------------------------------------------------------------------
# Hoi IP neu chua co
# ---------------------------------------------------------------------------
if (-not $IPhoneIP) {
    $IPhoneIP = Read-Host "`n  Nhap IP iPhone (vd: 192.168.1.100)"
}
$IPhoneIP = $IPhoneIP.Trim()
Write-Host "  Target: root@${IPhoneIP}:${SSHPort}"

# ---------------------------------------------------------------------------
# Xac dinh SSH options
# Neu co Password thi dung sshpass (trong WSL); neu khong thi dung SSH key
# ---------------------------------------------------------------------------
$useSSHKey  = $true
$sshKeyArgs = @("-p", $SSHPort, "-o", "StrictHostKeyChecking=no")

if ($Password) {
    # Chuyen SecureString -> plain text de truyen vao sshpass qua WSL
    $plain = [System.Net.NetworkCredential]::new("", $Password).Password
    # Chay sshpass qua WSL de tranh luu password trong process list
    $useSSHKey = $false
    Write-Host "  Auth: password (qua sshpass trong WSL)"
} else {
    Write-Host "  Auth: SSH key (nhap password thu cong neu duoc hoi)"
}
Write-Host ""

# ---------------------------------------------------------------------------
# SCP upload
# ---------------------------------------------------------------------------
Write-Host "[>>] Upload .deb len iPhone..." -ForegroundColor Cyan

if ($useSSHKey) {
    scp @sshKeyArgs $deb.FullName "root@${IPhoneIP}:/tmp/$($deb.Name)"
    $scpExit = $LASTEXITCODE
} else {
    # Dung WSL sshpass de khong lo password trong command line Windows
    $debWslPath = wsl wslpath -u ($deb.FullName -replace "\\", "/")
    $sshpassCmd = "sshpass -p '$plain' scp -P $SSHPort -o StrictHostKeyChecking=no '$debWslPath' 'root@${IPhoneIP}:/tmp/$($deb.Name)'"
    wsl bash -c $sshpassCmd
    $scpExit = $LASTEXITCODE
}

if ($scpExit -ne 0) {
    Write-Host "[ERR] Upload that bai. Kiem tra:" -ForegroundColor Red
    Write-Host "  - IP dung chua? ($IPhoneIP)"
    Write-Host "  - OpenSSH da cai tren iPhone chua?"
    Write-Host "  - iPhone cung WiFi voi PC chua?"
    exit 1
}
Write-Host "  Upload OK"

# ---------------------------------------------------------------------------
# SSH: cai dat tren iPhone
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[>>] Cai dat tren iPhone..." -ForegroundColor Cyan

# Lenh bash chay tren iPhone
$remoteInstall = "dpkg -i /tmp/$($deb.Name); launchctl unload /Library/LaunchDaemons/com.iphone-farm.server.plist 2>/dev/null; launchctl load /Library/LaunchDaemons/com.iphone-farm.server.plist; echo INSTALL_OK"

if ($useSSHKey) {
    ssh @sshKeyArgs "root@${IPhoneIP}" $remoteInstall
    $sshExit = $LASTEXITCODE
} else {
    $sshpassCmd2 = "sshpass -p '$plain' ssh -p $SSHPort -o StrictHostKeyChecking=no root@${IPhoneIP} '$remoteInstall'"
    wsl bash -c $sshpassCmd2
    $sshExit = $LASTEXITCODE
}

# ---------------------------------------------------------------------------
# Ket qua
# ---------------------------------------------------------------------------
if ($sshExit -eq 0) {
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "  CAI XONG!"                                      -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "  Server dang chay tai: http://${IPhoneIP}:7777"
    Write-Host ""
    Write-Host "  Kiem tra: curl http://${IPhoneIP}:7777/info"
    Write-Host ""
    Write-Host "  Mo PC tool:"
    Write-Host "    cd ..\pc-tool"
    Write-Host "    python main.py --devices $IPhoneIP"
} else {
    Write-Host "[ERR] Cai dat that bai (exit $sshExit). Xem loi phia tren." -ForegroundColor Red
}
