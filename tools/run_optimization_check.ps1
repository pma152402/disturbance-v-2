param(
    [Parameter(Mandatory = $true)][string]$Script,
    [string]$GodotPath = "",
    [int]$TimeoutSeconds = 180,
    [switch]$Headless,
    [string[]]$ScriptArguments = @()
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($Script -notmatch '^res://tools/[a-zA-Z0-9_]+\.gd$') {
    throw "Usa un script de validacion o diagnostico de res://tools/."
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path (Split-Path -Parent $projectRoot) "godot.exe"
}
$label = [IO.Path]::GetFileNameWithoutExtension($Script)
$logPath = Join-Path $PSScriptRoot "output/audit_$label.log"
$arguments = @("--path", ('"' + $projectRoot + '"'), "--log-file", ('"' + $logPath + '"'), "--script", $Script)
if ($Headless) { $arguments += "--headless" }
if ($ScriptArguments.Count -gt 0) { $arguments += "--"; $arguments += $ScriptArguments }
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -PassThru -WindowStyle Hidden
# Solo se espera y, en caso de timeout, se detiene el proceso que iniciamos.
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "Timeout de $label. Consulta $logPath."
}
$process.Refresh()
Get-Content -LiteralPath $logPath -Tail 25
if ($process.ExitCode -ne 0) { throw "Godot termino con codigo $($process.ExitCode): $label" }
if (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR:|Parse Error:|Assertion failed|Error calling deferred method:' -Quiet) {
    throw "La validacion produjo errores de script: $label"
}
