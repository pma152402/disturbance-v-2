# Valida rutas literales de recursos; excluye fuentes archivadas y cachés.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$missing = @()
Get-ChildItem -LiteralPath $projectRoot -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\(\.godot|\.git|source_assets|output)\\' -and
    $_.Extension -in @('.gd', '.tscn', '.tres', '.godot', '.gdshader')
} | ForEach-Object {
    $source = $_.FullName
    $content = [IO.File]::ReadAllText($source)
    foreach ($match in [regex]::Matches($content, 'res://[^"\s]+\.(?:gdshader|tscn|tres|gd)(?=["\s])')) {
        $resource = $match.Value
        if ($resource.Contains('%')) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $resource.Substring(6)))) {
            $missing += "$source : $resource"
        }
    }
}
if ($missing.Count) { $missing | Sort-Object -Unique | Write-Output; exit 1 }
Write-Output 'OK: todas las rutas literales de recursos existen.'
