[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$OutputPath = ""
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $ProjectRoot).Path
if (-not $OutputPath) { $OutputPath = Join-Path $root 'reports/mt5-ea-lab-source.zip' }
$out = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Force -Path (Split-Path $out -Parent) | Out-Null
if (Test-Path $out) { Remove-Item $out -Force }
$exclude = @('\.git\','\.venv\','\__pycache__\','\datasets\raw\','\reports\backtests\','\reports\build\','\reports\tests\','\.env$','\.log$')
$files = Get-ChildItem $root -File -Recurse | Where-Object {
    $p = $_.FullName.Substring($root.Length)
    -not ($exclude | Where-Object { $p -match $_ }) -and $_.FullName -ne $out
}
if (-not $files) { throw 'No files to package.' }
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('mt5-ea-lab-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp | Out-Null
try {
    foreach ($file in $files) {
        $rel = $file.FullName.Substring($root.Length).TrimStart('\','/')
        $dest = Join-Path $temp $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Copy-Item $file.FullName $dest
    }
    Compress-Archive -Path (Join-Path $temp '*') -DestinationPath $out -CompressionLevel Optimal
} finally { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host "Package created: $out"
