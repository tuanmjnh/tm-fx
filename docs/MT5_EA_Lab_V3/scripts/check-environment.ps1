[CmdletBinding()]
param(
    [string]$MetaEditorPath = "",
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)
$ErrorActionPreference = 'Stop'
Write-Host "ProjectRoot: $ProjectRoot"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) { & python --version } else { Write-Host "Python: NOT FOUND (optional for MQL-only build)" }

if (-not $MetaEditorPath) {
    $candidates = @(
        "$env:ProgramFiles\MetaTrader 5\metaeditor64.exe",
        "$env:ProgramFiles\Exness MT5\metaeditor64.exe",
        "$env:ProgramFiles(x86)\MetaTrader 5\metaeditor.exe"
    )
    $MetaEditorPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ($MetaEditorPath -and (Test-Path $MetaEditorPath)) {
    Write-Host "MetaEditor: $MetaEditorPath"
} else {
    Write-Warning "MetaEditor not auto-detected. Pass -MetaEditorPath with the exact terminal's MetaEditor path."
    exit 2
}
Write-Host "Environment check completed. This script does not modify the system or start MT5 trading."
