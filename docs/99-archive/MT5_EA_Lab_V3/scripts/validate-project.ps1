[CmdletBinding()]
param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$experts = Join-Path $ProjectRoot 'MQL5\Experts'
if (-not (Test-Path $experts)) {
    Write-Warning "MQL5\Experts not found yet. This is a documentation/bootstrap pack; create the source tree during implementation."
    exit 2
}
$mq5 = Get-ChildItem -Path $experts -Filter '*.mq5' -Recurse -File
if (-not $mq5) {
    Write-Warning "No EA entrypoint .mq5 files found. Do not report build success."
    exit 3
}
$missing = New-Object System.Collections.Generic.List[string]
foreach ($file in $mq5) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $includes = [regex]::Matches($text, '#include\s+["<]([^">]+)[">]')
    foreach ($m in $includes) {
        $relative = $m.Groups[1].Value
        $localCandidate = Join-Path $file.DirectoryName $relative
        $includeRootCandidate = Join-Path (Join-Path $ProjectRoot 'MQL5\Include') $relative
        if (-not (Test-Path $localCandidate) -and -not (Test-Path $includeRootCandidate)) {
            $missing.Add("$($file.FullName) -> $relative")
        }
    }
}
if ($missing.Count -gt 0) {
    Write-Host 'Missing include dependencies:' -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host " - $_" }
    exit 4
}
Write-Host "Validated $($mq5.Count) EA entrypoint(s); include references resolved."
