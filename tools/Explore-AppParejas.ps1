param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$engine = & (Join-Path $PSScriptRoot 'Get-Godot.ps1') -GodotPath $GodotPath
$appRoot = Join-Path $repoRoot 'app'
$artifactRoot = Join-Path $repoRoot '.artifacts/exploration'
New-Item -ItemType Directory -Force $artifactRoot | Out-Null
$importLog = & $engine --headless --path $appRoot --editor --quit 2>&1
if ($LASTEXITCODE -ne 0 -or $importLog -match 'SCRIPT ERROR:|ERROR:') {
    throw 'Falló la importación antes de explorar la demostración.'
}
# La escena inyecta el proveedor local y usa archivos propios de prueba.
# No carga cuentas ni envía correos aunque exista configuración Supabase.
$log = & $engine --path $appRoot res://tests/autonomous_demo.tscn --quit-after 600 2>&1
$exitCode = $LASTEXITCODE
$log | Set-Content (Join-Path $artifactRoot 'desktop-direct.log') -Encoding utf8
$log | Write-Output
if ($exitCode -ne 0 -or $log -match 'SCRIPT ERROR:|ERROR:|EXPLORACION: FALLO' -or
    -not ($log -match 'EXPLORACION FINAL: \d+ verificaciones, 0 fallos')) {
    throw 'La exploración no completó el recorrido y las capturas sin fallos.'
}
