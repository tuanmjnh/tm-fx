<#
.SYNOPSIS
    Package the Wonderwhales PinePort source, docs, tests and helper scripts.

.DESCRIPTION
    Creates a versioned zip under reports\packages plus a SHA256 manifest.
    Only an explicit allow-list of files is copied. Compiled artifacts, logs,
    datasets, models, experiments, virtual environments and credential files
    are never included.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER OutDir
    Output directory. Defaults to reports\packages.

.PARAMETER Version
    Package version label; defaults to 1.0.0.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$OutDir = "",
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
if (-not $OutDir) {
    $OutDir = Join-Path $ProjectRoot "reports\packages"
}

$files = @(
    "README.md",
    "pyproject.toml",
    "docs/INDICATOR_SPEC_Wonderwhales.md",
    "docs/REPAINT_AUDIT_Wonderwhales.md",
    "docs/BUFFER_CONTRACT_Wonderwhales.md",
    "docs/PINE_PARITY_Wonderwhales.md",
    "docs/PINE_MQL5_COMPATIBILITY.md",
    "docs/TEST_PLAN.md",
    "docs/PINEPORT_INSTALL_AND_TEST.md",
    "docs/PINE_INVENTORY.md",
    "docs/PROGRESS.md",
    "mt5/README.md",
    "mt5/Include/PinePort/WonderwhalesContract.mqh",
    "mt5/Indicators/PinePort/Wonderwhales.mq5",
    "mt5/Experts/PineSignalLabEA.mq5",
    "mt5/Scripts/WonderwhalesContractTests.mq5",
    "python/src/mt5_ea_ai_lab/evaluation/pine_parity.py",
    "python/tests/test_pine_parity.py",
    "scripts/compare_pine_exports.py",
    "scripts/validate_pineport.py",
    "scripts/build_pineport.ps1",
    "scripts/package_pineport.ps1"
)

$blockedExtensions = @(
    ".ex4", ".ex5", ".log", ".sqlite", ".sqlite3", ".db", ".zip",
    ".key", ".pem", ".pfx", ".p12"
)

$secretPattern = "(?i)\b(password|passwd|api[_-]?key|secret|token)\s*=\s*['""]?[A-Za-z0-9_\-]{6,}"

$missing = @()
foreach ($relative in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $relative))) {
        $missing += $relative
    }
}
if ($missing.Count -gt 0) {
    Write-Host "FAIL: required files are missing:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 2
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$name = "wonderwhales-pineport-v$Version-$stamp"
$stage = Join-Path $OutDir ("stage-" + $name)
$zipPath = Join-Path $OutDir ($name + ".zip")

New-Item -ItemType Directory -Force -Path $stage | Out-Null

$manifestLines = @()
foreach ($relative in $files) {
    $source = Join-Path $ProjectRoot $relative
    $extension = [System.IO.Path]::GetExtension($relative).ToLowerInvariant()
    if ($blockedExtensions -contains $extension) {
        Write-Host "FAIL: blocked extension in allow-list: $relative" -ForegroundColor Red
        exit 1
    }

    if ($extension -in @(".mq5", ".mqh", ".py", ".ps1", ".toml")) {
        $content = Get-Content -LiteralPath $source -Raw
        if ($content -match $secretPattern) {
            Write-Host "FAIL: possible secret assignment in $relative" -ForegroundColor Red
            exit 1
        }
    }

    $destination = Join-Path $stage $relative
    $destinationDir = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination

    $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestLines += "$hash  $relative"
}

$info = @(
    "package=$name",
    "version=$Version",
    "created=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
    "files=$($files.Count)",
    "note=Source package only. Contains no .ex5, logs, datasets, models or account files."
)
$info | Set-Content -LiteralPath (Join-Path $stage "PACKAGE_INFO.txt") -Encoding UTF8
$manifestLines | Set-Content -LiteralPath (Join-Path $stage "MANIFEST.sha256") -Encoding UTF8

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -Force
Remove-Item -LiteralPath $stage -Recurse -Force

$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "PACKAGE_OK: $zipPath"
Write-Host "PACKAGE_FILES: $($files.Count)"
Write-Host "PACKAGE_SHA256: $zipHash"
exit 0
