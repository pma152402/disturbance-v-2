param(
    [string]$GodotPath = "",
    [int]$TimeoutSeconds = 210,
    [int]$Passes = 3,
    [int]$SampleFrames = 240,
    [int]$SettleFrames = 75,
    [switch]$SaveBaseline,
    [switch]$FailOnRegression
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $PSScriptRoot "output"
$currentReport = Join-Path $outputDir "performance_current.json"
$comparisonReport = Join-Path $outputDir "performance_comparison.md"
$logPath = Join-Path $outputDir "performance_benchmark.log"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $GodotPath = $command.Source
    } else {
        $desktopCandidate = Join-Path (Split-Path -Parent $projectRoot) "godot.exe"
        if (Test-Path -LiteralPath $desktopCandidate) { $GodotPath = $desktopCandidate }
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw "No se encontro Godot. Usa -GodotPath C:\ruta\godot.exe"
}

$existingIds = @(Get-Process -Name godot -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$godotArgs = @(
    "--path", $projectRoot,
    "--log-file", $logPath,
    "--script", "res://tools/performance_benchmark.gd",
    "--",
    "--passes=$Passes",
    "--sample-frames=$SampleFrames",
    "--settle-frames=$SettleFrames",
    "--watchdog-seconds=$($TimeoutSeconds - 10)"
)
if ($SaveBaseline) { $godotArgs += "--save-baseline" }
if ($FailOnRegression) { $godotArgs += "--fail-on-regression" }

$startedAt = Get-Date
$process = Start-Process -FilePath $GodotPath -ArgumentList $godotArgs -PassThru -WindowStyle Hidden
$deadline = $startedAt.AddSeconds($TimeoutSeconds)
$exitCode = 0
$timedOut = $false

try {
    while ((Get-Date) -lt $deadline) {
        $newProcesses = @(Get-Process -Name godot -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin $existingIds })
        if ($newProcesses.Count -eq 0 -and $process.HasExited) {
            $exitCode = $process.ExitCode
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if ((Get-Date) -ge $deadline) {
        $timedOut = $true
        throw "El benchmark supero el limite de $TimeoutSeconds segundos."
    }
}
finally {
    if ($timedOut) {
        $newProcesses = @(Get-Process -Name godot -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin $existingIds })
        foreach ($newProcess in $newProcesses) {
            Stop-Process -Id $newProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($exitCode -ne 0) { throw "Godot termino con codigo $exitCode. Revisa $logPath" }
if (-not (Test-Path -LiteralPath $currentReport) -or (Get-Item -LiteralPath $currentReport).LastWriteTime -lt $startedAt) {
    throw "Godot termino sin generar una medicion nueva. Revisa $logPath"
}

Write-Host "Benchmark terminado."
Write-Host "Datos:   $currentReport"
Write-Host "Informe: $comparisonReport"
