[CmdletBinding()]
param([string]$ProjectRoot = (Get-Location).Path)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $ProjectRoot).Path
$venvPython = Join-Path $root '.venv/Scripts/python.exe'
$pythonExe = if (Test-Path $venvPython) { $venvPython } else { (Get-Command python -ErrorAction Stop).Source }
$testDir = Join-Path $root 'python/tests'
$reportDir = Join-Path $root 'reports/tests'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
if (-not (Test-Path $testDir)) { throw "Test directory missing: $testDir" }
$log = Join-Path $reportDir ("pytest-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
Push-Location $root
try {
    & $pythonExe -m pytest $testDir -q 2>&1 | Tee-Object -FilePath $log
    $code = $LASTEXITCODE
} finally { Pop-Location }
if ($code -ne 0) { Write-Error "pytest failed or collected no passing tests. See $log"; exit $code }
Write-Host "pytest passed. Log: $log"
