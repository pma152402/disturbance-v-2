param(
    [string]$GodotPath = "",
    [int]$TimeoutSeconds = 300,
    [switch]$WalkingHud
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $command) { $GodotPath = $command.Source }
    else { $GodotPath = Join-Path (Split-Path -Parent $projectRoot) "godot.exe" }
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Usa -GodotPath con la ruta al ejecutable de Godot." }
$outputDir = Join-Path $PSScriptRoot "output"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$reportPath = Join-Path $outputDir "recording_current.json"
$logPath = Join-Path $outputDir "recording_benchmark.log"
$arguments = @(
    '--path', ('"{0}"' -f $projectRoot),
    '--log-file', ('"{0}"' -f $logPath),
    '--script', 'res://tools/benchmark_recording.gd',
    '--', "--watchdog-seconds=$($TimeoutSeconds - 10)"
)
if ($WalkingHud) { $arguments += '--walking-hud' }
$startedAt = Get-Date
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
try {
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        # Stop only our process, never another editor or game launched meanwhile.
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "El benchmark supero $TimeoutSeconds segundos. Revisa $logPath"
    }
    if ($process.ExitCode -ne 0) { throw "Godot termino con codigo $($process.ExitCode). Revisa $logPath" }
    if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTime -lt $startedAt) {
        throw "No se genero un informe nuevo. Revisa $logPath"
    }
    Write-Host "Benchmark A/B completado: $reportPath"
} finally {
    $process.Dispose()
}
