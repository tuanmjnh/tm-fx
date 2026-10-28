<#
.SYNOPSIS
    Run the Python test suite with the repository virtual environment.

.DESCRIPTION
    Resolves an interpreter (-Python, then .venv\Scripts\python.exe, then
    "python"), verifies that pytest is importable and runs it from the project
    root so pyproject.toml's pythonpath setting applies. The pytest exit code is
    propagated unchanged. Nothing is installed, no network call is made and no
    MQL5 source is compiled.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER Python
    Interpreter to use instead of the automatic resolution.

.PARAMETER TestPath
    File or directory passed to pytest. Defaults to python\tests.

.PARAMETER PytestArgs
    Extra arguments forwarded to pytest, for example -k sim_configs.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\run-python-tests.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\run-python-tests.ps1 -PytestArgs "-q","-k","sim"
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$Python = "",
    [string]$TestPath = "python\tests",
    [string[]]$PytestArgs = @()
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

$resolvedTestPath = $TestPath
if (-not [System.IO.Path]::IsPathRooted($resolvedTestPath)) {
    $resolvedTestPath = Join-Path $ProjectRoot $TestPath
}
if (-not (Test-Path -LiteralPath $resolvedTestPath)) {
    Write-Host "FAIL: test path not found: $resolvedTestPath" -ForegroundColor Red
    exit 2
}

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

if (-not $pythonPath) {
    Write-Host "FAIL: no Python interpreter found." -ForegroundColor Red
    Write-Host "Create .venv or pass -Python <path>. No test was run."
    exit 2
}

& $pythonPath -c "import pytest" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: pytest is not importable with $pythonPath" -ForegroundColor Red
    Write-Host "Install it into that environment (for example: $pythonPath -m pip install pytest). No test was run."
    exit 2
}

Write-Host "Running pytest with $pythonPath"
Write-Host "Test path: $resolvedTestPath"

Push-Location $ProjectRoot
try {
    & $pythonPath -m pytest $resolvedTestPath -q @PytestArgs
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

Write-Host ""
if ($code -eq 0) {
    Write-Host "TESTS_OK: pytest reported success." -ForegroundColor Green
    Write-Host "Python tests do not prove MQL5 runtime behaviour; run SimCoreTests and Strategy Tester in MT5."
}
else {
    Write-Host "TESTS_FAILED: pytest exit code $code." -ForegroundColor Red
}
exit $code
