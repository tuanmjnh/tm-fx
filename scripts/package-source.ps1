<#
.SYNOPSIS
    Package the shared project sources into a versioned zip with a SHA256 manifest.

.DESCRIPTION
    Collects only text/source content from README.md, pyproject.toml, docs\,
    configs\, mt5\, python\ and scripts\. Virtual environments, caches, reports,
    datasets, models, compiled .ex5 files, logs, archives and credential files
    are excluded by path segment and extension. Every text file is scanned for
    quoted secret assignments before anything is copied; a hit aborts the
    package. The staging directory is created by this script and removed after
    the zip is written. No existing source file is modified or deleted.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER OutDir
    Output directory. Defaults to reports\packages.

.PARAMETER Version
    Package version label; defaults to 1.0.0.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\package-source.ps1 -Version 0.9.0
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
if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    Write-Host "FAIL: project root not found: $ProjectRoot" -ForegroundColor Red
    exit 2
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not $OutDir) {
    $OutDir = Join-Path $ProjectRoot "reports\packages"
}

$roots = @("README.md", "pyproject.toml", "docs", "configs", "mt5", "python", "scripts")
$allowedExtensions = @(".md", ".json", ".yaml", ".yml", ".toml", ".mq5", ".mqh", ".py", ".ps1", ".txt", ".cfg", ".ini")
$textExtensions = @(".md", ".json", ".yaml", ".yml", ".toml", ".mq5", ".mqh", ".py", ".ps1", ".txt", ".cfg", ".ini")
$blockedSegments = @(".venv", "__pycache__", ".git", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".idea", ".vscode", "reports", "data", "models")
$blockedExtensions = @(".ex4", ".ex5", ".log", ".sqlite", ".sqlite3", ".db", ".zip", ".key", ".pem", ".pfx", ".p12", ".onnx", ".csv", ".set")
$secretPattern = '(?i)\b(password|passwd|api[_-]?key|secret|token)\b["'']?\s*[:=]\s*["''][^"''\r\n]{4,}["'']'

$missing = @()
foreach ($relative in $roots) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $relative))) {
        $missing += $relative
    }
}
if ($missing.Count -gt 0) {
    Write-Host "FAIL: required roots are missing:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 2
}

$files = New-Object System.Collections.Generic.List[object]
$skipped = 0

foreach ($relativeRoot in $roots) {
    $fullRoot = Join-Path $ProjectRoot $relativeRoot
    $item = Get-Item -LiteralPath $fullRoot
    if ($item.PSIsContainer) {
        $candidates = Get-ChildItem -LiteralPath $fullRoot -Recurse -File
    }
    else {
        $candidates = @($item)
    }

    foreach ($candidate in $candidates) {
        $relative = $candidate.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/')
        $segments = $relative -split '[\\/]'
        $blocked = $false
        foreach ($segment in $segments) {
            if ($blockedSegments -contains $segment) { $blocked = $true; break }
        }
        if ($blocked) { $skipped++; continue }

        $extension = $candidate.Extension.ToLowerInvariant()
        if ($blockedExtensions -contains $extension) { $skipped++; continue }
        if ($allowedExtensions -notcontains $extension) { $skipped++; continue }

        $files.Add([pscustomobject]@{
            Relative = $relative
            FullName = $candidate.FullName
            Extension = $extension
        }) | Out-Null
    }
}

$files = @($files | Sort-Object Relative)
if ($files.Count -eq 0) {
    Write-Host "FAIL: no packageable source file found." -ForegroundColor Red
    exit 1
}

foreach ($file in $files) {
    if ($textExtensions -notcontains $file.Extension) { continue }
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match $secretPattern) {
        Write-Host "FAIL: possible secret assignment in $($file.Relative)" -ForegroundColor Red
        Write-Host "Package aborted before copying. Remove the value and rotate the credential."
        exit 1
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$name = "mt5-ea-ai-lab-v$Version-$stamp"
$stage = Join-Path $OutDir ("stage-" + $name)
$zipPath = Join-Path $OutDir ($name + ".zip")

if (Test-Path -LiteralPath $stage) {
    Write-Host "FAIL: staging directory already exists: $stage" -ForegroundColor Red
    exit 1
}
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$manifestLines = @()
try {
    foreach ($file in $files) {
        $destination = Join-Path $stage $file.Relative
        $destinationDir = Split-Path -Parent $destination
        New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination

        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifestLines += "$hash  $($file.Relative)"
    }

    $info = @(
        "package=$name",
        "version=$Version",
        "created=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
        "files=$($files.Count)",
        "excluded_segments=$($blockedSegments -join ', ')",
        "note=Source package only. Contains no .ex5, logs, datasets, models, reports, virtual environments or credential files."
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines((Join-Path $stage "PACKAGE_INFO.txt"), [string[]]$info, $utf8NoBom)
    [System.IO.File]::WriteAllLines((Join-Path $stage "MANIFEST.sha256"), [string[]]$manifestLines, $utf8NoBom)

    Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -Force
}
finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}

$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "PACKAGE_OK: $zipPath"
Write-Host "PACKAGE_FILES: $($files.Count)"
Write-Host "PACKAGE_SKIPPED: $skipped"
Write-Host "PACKAGE_SHA256: $zipHash"
exit 0
