[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$MetaEditorPath = ""
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $ProjectRoot).Path
Write-Host "Project root: $root"

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) { & python --version } else { Write-Warning "python not found on PATH" }
$pytest = Get-Command pytest -ErrorAction SilentlyContinue
if ($pytest) { & pytest --version } else { Write-Host "pytest not found globally; .venv may be used later." }

if (-not $MetaEditorPath) { $MetaEditorPath = $env:METAEDITOR_PATH }
if ($MetaEditorPath) {
    if (Test-Path $MetaEditorPath) { Write-Host "MetaEditor found: $MetaEditorPath" }
    else { Write-Warning "METAEDITOR_PATH supplied but file not found: $MetaEditorPath" }
} else { Write-Host "MetaEditor path not supplied. Use -MetaEditorPath when building MQL5." }

foreach ($path in @('docs','scripts','configs','MQL5/Experts/MT5EALab','python/tests','reports')) {
    $full = Join-Path $root $path
    if (Test-Path $full) { Write-Host "OK  $path" } else { Write-Warning "Missing $path" }
}
Write-Host "Environment check finished. Warnings above must be resolved or documented as BLOCKED."
