# Chay tu dong sau reboot de hoan tat: Ubuntu -> Theos -> build DEB

. "$PSScriptRoot\_common.ps1"
Add-Type -AssemblyName System.Windows.Forms

$LogFile = "$env:TEMP\iphone-farm-setup.log"
function Log {
    param($msg)
    $line = "$(Get-Date -Format 'HH:mm:ss') $msg"
    $line | Add-Content -Path $LogFile
    Write-Host $line
}

Log "=== iPhone Farm: Tiep tuc sau reboot ==="

# ---------------------------------------------------------------------------
wsl --set-default-version 2 *>$null
if ($LASTEXITCODE -ne 0) { Log "[!] WSL2 set-default that bai, dung WSL1" }

# ---------------------------------------------------------------------------
$distList = (wsl --list --quiet 2>$null | Out-String) -replace "`0", ""
if ($distList -notmatch "Ubuntu") {
    Log "[ERR] Ubuntu chua duoc cai. Chay lai 1_setup_wsl_theos.ps1"
    [System.Windows.Forms.MessageBox]::Show(
        "Ubuntu chua duoc cai.`nVui long chay lai build\1_setup_wsl_theos.ps1",
        "Loi", "OK", "Error")
    exit 1
}
Log "Ubuntu OK"

# ---------------------------------------------------------------------------
# Ghi wsl.conf de Ubuntu dung root mac dinh (khong can sudo vi da la -u root)
$cfgScript = 'printf "[user]\ndefault=root\n" > /etc/wsl.conf && echo DONE'
$cfgOut = wsl -d Ubuntu -u root bash -c $cfgScript 2>$null
if ($cfgOut -notmatch "DONE") { Log "[!] Khong ghi duoc /etc/wsl.conf" }

$testOut = wsl -d Ubuntu -u root bash -c "echo WSLTEST" 2>$null
if ($testOut -notmatch "WSLTEST") {
    Log "[ERR] Khong the chay bash trong Ubuntu"
    [System.Windows.Forms.MessageBox]::Show("Khong the chay Ubuntu. Xem log: $LogFile", "Loi", "OK", "Error")
    exit 1
}
Log "Ubuntu bash OK"

# ---------------------------------------------------------------------------
Log "Cai Theos (co the mat 10-20 phut)..."

$theosScript = @'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>&1 | tail -1
apt-get install -y -qq \
    curl git make clang ca-certificates \
    libplist-utils zip unzip xz-utils bzip2 \
    python3 rsync fakeroot dpkg-dev 2>&1 | tail -3
export THEOS=/opt/theos
if [ ! -d "$THEOS" ]; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
fi
echo 'export THEOS=/opt/theos' > /etc/profile.d/theos.sh
echo 'export PATH=$THEOS/bin:$PATH' >> /etc/profile.d/theos.sh
chmod +x /etc/profile.d/theos.sh
echo "THEOS_SETUP_DONE"
'@

$tmpTheos = "$env:TEMP\install_theos.sh"
($theosScript -replace "`r`n", "`n") | Set-Content -Path $tmpTheos -Encoding UTF8 -NoNewline
$theosWSL = Convert-ToWSLPath $tmpTheos
wsl -d Ubuntu -u root bash $theosWSL
Remove-Item -Path $tmpTheos -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Log "[ERR] Cai Theos that bai"
    [System.Windows.Forms.MessageBox]::Show("Cai Theos that bai. Xem log: $LogFile", "Loi", "OK", "Error")
    exit 1
}
Log "Theos OK"

# ---------------------------------------------------------------------------
Log "Build DEB..."

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$OutputDir   = Join-Path $ScriptDir "output"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$IosDeb_WSL  = Convert-ToWSLPath (Join-Path $ProjectRoot "ios-deb")
$BuildSh_WSL = Convert-ToWSLPath (Join-Path $ScriptDir "build_inside_wsl.sh")

wsl -d Ubuntu -u root bash -c "chmod +x $BuildSh_WSL && bash $BuildSh_WSL $IosDeb_WSL"

if ($LASTEXITCODE -eq 0) {
    $deb = Show-BuildResult $OutputDir
    if ($deb) {
        Log "=== BUILD THANH CONG: $($deb.Name) ==="
        [System.Windows.Forms.MessageBox]::Show(
            "BUILD THANH CONG!`n`nFile: $($deb.Name)`nThu muc: $OutputDir`n`nCai len iPhone bang Filza hoac chay 3_install_to_iphone.ps1",
            "iPhone Farm DEB", "OK", "Information")
    } else {
        Log "[ERR] Build OK nhung khong tim thay .deb trong $OutputDir"
        [System.Windows.Forms.MessageBox]::Show("Build OK nhung khong co .deb output. Xem log: $LogFile", "Loi", "OK", "Error")
    }
} else {
    Log "[ERR] Build that bai"
    [System.Windows.Forms.MessageBox]::Show("Build that bai. Xem log: $LogFile", "Loi", "OK", "Error")
}

Unregister-ScheduledTask -TaskName "iPhoneFarmSetup" -Confirm:$false -ErrorAction SilentlyContinue
Log "=== Hoan tat ==="
