<#
.SYNOPSIS
    Compile the Wonderwhales PinePort indicator, contract tests and EA.

.DESCRIPTION
    MetaEditor CLI may return exit code 1 even when the log reports success.
    This script therefore reads the UTF-16 log and treats the "Result:" line as
    authoritative. Exit 0 only when every source compiles with 0 errors and
    0 warnings. No MT5 terminal, broker connection or trading API is used.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER MetaEditorPath
    Full path to MetaEditor64.exe.

.PARAMETER LogDir
    Directory for compile logs. Defaults to reports\build.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$MetaEditorPath = "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe",
    [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"

if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
if (-not $LogDir) {
    $LogDir = Join-Path $ProjectRoot "reports\build"
}

$sources = @(
    "mt5\Indicators\PinePort\Wonderwhales.mq5",
    "mt5\Scripts\WonderwhalesContractTests.mq5",
    "mt5\Experts\PineSignalLabEA.mq5"
)

function Read-Utf16Log {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

if (-not (Test-Path -LiteralPath $MetaEditorPath)) {
    Write-Host "FAIL: MetaEditor not found: $MetaEditorPath" -ForegroundColor Red
    Write-Host "Set -MetaEditorPath or install MetaTrader 5. No compile was attempted."
    exit 2
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$failures = 0
$results = @()

foreach ($relative in $sources) {
    $sourcePath = Join-Path $ProjectRoot $relative
    $name = [System.IO.Path]::GetFileNameWithoutExtension($relative)
    $logPath = Join-Path $LogDir ("{0}.log" -f $name)
    $ex5Path = [System.IO.Path]::ChangeExtension($sourcePath, ".ex5")

    Write-Host "Compiling $relative"
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Host "FAIL: source missing: $sourcePath" -ForegroundColor Red
        $results += [pscustomobject]@{ Source = $relative; CliExit = $null; Errors = $null; Warnings = $null; Ex5Bytes = $null; Log = $null }
        $failures++
        continue
    }

    if (Test-Path -LiteralPath $logPath) {
        Remove-Item -LiteralPath $logPath -Force
    }

    & $MetaEditorPath "/compile:$sourcePath" "/log:$logPath" | Out-Null
    $cliExit = $LASTEXITCODE

    if (-not (Test-Path -LiteralPath $logPath)) {
        Write-Host "FAIL: MetaEditor did not write a log: $logPath" -ForegroundColor Red
        $results += [pscustomobject]@{ Source = $relative; CliExit = $cliExit; Errors = $null; Warnings = $null; Ex5Bytes = $null; Log = $null }
        $failures++
        continue
    }

    $text = Read-Utf16Log -Path $logPath
    $match = [regex]::Match($text, "Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?")
    if (-not $match.Success) {
        Write-Host "FAIL: log has no Result line: $logPath" -ForegroundColor Red
        $results += [pscustomobject]@{ Source = $relative; CliExit = $cliExit; Errors = $null; Warnings = $null; Ex5Bytes = $null; Log = $logPath }
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
        Source = $relative
        CliExit = $cliExit
        Errors = $errors
        Warnings = $warnings
        Ex5Bytes = $ex5Bytes
        Log = $logPath
    }

    if ($errors -ne 0 -or $warnings -ne 0) {
        $failures++
        Write-Host ("FAIL: {0} errors, {1} warnings (cli exit {2})" -f $errors, $warnings, $cliExit) -ForegroundColor Red
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
Write-Host "Compile success does not prove runtime correctness; run the test script and Strategy Tester manually."
exit 0
