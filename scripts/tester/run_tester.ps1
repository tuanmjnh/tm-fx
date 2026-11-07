<#
.SYNOPSIS
    Run one Strategy Tester scenario headlessly and archive its artefacts.

.DESCRIPTION
    Starts terminal64.exe with "/config:<scenario>.ini", waits for the terminal to
    exit, then copies the tester report (tester_<scenario>.htm/.png) and the EA CSV
    (sim_<scenario>.csv) into <root>\reports\build\tester-reports\<scenario>\.

    This is the only family of scripts in the repo that starts the MT5 terminal.
    It never logs in and never sends an order by itself: the Strategy Tester runs on
    a throwaway virtual account and the EA stays demo/tester-only (ADR 0004/0006).
    A scenario .set must be staged in <data folder>\MQL5\Profiles\Tester\ - this
    script stages it from reports\build\tester-sets\ when present.

.PARAMETER Scenario
    Scenario name. Must match <RunDir>\<scenario>.ini.

.PARAMETER ProjectRoot
    Repository root. Defaults to two levels above this script.

.PARAMETER TerminalDataDir
    MT5 data folder (contains MQL5\). Auto-detected under
    %APPDATA%\MetaQuotes\Terminal when omitted.

.PARAMETER AgentFilesDir
    Tester agent MQL5\Files folder. Auto-detected under
    %APPDATA%\MetaQuotes\Tester when omitted.

.PARAMETER Exe
    Full path to terminal64.exe.

.PARAMETER RunDir
    Folder holding <scenario>.ini. Defaults to reports\build\tester-run.

.PARAMETER OutRoot
    Archive root. Defaults to reports\build\tester-reports.

.PARAMETER Contract
    Name the report contract_<scenario> and do not wait for a CSV (script tests).

.PARAMETER TimeoutSec
    Hard timeout waiting for terminal64 to exit.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Scenario,
    [string]$ProjectRoot = "",
    [string]$TerminalDataDir = "",
    [string]$AgentFilesDir = "",
    [string]$Exe = "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe",
    [string]$RunDir = "",
    [string]$OutRoot = "",
    [switch]$Contract,
    [int]$TimeoutSec = 1800
)

$ErrorActionPreference = "Stop"

if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
if (-not $RunDir) { $RunDir = Join-Path $ProjectRoot "reports\build\tester-run" }
if (-not $OutRoot) { $OutRoot = Join-Path $ProjectRoot "reports\build\tester-reports" }

function Get-TerminalDataDir {
    $base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (-not (Test-Path -LiteralPath $base)) { return $null }
    $candidates = @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "MQL5\Experts") } |
        Select-Object -ExpandProperty FullName)
    if ($candidates.Count -eq 0) { return $null }
    return $candidates
}

function Get-AgentFilesDirs {
    $base = Join-Path $env:APPDATA "MetaQuotes\Tester"
    if (-not (Test-Path -LiteralPath $base)) { return @() }
    return @(
        Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -Directory -Filter "Agent-*" -ErrorAction SilentlyContinue
            } |
            ForEach-Object { Join-Path $_.FullName "MQL5\Files" } |
            Where-Object { Test-Path -LiteralPath $_ }
    )
}

if (-not $TerminalDataDir) {
    $dirs = @(Get-TerminalDataDir)
    if ($dirs.Count -eq 0) { throw "no MT5 data folder found; pass -TerminalDataDir <path containing MQL5>" }
    if ($dirs.Count -gt 1) {
        #--- Prefer the folder whose MQL5\Experts already holds the compiled EA.
        $match = $dirs | Where-Object { Test-Path -LiteralPath (Join-Path $_ "MQL5\Experts\WonderwhalesXAU2ModeEA.ex5") }
        $TerminalDataDir = if ($match) { @($match)[0] } else { $dirs[0] }
    } else {
        $TerminalDataDir = $dirs[0]
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $TerminalDataDir "MQL5\Experts"))) {
    throw "$TerminalDataDir does not contain MQL5\Experts"
}

#--- The tester picks an agent (…-3000, …-3001, …) per run, so artefacts can land
#--- in ANY agent's Files folder. Search them all instead of guessing the first.
$AgentFilesDirs = @()
if ($AgentFilesDir) {
    $AgentFilesDirs = @($AgentFilesDir)
} else {
    $AgentFilesDirs = @(Get-AgentFilesDirs)
    if ($AgentFilesDirs.Count -gt 0) { $AgentFilesDir = $AgentFilesDirs[0] }
}

$Ini = Join-Path $RunDir "$Scenario.ini"
if (-not (Test-Path -LiteralPath $Ini)) { throw "missing ini: $Ini" }
if (-not (Test-Path -LiteralPath $Exe)) { throw "missing terminal: $Exe" }

$ReportName = if ($Contract) { "contract_$($Scenario -replace '^contract_', '')" } else { "tester_$Scenario" }
$OutDir = Join-Path $OutRoot $Scenario
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

#--- A scenario writes more than one CSV: the 18-column journal, the census and
#--- the telemetry file all share the sim_<scenario> prefix.
$journalPath = if ($AgentFilesDir) { Join-Path $AgentFilesDir "sim_$Scenario.csv" } else { $null }

#--- A running terminal ignores /config:, so refuse to start in that case.
$running = Get-Process terminal64 -ErrorAction SilentlyContinue
if ($running) { throw "terminal64 is already running (pid $($running.Id)); close it first" }

#--- Stage the scenario .set next to the terminal profiles when we have one.
$setSrc = Join-Path $ProjectRoot "reports\build\tester-sets\$Scenario.set"
$setDst = Join-Path $TerminalDataDir "MQL5\Profiles\Tester\$Scenario.set"
if (Test-Path -LiteralPath $setSrc) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $setDst) | Out-Null
    Copy-Item -LiteralPath $setSrc -Destination $setDst -Force
    Write-Host "STAGED $setDst"
}

#--- Remove stale artefacts so freshness is unambiguous.
Get-ChildItem $TerminalDataDir -Filter "$ReportName.*" -File -ErrorAction SilentlyContinue | Remove-Item -Force
foreach ($dir in $AgentFilesDirs) {
    Get-ChildItem $dir -Filter "sim_$Scenario*.csv" -File -ErrorAction SilentlyContinue | Remove-Item -Force
}

Write-Host "RUN $Scenario  ini=$Ini  report=$ReportName  data=$TerminalDataDir"
$started = Get-Date
$proc = Start-Process -FilePath $Exe -ArgumentList "/config:`"$Ini`"" -PassThru
$deadline = $started.AddSeconds($TimeoutSec)
while (-not $proc.HasExited) {
    Start-Sleep -Seconds 2
    if ((Get-Date) -gt $deadline) { throw "timeout waiting for terminal64 to exit" }
}
Write-Host ("terminal64 exited after {0:N1}s (code {1})" -f ((Get-Date) - $started).TotalSeconds, $proc.ExitCode)

#--- The tester agent can still be flushing files; poll for the report.
$htm = Join-Path $TerminalDataDir "$ReportName.htm"
for ($i = 0; $i -lt 60; $i++) {
    if ((Test-Path $htm) -and ((Get-Item $htm).LastWriteTime -gt $started)) { break }
    Start-Sleep -Seconds 2
}
if (-not $Contract) {
    for ($i = 0; $i -lt 60; $i++) {
        $fresh = @($AgentFilesDirs | ForEach-Object {
            Get-ChildItem $_ -Filter "sim_$Scenario*.csv" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt $started } })
        if ($fresh.Count -gt 0) { break }
        Start-Sleep -Seconds 2
    }
}

#--- Fail closed on a silently aborted run. The tester writes a report even when
#--- it never loaded history (History Quality n/a, Bars 0, Ticks 0) and exits 0,
#--- which on 2026-11-05 made a 12-second non-run look like a finished scenario.
$bars = 0
if (Test-Path $htm) {
    $html = Get-Content -LiteralPath $htm -Raw -Encoding UTF8
    $m = [regex]::Match($html, 'Bars:</td>\s*<td[^>]*><b>([0-9,]+)</b>')
    if ($m.Success) { $bars = [double]($m.Groups[1].Value -replace '[^0-9]', '') }
}
if ($bars -le 0) {
    throw "tester loaded no bars for $Scenario (report=$htm); run aborted, archive left untouched"
}

#--- Only replace the archive once the run is known good, so a failed run can
#--- never leave a previous run's CSV looking like fresh evidence.
Get-ChildItem $OutDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$copied = @()
if (Test-Path $htm) {
    Get-ChildItem $TerminalDataDir -Filter "$ReportName.*" -File |
        Copy-Item -Destination $OutDir -Force
    $copied += "$ReportName.*"
}
if (-not $Contract) {
    $csvs = @($AgentFilesDirs | ForEach-Object {
        Get-ChildItem $_ -Filter "sim_$Scenario*.csv" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $started } })
    foreach ($csv in $csvs) {
        Copy-Item $csv.FullName (Join-Path $OutDir $csv.Name) -Force
        $copied += $csv.Name
    }
}

if ($copied.Count -eq 0) { throw "no artefacts produced for $Scenario" }

Write-Host "ARCHIVED -> $OutDir"
Get-ChildItem $OutDir -File | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.Substring(0, 12)
    Write-Host ("  {0,9} bytes  sha256={1}  {2}" -f $_.Length, $hash, $_.Name)
}
