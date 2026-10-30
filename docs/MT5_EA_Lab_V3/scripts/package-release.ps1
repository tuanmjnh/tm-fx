[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = ""
)
$ErrorActionPreference = 'Stop'
if (-not $OutputPath) { $OutputPath = Join-Path (Split-Path -Parent $ProjectRoot) 'MT5_EA_Lab_V3_Release.zip' }
$exclude = @('*.log','*.csv','*.dat','*.key','*.secret','*.env','*password*','*credential*')
$items = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File | Where-Object {
    $name = $_.Name
    -not ($exclude | Where-Object { $name -like $_ })
}
if (-not $items) { throw 'No files to package.' }
if (Test-Path $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
Compress-Archive -Path ($items.FullName) -DestinationPath $OutputPath -CompressionLevel Optimal
Write-Host "Package created: $OutputPath"
Write-Warning "Review the archive manually for private data before sharing. This script is a packaging helper, not a security scanner."
