<#
.SYNOPSIS
    Back up existing Clash Verge Rev global configs, deploy Universal Low-TTFT Mihomo configs,
    and run syntax/schema verification with verge-mihomo / mihomo.
#>

[CmdletBinding()]
param(
    [string]$ConfigDir = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ConfigSrc = Join-Path $RepoRoot "config"

# 1. Auto-detect Clash Verge Rev config directory (Standard AppData or Portable mode)
if (-not $ConfigDir) {
    $Candidates = @(
        "$env:APPDATA\io.github.clash-verge-rev.clash-verge-rev",
        "$env:USERPROFILE\.config\clash-verge"
    )
    $RunningGui = Get-Process -Name "clash-verge" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($RunningGui -and $RunningGui.Path) {
        $PortableDir = Join-Path (Split-Path -Parent $RunningGui.Path) ".config\io.github.clash-verge-rev.clash-verge-rev"
        $Candidates = @($PortableDir) + $Candidates
    }
    $ConfigDir = $Candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if (-not $ConfigDir -or -not (Test-Path $ConfigDir)) {
    throw "Clash Verge Rev config directory not found. Pass -ConfigDir '<path>' explicitly."
}

# 2. Timestamped backup
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $ConfigDir "clash-verge-rev-backup\low-ttft-backup-$Timestamp"
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ConfigDir "profiles") -Force | Out-Null

$Targets = @(
    @{ Src = Join-Path $ConfigSrc "Merge.yaml";      Dst = Join-Path $ConfigDir "profiles\Merge.yaml"; Bak = Join-Path $BackupDir "Merge.yaml" },
    @{ Src = Join-Path $ConfigSrc "Script.js";       Dst = Join-Path $ConfigDir "profiles\Script.js";  Bak = Join-Path $BackupDir "Script.js" },
    @{ Src = Join-Path $ConfigSrc "dns_config.yaml"; Dst = Join-Path $ConfigDir "dns_config.yaml";     Bak = Join-Path $BackupDir "dns_config.yaml" }
)

foreach ($t in $Targets) {
    if (Test-Path $t.Dst) {
        Copy-Item -Path $t.Dst -Destination $t.Bak -Force
    }
    Copy-Item -Path $t.Src -Destination $t.Dst -Force
}

Write-Host "[OK] Backed up previous configs to: $BackupDir" -ForegroundColor Green
Write-Host "[OK] Deployed Merge.yaml, Script.js, and dns_config.yaml to: $ConfigDir" -ForegroundColor Green

# 3. Auto-discover verge-mihomo.exe / mihomo.exe for config validation
$BinCandidates = @()
foreach ($procName in @("verge-mihomo", "clash-verge", "mihomo")) {
    $p = Get-Process -Name $procName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p -and $p.Path) {
        $dir = Split-Path -Parent $p.Path
        $BinCandidates += (Join-Path $dir "verge-mihomo.exe")
        $BinCandidates += (Join-Path $dir "mihomo.exe")
    }
}
$RegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$InstallLoc = Get-ItemProperty $RegPaths -ErrorAction SilentlyContinue |
              Where-Object { $_.DisplayName -match "Clash Verge" -and $_.InstallLocation } |
              Select-Object -ExpandProperty InstallLocation -First 1
if ($InstallLoc) {
    $BinCandidates += (Join-Path $InstallLoc "verge-mihomo.exe")
}
$BinCandidates += @(
    "$env:ProgramFiles\Clash Verge\verge-mihomo.exe",
    "${env:ProgramFiles(x86)}\Clash Verge\verge-mihomo.exe",
    "$env:LOCALAPPDATA\Programs\Clash Verge\verge-mihomo.exe"
)
foreach ($cmdName in @("verge-mihomo.exe", "mihomo.exe")) {
    $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { $BinCandidates += $cmd.Source }
}

$MihomoBin = $BinCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($MihomoBin) {
    $TmpTest = Join-Path $ConfigDir "low-ttft-validate-tmp.yaml"
    try {
        $Merged = (Get-Content (Join-Path $ConfigSrc "Merge.yaml") -Raw) + "`n" +
                  (Get-Content (Join-Path $ConfigSrc "dns_config.yaml") -Raw) + "`nproxies: []`nrules:`n  - MATCH,DIRECT`n"
        Set-Content -Path $TmpTest -Value $Merged -Encoding UTF8
        & $MihomoBin -t -d $ConfigDir -f $TmpTest
        if ($LASTEXITCODE -ne 0) {
            throw "Mihomo config validation failed (ExitCode=$LASTEXITCODE)"
        }
        Write-Host "[OK] Kernel validation passed! Reload your active profile in Clash Verge Rev to apply." -ForegroundColor Cyan
    } finally {
        if (Test-Path $TmpTest) { Remove-Item $TmpTest -Force }
    }
} else {
    Write-Warning "mihomo binary not found in standard locations; skipped CLI validation. Reload profile in GUI to apply."
}
