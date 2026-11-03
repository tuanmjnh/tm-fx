[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [Parameter(Mandatory=$true)][string]$MetaEditorPath
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $ProjectRoot).Path
if (-not (Test-Path $MetaEditorPath -PathType Leaf)) { throw "MetaEditor executable not found: $MetaEditorPath" }
$sourceRoot = Join-Path $root 'MQL5/Experts/MT5EALab'
if (-not (Test-Path $sourceRoot)) { throw "Source directory not found: $sourceRoot" }
$sources = @(Get-ChildItem $sourceRoot -Filter '*.mq5' -File -Recurse)
if ($sources.Count -eq 0) { throw "No .mq5 files found under $sourceRoot; nothing was built." }
$logDir = Join-Path $root 'reports/build'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$failed = @()
foreach ($src in $sources) {
    $safeName = ($src.BaseName -replace '[^A-Za-z0-9_.-]','_')
    $log = Join-Path $logDir "$safeName-build.log"
    Write-Host "Compiling $($src.FullName)"
    $args = @("/compile:`"$($src.FullName)`"", "/log:`"$log`"")
    $proc = Start-Process -FilePath $MetaEditorPath -ArgumentList $args -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Warning "MetaEditor exit code $($proc.ExitCode) for $($src.Name). See $log"
        $failed += $src.FullName
    } elseif (-not (Test-Path $log) -or (Get-Item $log).Length -eq 0) {
        Write-Warning "No usable compile log for $($src.Name); cannot claim success."
        $failed += $src.FullName
    } else {
        $content = Get-Content $log -Raw
        if ($content -match '(?im)\b[1-9]\d* errors?\b' -or $content -match '(?im)\b(error|failed)\b') {
            Write-Warning "Compile log may contain errors for $($src.Name). Inspect $log"
            $failed += $src.FullName
        } else { Write-Host "Compile process returned 0; inspect log for warnings: $log" }
    }
}
if ($failed.Count -gt 0) {
    Write-Error ("Build not verified for: " + ($failed -join '; '))
    exit 1
}
Write-Host "All compiler processes returned success and produced logs. Review logs manually before accepting build."
