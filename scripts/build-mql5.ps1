<#
.SYNOPSIS
    Compile every MQL5 source under mt5\ with MetaEditor CLI and report real results.

.DESCRIPTION
    Discovers .mq5 files recursively (Indicators, Experts, Scripts, ...), deletes
    stale .ex5 artifacts, compiles each source into its own UTF-16 log and reads
    the "Result: N errors, M warnings" line. MetaEditor CLI sometimes returns
    exit code 1 even on success, so the log is authoritative. A missing log, a
    missing Result line, a missing .ex5 or any error/warning fails the build.

    Include files (.mqh) are not compiled directly; they are pulled in by the
    .mq5 sources. No terminal is launched, no broker is contacted and no
    trading API is called.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER MetaEditorPath
    Full path to MetaEditor64.exe.

.PARAMETER LogDir
    Directory for compile logs. Defaults to reports\build.

.PARAMETER Filter
    Wildcard matched against the path relative to mt5\, for example "Experts\*".
    Defaults to "*" (every source).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\build-mql5.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\*" -LogDir reports\build-track-c
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$MetaEditorPath = "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe",
    [string]$LogDir = "",
    [string]$Filter = "*"
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
if (-not $LogDir) {
    $LogDir = Join-Path $ProjectRoot "reports\build"
}

function Read-Utf16Log {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

if (-not (Test-Path -LiteralPath $MetaEditorPath -PathType Leaf)) {
    Write-Host "FAIL: MetaEditor not found: $MetaEditorPath" -ForegroundColor Red
    Write-Host "Set -MetaEditorPath or install MetaTrader 5. No compile was attempted."
    exit 2
}

$mt5Dir = Join-Path $ProjectRoot "mt5"
if (-not (Test-Path -LiteralPath $mt5Dir -PathType Container)) {
    Write-Host "FAIL: missing mt5 directory: $mt5Dir" -ForegroundColor Red
    exit 2
}

$sources = @(Get-ChildItem -LiteralPath $mt5Dir -Recurse -Filter "*.mq5" -File |
    Sort-Object FullName |
    Where-Object { $_.FullName.Substring($mt5Dir.Length).TrimStart('\', '/') -like $Filter })

if ($sources.Count -eq 0) {
    Write-Host "FAIL: no .mq5 source matched Filter '$Filter' under $mt5Dir" -ForegroundColor Red
    exit 2
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$failures = 0
$results = @()

foreach ($source in $sources) {
    $relative = $source.FullName.Substring($mt5Dir.Length).TrimStart('\', '/')
    $display = "mt5\$relative"
    $logName = ($relative -replace '[\\/]', '_') + ".log"
    $logPath = Join-Path $LogDir $logName
    $ex5Path = [System.IO.Path]::ChangeExtension($source.FullName, ".ex5")

    Write-Host "Compiling $display"
    if (Test-Path -LiteralPath $logPath) {
        Remove-Item -LiteralPath $logPath -Force
    }
    if (Test-Path -LiteralPath $ex5Path) {
        Remove-Item -LiteralPath $ex5Path -Force
    }

    & $MetaEditorPath "/compile:$($source.FullName)" "/log:$logPath" | Out-Null
    $cliExit = $LASTEXITCODE

    if (-not (Test-Path -LiteralPath $logPath)) {
        Write-Host "FAIL: MetaEditor did not write a log: $logPath" -ForegroundColor Red
        $results += [pscustomobject]@{ Source = $display; CliExit = $cliExit; Errors = $null; Warnings = $null; Ex5Bytes = $null; Log = $null }
        $failures++
        continue
    }

    $text = Read-Utf16Log -Path $logPath
    $match = [regex]::Match($text, "Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?")
    if (-not $match.Success) {
        Write-Host "FAIL: log has no Result line: $logPath" -ForegroundColor Red
        $results += [pscustomobject]@{ Source = $display; CliExit = $cliExit; Errors = $null; Warnings = $null; Ex5Bytes = $null; Log = $logPath }
        $failures++
        continue
    }

    $errors = [int]$match.Groups[1].Value
    $warnings = [int]$match.Groups[2].Value
    $ex5Bytes = $null
    if (Test-Path -LiteralPath $ex5Path) {
        $ex5Bytes = (Get-Item -LiteralPath $ex5Path).Length
    }

    $results += [pscustomobject]@{
        Source = $display
        CliExit = $cliExit
        Errors = $errors
        Warnings = $warnings
        Ex5Bytes = $ex5Bytes
        Log = $logName
    }

    if ($errors -ne 0 -or $warnings -ne 0) {
        $failures++
        Write-Host ("FAIL: {0} errors, {1} warnings (cli exit {2})" -f $errors, $warnings, $cliExit) -ForegroundColor Red
    }
    elseif ($null -eq $ex5Bytes) {
        $failures++
        Write-Host "FAIL: log reports success but no .ex5 was produced: $ex5Path" -ForegroundColor Red
    }
    else {
        Write-Host ("PASS: 0 errors, 0 warnings (cli exit {0}); ex5={1} bytes" -f $cliExit, $ex5Bytes) -ForegroundColor Green
    }
}

Write-Host ""
$results | Format-Table -AutoSize | Out-String | Write-Host

if ($failures -gt 0) {
    Write-Host "BUILD_FAILED: $failures of $($sources.Count) source(s) failed." -ForegroundColor Red
    exit 1
}

Write-Host "BUILD_OK: $($sources.Count) source(s) compiled with 0 errors and 0 warnings."
Write-Host "Compile success does not prove runtime correctness; run the test scripts and Strategy Tester manually."
exit 0
