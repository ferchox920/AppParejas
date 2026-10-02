param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$engine = & (Join-Path $PSScriptRoot 'Get-Godot.ps1') -GodotPath $GodotPath
$appRoot = Join-Path $repoRoot 'app'
$artifactRoot = Join-Path $repoRoot '.artifacts/init'
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
$importLog = & $engine --headless --path $appRoot --editor --quit 2>&1
$importExit = $LASTEXITCODE
$importLog | Set-Content -LiteralPath (Join-Path $artifactRoot 'import.log') -Encoding utf8
if ($importExit -ne 0 -or ($importLog -match 'SCRIPT ERROR:|ERROR:')) {
    $importLog | Write-Output
    throw 'Falló la importación del proyecto.'
}
$testLog = & $engine --headless --path $appRoot --script res://tests/run_tests.gd 2>&1
$testExit = $LASTEXITCODE
$testLog | Set-Content -LiteralPath (Join-Path $artifactRoot 'tests.log') -Encoding utf8
$testLog | Write-Output
if ($testExit -ne 0 -or ($testLog -match 'SCRIPT ERROR:|ERROR:')) {
    throw 'Fallaron las verificaciones de AppParejas.'
}
$openingLog = & $engine --headless --path $appRoot --script res://tests/first_open_tests.gd 2>&1
$openingExit = $LASTEXITCODE
$openingLog | Set-Content -LiteralPath (Join-Path $artifactRoot 'first-open-tests.log') -Encoding utf8
$openingLog | Write-Output
if ($openingExit -ne 0 -or ($openingLog -match 'SCRIPT ERROR:|ERROR:')) {
    throw 'Fallaron las verificaciones de primera apertura.'
}
