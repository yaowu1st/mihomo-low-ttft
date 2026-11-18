<#
.SYNOPSIS
    Restore Clash Verge Rev global configs from the latest (or specified) backup snapshot.
#>

[CmdletBinding()]
param(
    [string]$ConfigDir = "$env:APPDATA\io.github.clash-verge-rev.clash-verge-rev",
    [string]$BackupFolder = ""
)

$ErrorActionPreference = "Stop"
$BackupRoot = Join-Path $ConfigDir "clash-verge-rev-backup"

if (-not $BackupFolder) {
    $Latest = Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -like "low-ttft-backup-*" } |
              Sort-Object LastWriteTime -Descending |
              Select-Object -First 1
    if (-not $Latest) {
        throw "No low-ttft backup directory found under: $BackupRoot"
    }
    $BackupFolder = $Latest.FullName
}

if (-not (Test-Path $BackupFolder)) {
    throw "Specified backup folder does not exist: $BackupFolder"
}

$Map = @(
    @{ Bak = Join-Path $BackupFolder "Merge.yaml";      Dst = Join-Path $ConfigDir "profiles\Merge.yaml" },
    @{ Bak = Join-Path $BackupFolder "Script.js";       Dst = Join-Path $ConfigDir "profiles\Script.js" },
    @{ Bak = Join-Path $BackupFolder "dns_config.yaml"; Dst = Join-Path $ConfigDir "dns_config.yaml" }
)

foreach ($m in $Map) {
    if (Test-Path $m.Bak) {
        Copy-Item -Path $m.Bak -Destination $m.Dst -Force
        Write-Host "[Restored] $($m.Dst)" -ForegroundColor Yellow
    }
}

Write-Host "[OK] Restored from backup: $BackupFolder . Reload your profile in Clash Verge Rev." -ForegroundColor Green
