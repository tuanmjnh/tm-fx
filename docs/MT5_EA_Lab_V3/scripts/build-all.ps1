[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MetaEditorPath,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ExpertsRoot = "MQL5\Experts"
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $MetaEditorPath -PathType Leaf)) {
    throw "MetaEditor not found: $MetaEditorPath"
}
$metaEditor = (Resolve-Path -LiteralPath $MetaEditorPath).Path
$root = Join-Path $ProjectRoot $ExpertsRoot
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Experts root not found: $root"
}
$entries = @(Get-ChildItem -LiteralPath $root -Filter '*.mq5' -Recurse -File)
if ($entries.Count -eq 0) {
    throw "No .mq5 entrypoints found under $root. This bootstrap pack does not yet contain V3 EA implementations."
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($entry in $entries) {
    Write-Host "`nCompiling: $($entry.FullName)"
    $logPath = [System.IO.Path]::ChangeExtension($entry.FullName, '.log')
    $ex5Path = [System.IO.Path]::ChangeExtension($entry.FullName, '.ex5')
    if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }

    # MetaEditor command-line syntax requires the source path to be quoted.
    $compileArg = '/compile:"' + $entry.FullName + '"'
    $proc = $null
    try {
        $proc = Start-Process -FilePath $metaEditor -ArgumentList @($compileArg, '/log') -Wait -PassThru -WindowStyle Hidden
    }
    catch {
        Write-Warning "Could not start MetaEditor for $($entry.Name): $($_.Exception.Message)"
        $results.Add([pscustomobject]@{ File=$entry.FullName; Status='FAILED_TO_START'; ExitCode=$null; Log=$logPath; Ex5=$ex5Path })
        continue
    }

    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
        Write-Warning "No compiler log for $($entry.Name); cannot mark PASS. ProcessExit=$($proc.ExitCode)"
        $results.Add([pscustomobject]@{ File=$entry.FullName; Status='UNVERIFIED_NO_LOG'; ExitCode=$proc.ExitCode; Log=$logPath; Ex5=$ex5Path })
        continue
    }

    $log = Get-Content -LiteralPath $logPath -Raw
    $hasErrors = $log -match '(?im)(\berrors?\s*[:=]\s*[1-9]\d*\b|\b[1-9]\d*\s+errors?\b)'
    $hasZeroErrors = $log -match '(?im)(\berrors?\s*[:=]\s*0\b|\b0\s+errors?\b)'
    $hasWarnings = $log -match '(?im)(\bwarnings?\s*[:=]\s*[1-9]\d*\b|\b[1-9]\d*\s+warnings?\b)'
    $ex5Exists = Test-Path -LiteralPath $ex5Path -PathType Leaf

    if ($hasErrors) {
        Write-Warning "COMPILE FAILED: $($entry.Name). Review $logPath"
        $status = 'FAILED_ERRORS'
    }
    elseif ($hasZeroErrors -and $ex5Exists) {
        if ($hasWarnings) {
            Write-Warning "COMPILE WITH WARNINGS: $($entry.Name). Review $logPath"
            $status = 'PASS_WITH_WARNINGS'
        }
        else {
            Write-Host "COMPILE CLEAN: $($entry.Name)" -ForegroundColor Green
            $status = 'PASS'
        }
    }
    else {
        Write-Warning "Compile result not conclusively parsed or .ex5 missing for $($entry.Name); inspect $logPath"
        $status = 'UNVERIFIED'
    }
    $results.Add([pscustomobject]@{ File=$entry.FullName; Status=$status; ExitCode=$proc.ExitCode; Log=$logPath; Ex5=$ex5Path })
}

$reportPath = Join-Path $ProjectRoot 'reports\build-summary.csv'
$reportDir = Split-Path -Parent $reportPath
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$results | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8
Write-Host "`nBuild summary: $reportPath"
$results | Format-Table -AutoSize

$notPass = @($results | Where-Object { $_.Status -notin @('PASS','PASS_WITH_WARNINGS') })
if ($notPass.Count -gt 0) {
    Write-Warning "$($notPass.Count) entrypoint(s) failed or are unverified. Do not package as a verified release."
    exit 10
}
Write-Host 'All discovered entrypoints have compiler logs and .ex5 outputs. Review warnings before release.'
