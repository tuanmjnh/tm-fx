<#
.SYNOPSIS
    Copy the project MQL5 sources into an MT5 data folder and compile them.

.DESCRIPTION
    Dry run by default. With -Apply the script copies the PinePort sources plus
    the Track C simulation, TrendRider and demo-execution sources into
    <data folder>\MQL5 and compiles them with MetaEditor. Compile logs are
    read as UTF-16 and must report "0 errors, 0 warnings". Include trees are
    copied wholesale so a fresh MT5 install gets the same source set.

    The script never starts the MT5 terminal, never connects to a broker and
    never reads or writes account files. Existing target files that differ are
    skipped unless -Force is supplied.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent directory of this script.

.PARAMETER TerminalDataDir
    MT5 data folder (the one containing MQL5\). Use File > Open Data Folder in
    the terminal to find it. When omitted, folders under
    %APPDATA%\MetaQuotes\Terminal are listed.

.PARAMETER MetaEditorPath
    Full path to MetaEditor64.exe.

.PARAMETER LogDir
    Directory for compile logs. Defaults to reports\build\deploy.

.PARAMETER Apply
    Copy the files. Without this switch nothing is written.

.PARAMETER Force
    Overwrite target files whose content differs from the repository copy.

.PARAMETER SkipCompile
    Copy only; do not run MetaEditor.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [string]$TerminalDataDir = "",
    [string]$MetaEditorPath = "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe",
    [string]$LogDir = "",
    [switch]$Apply,
    [switch]$Force,
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
if (-not $LogDir) {
    $LogDir = Join-Path $ProjectRoot "reports\build\deploy"
}

$files = @(
    [pscustomobject]@{ Source = "mt5\Include\LabLogger.mqh"; Target = "MQL5\Include\LabLogger.mqh" },
    [pscustomobject]@{ Source = "mt5\Include\PinePort\WonderwhalesContract.mqh"; Target = "MQL5\Include\PinePort\WonderwhalesContract.mqh" },
    [pscustomobject]@{ Source = "mt5\Include\PinePort\LongKacoVSAContract.mqh"; Target = "MQL5\Include\PinePort\LongKacoVSAContract.mqh" },
    [pscustomobject]@{ Source = "mt5\Include\PinePort\TMFusionZonesContract.mqh"; Target = "MQL5\Include\PinePort\TMFusionZonesContract.mqh" },
    [pscustomobject]@{ Source = "mt5\Include\PinePort\PriceActionMTFContract.mqh"; Target = "MQL5\Include\PinePort\PriceActionMTFContract.mqh" },
    [pscustomobject]@{ Source = "mt5\Include\PinePort\TMXAUSignals2Contract.mqh"; Target = "MQL5\Include\PinePort\TMXAUSignals2Contract.mqh" },
    [pscustomobject]@{ Source = "mt5\Include\PinePort\TMIndicator2Contract.mqh"; Target = "MQL5\Include\PinePort\TMIndicator2Contract.mqh" },
    [pscustomobject]@{ Source = "mt5\Indicators\PinePort\Wonderwhales.mq5"; Target = "MQL5\Indicators\PinePort\Wonderwhales.mq5" },
    [pscustomobject]@{ Source = "mt5\Indicators\PinePort\LongKacoVSA.mq5"; Target = "MQL5\Indicators\PinePort\LongKacoVSA.mq5" },
    [pscustomobject]@{ Source = "mt5\Indicators\PinePort\TMFusionZones.mq5"; Target = "MQL5\Indicators\PinePort\TMFusionZones.mq5" },
    [pscustomobject]@{ Source = "mt5\Indicators\PinePort\PriceActionMTF.mq5"; Target = "MQL5\Indicators\PinePort\PriceActionMTF.mq5" },
    [pscustomobject]@{ Source = "mt5\Indicators\PinePort\TMXAUSignals2.mq5"; Target = "MQL5\Indicators\PinePort\TMXAUSignals2.mq5" },
    [pscustomobject]@{ Source = "mt5\Indicators\PinePort\TMIndicator2.mq5"; Target = "MQL5\Indicators\PinePort\TMIndicator2.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\WonderwhalesContractTests.mq5"; Target = "MQL5\Scripts\WonderwhalesContractTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\LongKacoVSAContractTests.mq5"; Target = "MQL5\Scripts\LongKacoVSAContractTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\TMFusionZonesContractTests.mq5"; Target = "MQL5\Scripts\TMFusionZonesContractTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\PriceActionMTFContractTests.mq5"; Target = "MQL5\Scripts\PriceActionMTFContractTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\TMXAUSignals2ContractTests.mq5"; Target = "MQL5\Scripts\TMXAUSignals2ContractTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\TMIndicator2ContractTests.mq5"; Target = "MQL5\Scripts\TMIndicator2ContractTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Experts\PineSignalLabEA.mq5"; Target = "MQL5\Experts\PineSignalLabEA.mq5" },
    [pscustomobject]@{ Source = "mt5\Experts\PineMultiSignalLabEA.mq5"; Target = "MQL5\Experts\PineMultiSignalLabEA.mq5" }
)

# Track C simulation, TrendRider and demo-execution sources. The .mqh trees are
# enumerated instead of listed so a new module cannot be left out of a redeploy.
foreach ($tree in @("mt5\Include\Sim", "mt5\Include\TrendRider", "mt5\Include\Exec")) {
    $treeRoot = Join-Path $ProjectRoot $tree
    if (-not (Test-Path -LiteralPath $treeRoot -PathType Container)) {
        Write-Host "FAIL: include tree missing: $treeRoot" -ForegroundColor Red
        exit 2
    }
    foreach ($mqh in @(Get-ChildItem -LiteralPath $treeRoot -File -Filter "*.mqh" | Sort-Object Name)) {
        $relative = $mqh.FullName.Substring($ProjectRoot.Length + 1)
        $files += [pscustomobject]@{
            Source = $relative
            Target = "MQL5\" + $relative.Substring("mt5\".Length)
        }
    }
}

$files += @(
    [pscustomobject]@{ Source = "mt5\Experts\RunnerTrailingLabEA.mq5"; Target = "MQL5\Experts\RunnerTrailingLabEA.mq5" },
    [pscustomobject]@{ Source = "mt5\Experts\GridLabEA.mq5"; Target = "MQL5\Experts\GridLabEA.mq5" },
    [pscustomobject]@{ Source = "mt5\Experts\DCALabEA.mq5"; Target = "MQL5\Experts\DCALabEA.mq5" },
    [pscustomobject]@{ Source = "mt5\Experts\PinePlanSimEA.mq5"; Target = "MQL5\Experts\PinePlanSimEA.mq5" },
    [pscustomobject]@{ Source = "mt5\Experts\WonderwhalesSimEA.mq5"; Target = "MQL5\Experts\WonderwhalesSimEA.mq5" },
    [pscustomobject]@{ Source = "mt5\Experts\PATrendRiderXAUv1SimEA.mq5"; Target = "MQL5\Experts\PATrendRiderXAUv1SimEA.mq5" },
    [pscustomobject]@{ Source = "mt5\Experts\PATrendRiderXAUv1DemoEA.mq5"; Target = "MQL5\Experts\PATrendRiderXAUv1DemoEA.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\SimCoreTests.mq5"; Target = "MQL5\Scripts\SimCoreTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\SimPlanTests.mq5"; Target = "MQL5\Scripts\SimPlanTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\TrendRiderContractTests.mq5"; Target = "MQL5\Scripts\TrendRiderContractTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\ExecGuardTests.mq5"; Target = "MQL5\Scripts\ExecGuardTests.mq5" },
    [pscustomobject]@{ Source = "mt5\Scripts\ExecDemoProbe.mq5"; Target = "MQL5\Scripts\ExecDemoProbe.mq5" }
)

$compileTargets = @(
    "MQL5\Indicators\PinePort\Wonderwhales.mq5",
    "MQL5\Scripts\WonderwhalesContractTests.mq5",
    "MQL5\Indicators\PinePort\LongKacoVSA.mq5",
    "MQL5\Scripts\LongKacoVSAContractTests.mq5",
    "MQL5\Indicators\PinePort\TMFusionZones.mq5",
    "MQL5\Scripts\TMFusionZonesContractTests.mq5",
    "MQL5\Indicators\PinePort\PriceActionMTF.mq5",
    "MQL5\Scripts\PriceActionMTFContractTests.mq5",
    "MQL5\Indicators\PinePort\TMXAUSignals2.mq5",
    "MQL5\Scripts\TMXAUSignals2ContractTests.mq5",
    "MQL5\Indicators\PinePort\TMIndicator2.mq5",
    "MQL5\Scripts\TMIndicator2ContractTests.mq5",
    "MQL5\Experts\PineSignalLabEA.mq5",
    "MQL5\Experts\PineMultiSignalLabEA.mq5",
    "MQL5\Scripts\SimCoreTests.mq5",
    "MQL5\Scripts\SimPlanTests.mq5",
    "MQL5\Experts\RunnerTrailingLabEA.mq5",
    "MQL5\Experts\GridLabEA.mq5",
    "MQL5\Experts\DCALabEA.mq5",
    "MQL5\Experts\PinePlanSimEA.mq5",
    "MQL5\Experts\WonderwhalesSimEA.mq5",
    "MQL5\Scripts\TrendRiderContractTests.mq5",
    "MQL5\Experts\PATrendRiderXAUv1SimEA.mq5",
    "MQL5\Scripts\ExecGuardTests.mq5",
    "MQL5\Scripts\ExecDemoProbe.mq5",
    "MQL5\Experts\PATrendRiderXAUv1DemoEA.mq5"
)

function Get-TerminalCandidates {
    $base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (-not (Test-Path -LiteralPath $base)) {
        return @()
    }
    return @(
        Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "MQL5\Experts") } |
            Select-Object -ExpandProperty FullName
    )
}

function Get-HashSafe {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
    return $null
}

function Read-Utf16Log {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

if (-not $TerminalDataDir) {
    $candidates = @(Get-TerminalCandidates)
    if ($candidates.Count -eq 0) {
        Write-Host "FAIL: no MT5 data folder found under %APPDATA%\MetaQuotes\Terminal" -ForegroundColor Red
        Write-Host "Open MT5 > File > Open Data Folder, then pass -TerminalDataDir <path containing MQL5>."
        exit 2
    }
    if ($candidates.Count -gt 1 -and $Apply) {
        Write-Host "FAIL: multiple MT5 data folders found; pass -TerminalDataDir explicitly." -ForegroundColor Red
        $candidates | ForEach-Object { Write-Host "  $_" }
        exit 2
    }
    $TerminalDataDir = $candidates[0]
    if ($candidates.Count -gt 1) {
        Write-Host "Multiple data folders found; dry run uses the first one:"
        $candidates | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $TerminalDataDir "MQL5\Experts"))) {
    Write-Host "FAIL: $TerminalDataDir does not contain MQL5\Experts" -ForegroundColor Red
    exit 2
}

Write-Host "Data folder: $TerminalDataDir"
if (-not $Apply) {
    Write-Host "Mode: DRY RUN (add -Apply to copy)"
}

$plan = @()
$toCopy = @()
$conflicts = 0

foreach ($file in $files) {
    $sourcePath = Join-Path $ProjectRoot $file.Source
    $targetPath = Join-Path $TerminalDataDir $file.Target
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Host "FAIL: source missing: $sourcePath" -ForegroundColor Red
        exit 2
    }
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $targetHash = Get-HashSafe -Path $targetPath
    if ($null -eq $targetHash) {
        $action = "create"
    }
    elseif ($targetHash -eq $sourceHash) {
        $action = "identical"
    }
    elseif ($Force) {
        $action = "overwrite"
    }
    else {
        $action = "conflict"
        $conflicts++
    }
    if ($action -eq "create" -or $action -eq "overwrite") {
        $toCopy += [pscustomobject]@{ Source = $sourcePath; Target = $targetPath }
    }
    $plan += [pscustomobject]@{ File = $file.Target; Action = $action }
}

$plan | Format-Table -AutoSize | Out-String | Write-Host

if (-not $Apply) {
    Write-Host "No files were copied. Re-run with -Apply to deploy."
    exit 0
}

if ($conflicts -gt 0) {
    Write-Host "FAIL: $conflicts target file(s) differ; re-run with -Force to overwrite them." -ForegroundColor Red
    exit 2
}

foreach ($item in $toCopy) {
    $directory = Split-Path -Parent $item.Target
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
    Write-Host "COPIED: $($item.Target)"
}

if ($SkipCompile) {
    Write-Host "SKIPPED_COMPILE: files copied; compile them manually."
    exit 0
}

if (-not (Test-Path -LiteralPath $MetaEditorPath)) {
    Write-Host "FAIL: MetaEditor not found: $MetaEditorPath" -ForegroundColor Red
    Write-Host "Files were copied. Set -MetaEditorPath and re-run, or compile manually."
    exit 2
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$failures = 0
foreach ($relative in $compileTargets) {
    $sourcePath = Join-Path $TerminalDataDir $relative
    $name = [System.IO.Path]::GetFileNameWithoutExtension($relative)
    $logPath = Join-Path $LogDir ("{0}.log" -f $name)
    if (Test-Path -LiteralPath $logPath) {
        Remove-Item -LiteralPath $logPath -Force
    }

    Write-Host "Compiling $relative"
    & $MetaEditorPath "/compile:$sourcePath" "/log:$logPath" | Out-Null
    $cliExit = $LASTEXITCODE

    if (-not (Test-Path -LiteralPath $logPath)) {
        Write-Host "FAIL: MetaEditor wrote no log for $relative (cli exit $cliExit)" -ForegroundColor Red
        $failures++
        continue
    }

    $text = Read-Utf16Log -Path $logPath
    $match = [regex]::Match($text, "Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?")
    if (-not $match.Success) {
        Write-Host "FAIL: no Result line in $logPath" -ForegroundColor Red
        $failures++
        continue
    }

    $errors = [int]$match.Groups[1].Value
    $warnings = [int]$match.Groups[2].Value
    if ($errors -ne 0 -or $warnings -ne 0) {
        Write-Host ("FAIL: {0} error(s), {1} warning(s); log={2}" -f $errors, $warnings, $logPath) -ForegroundColor Red
        $failures++
    }
    else {
        Write-Host ("PASS: 0 errors, 0 warnings (cli exit {0})" -f $cliExit) -ForegroundColor Green
    }
}

if ($failures -gt 0) {
    Write-Host "DEPLOY_FAILED: $failures of $($compileTargets.Count) source(s) failed to compile." -ForegroundColor Red
    exit 1
}

Write-Host "DEPLOY_OK: files copied and compiled with 0 errors and 0 warnings."
Write-Host ""
Write-Host "Manual runtime checks (this script does not start the terminal):"
Write-Host "  1. Open MT5, drag Scripts > WonderwhalesContractTests onto a chart."
Write-Host "     Experts tab must show: TEST|RESULT|ALL_PASS|pass=36 fail=0|contract=1.0.0"
Write-Host "  2. Drag Scripts > LongKacoVSAContractTests and Scripts > TMFusionZonesContractTests."
Write-Host "     Each must print TEST|RESULT|ALL_PASS (TM FZ: pass=82 fail=0)."
Write-Host "  3. Drag Scripts > PriceActionMTFContractTests, TMXAUSignals2ContractTests and TMIndicator2ContractTests."
Write-Host "     Each must print TEST|RESULT|ALL_PASS (TM XAU2: pass=107 fail=0; TM Indicator 2: 155 vectors)."
Write-Host "  4. Attach Indicators > PinePort > Wonderwhales, LongKacoVSA, TMFusionZones, PriceActionMTF, TMXAUSignals2 or TMIndicator2."
Write-Host "  5. Attach Experts > PineSignalLabEA; CSV is written to MQL5\Files\pine_signal_log.csv."
Write-Host "     Attach Experts > PineMultiSignalLabEA; CSV is written to MQL5\Files\pine_multi_signal_log.csv."
Write-Host "  6. Audit the CSV: python scripts\audit_signal_csv.py --csv <csv> --offset-minutes 180"
Write-Host "     or: python scripts\audit_multi_signal_csv.py --csv <csv>"
Write-Host "  7. Parity (needs a real Pine reference export): python scripts\compare_multi_signal_exports.py --reference <pine.csv> --mql5 <csv> --mql5-offset-minutes 180"
Write-Host "  8. Scripts > ExecGuardTests must print ALL_PASS (pass=51 fail=0) before PATrendRiderXAUv1DemoEA"
Write-Host "     is attached to a chart. See docs\guides\demo-execution.md: dry-run first, demo account only."
Write-Host "  9. Scripts > ExecDemoProbe with InpConfirm=false must print PROBE|DRY|all_guards_pass."
Write-Host "     Set InpConfirm=true only to prove the demo broker accepts one guarded order; the probe"
Write-Host "     closes its own position immediately and never runs in the Strategy Tester."
exit 0
