<#
.SYNOPSIS
    Read-only check of the local toolchain needed by the MT5 EA & AI Lab.

.DESCRIPTION
    Verifies the repository layout, a Python interpreter (>= 3.11), pytest,
    MetaEditor and write access to reports\. Nothing is installed, compiled or
    launched. No credential, account file, environment secret or broker
    endpoint is read; only paths and versions are inspected.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER MetaEditorPath
    Full path to MetaEditor64.exe. When empty, a few standard install paths
    are tried.

.PARAMETER Python
    Interpreter to use. When empty, .venv\Scripts\python.exe is preferred and
    the "python" command on PATH is the fallback.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\check-environment.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\check-environment.ps1 -MetaEditorPath "D:\MT5\MetaEditor64.exe"
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$MetaEditorPath = "",
    [string]$Python = ""
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

$script:checks = 0
$script:failures = 0

function Add-Check {
    param(
        [bool]$Ok,
        [string]$Name,
        [string]$Detail = ""
    )
    $script:checks++
    if ($Ok) {
        Write-Host ("PASS: {0}{1}" -f $Name, $(if ($Detail) { " -> $Detail" } else { "" })) -ForegroundColor Green
    }
    else {
        $script:failures++
        Write-Host ("FAIL: {0}{1}" -f $Name, $(if ($Detail) { " -> $Detail" } else { "" })) -ForegroundColor Red
    }
}

Write-Host "Checking project layout under $ProjectRoot"

$requiredDirs = @("mt5", "mt5\Include\Sim", "mt5\Experts", "mt5\Scripts", "python\src", "python\tests", "scripts", "docs", "configs\sim")
foreach ($relative in $requiredDirs) {
    $path = Join-Path $ProjectRoot $relative
    Add-Check (Test-Path -LiteralPath $path -PathType Container) "directory $relative"
}

$requiredFiles = @(
    "pyproject.toml",
    "README.md",
    "configs\project.example.json",
    "configs\sim\runner_trailing.json",
    "configs\sim\grid_lab.json",
    "configs\sim\dca_lab.json",
    "mt5\Include\Sim\SimPortfolio.mqh",
    "mt5\Scripts\SimCoreTests.mq5"
)
foreach ($relative in $requiredFiles) {
    $path = Join-Path $ProjectRoot $relative
    Add-Check (Test-Path -LiteralPath $path -PathType Leaf) "file $relative"
}

# Python: explicit override, then the repository venv, then PATH.
$pythonPath = $null
if ($Python) {
    if (Test-Path -LiteralPath $Python -PathType Leaf) {
        $pythonPath = (Resolve-Path -LiteralPath $Python).Path
    }
    else {
        $command = Get-Command $Python -ErrorAction SilentlyContinue
        if ($command) { $pythonPath = $command.Source }
    }
}
else {
    $venvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $venvPython -PathType Leaf) {
        $pythonPath = $venvPython
    }
    else {
        $command = Get-Command python -ErrorAction SilentlyContinue
        if ($command) { $pythonPath = $command.Source }
    }
}
Add-Check ($null -ne $pythonPath) "python interpreter" $(if ($pythonPath) { $pythonPath } else { "not found" })

if ($pythonPath) {
    $versionText = & $pythonPath -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" 2>$null
    $versionOk = $false
    $versionDetail = "unreadable output: $versionText"
    if ($LASTEXITCODE -eq 0 -and $versionText) {
        try {
            $version = [version]$versionText.Trim()
            $versionOk = $version -ge [version]"3.11"
            $versionDetail = $version.ToString()
        }
        catch {
            $versionOk = $false
        }
    }
    Add-Check $versionOk "python >= 3.11" $versionDetail

    $pytestText = & $pythonPath -c "import pytest; print(pytest.__version__)" 2>$null
    $pytestOk = ($LASTEXITCODE -eq 0 -and $pytestText)
    Add-Check $pytestOk "pytest importable" $(if ($pytestOk) { $pytestText.Trim() } else { "pip install pytest inside the venv" })
}

# MetaEditor: explicit path wins and must exist; otherwise try standard locations.
$metaEditorCandidates = @()
if ($MetaEditorPath) {
    $metaEditorCandidates = @($MetaEditorPath)
}
else {
    $metaEditorCandidates = @(
        "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe",
        "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
    )
}
$metaEditorFound = $null
foreach ($candidate in $metaEditorCandidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $metaEditorFound = $candidate
        break
    }
}
Add-Check ($null -ne $metaEditorFound) "MetaEditor64.exe" $(if ($metaEditorFound) { $metaEditorFound } else { "pass -MetaEditorPath; compile will be skipped" })

$reportsDir = Join-Path $ProjectRoot "reports"
$reportsOk = $false
$reportsDetail = ""
try {
    New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $reportsDir "build") | Out-Null
    $probe = Join-Path $reportsDir ".environment-check-probe"
    Set-Content -LiteralPath $probe -Value "probe" -Encoding ASCII
    Remove-Item -LiteralPath $probe -Force
    $reportsOk = $true
    $reportsDetail = $reportsDir
}
catch {
    $reportsDetail = $_.Exception.Message
}
Add-Check $reportsOk "reports directory writable" $reportsDetail

Write-Host ""
Write-Host "SUMMARY: checks=$($script:checks) fail=$($script:failures)"
Write-Host "No broker connection, no account access, no secret or credential was read."

if ($script:failures -gt 0) {
    Write-Host "ENVIRONMENT_FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "ENVIRONMENT_OK" -ForegroundColor Green
exit 0
