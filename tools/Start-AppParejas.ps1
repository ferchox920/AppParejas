param([string]$GodotPath = '', [switch]$Editor)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$engine = & (Join-Path $PSScriptRoot 'Get-Godot.ps1') -GodotPath $GodotPath
$appRoot = Join-Path $repoRoot 'app'
if ($Editor) {
    & $engine --path $appRoot --editor
} else {
    & $engine --path $appRoot
}
if ($LASTEXITCODE -ne 0) { throw 'Godot terminó con un error.' }
