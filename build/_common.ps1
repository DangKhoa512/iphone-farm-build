# Shared helpers — dot-source this file at the top of build scripts:
#   . "$PSScriptRoot\_common.ps1"

function Convert-ToWSLPath {
    param([string]$WindowsPath)
    wsl wslpath -u ($WindowsPath -replace "\\", "/")
}

function Show-BuildResult {
    param([string]$OutputDir)
    $debFiles = Get-ChildItem -Path $OutputDir -Filter "*.deb" -ErrorAction SilentlyContinue
    if ($debFiles.Count -gt 0) {
        Start-Process explorer.exe $OutputDir
        return $debFiles[0]
    }
    return $null
}
