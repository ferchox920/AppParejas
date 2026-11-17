param([string]$PostgresBin = 'C:/Program Files/PostgreSQL/17/bin')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
    & python3 (Join-Path $repoRoot 'tools/Test-Backend.py')
    if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas del backend.' }
    return
}
$testRoot = Join-Path $repoRoot '.artifacts/backend'
$clusterPath = Join-Path $repoRoot '.tools/postgres-tests'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $clusterPath 'PG_VERSION'))) {
    & (Join-Path $PostgresBin 'initdb.exe') -D $clusterPath -U appparejas_test -A trust --encoding=UTF8 --locale=C | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar la base aislada.' }
}
$port = 54329
$db = 'appparejas_checks_' + [DateTime]::UtcNow.Ticks
$started = $false
try {
    $startProcess = Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') -ArgumentList @('-D', ('"' + $clusterPath + '"'), '-l', ('"' + (Join-Path $testRoot 'postgres.log') + '"'), '-o', ('"-h 127.0.0.1 -p ' + $port + '"'), '-w', 'start') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $testRoot 'start.log') -RedirectStandardError (Join-Path $testRoot 'start-errors.log')
    if (-not $startProcess.WaitForExit(15000)) { throw 'Se agotó el tiempo para iniciar la base de pruebas.' }
    if ($startProcess.ExitCode -ne 0) { throw 'No se pudo iniciar la base aislada. No se usa la instancia PostgreSQL del sistema.' }
    $started = $true
    & (Join-Path $PostgresBin 'createdb.exe') -h 127.0.0.1 -p $port -U appparejas_test $db
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la base de pruebas.' }
    try {
        & python (Join-Path $repoRoot 'tools/Test-Backend.py') --native (Join-Path $PostgresBin 'psql.exe') $port $db
        if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas del backend.' }
    } finally {
        & (Join-Path $PostgresBin 'dropdb.exe') -h 127.0.0.1 -p $port -U appparejas_test $db
        if ($LASTEXITCODE -ne 0) { Write-Warning "No se pudo eliminar la base de pruebas $db." }
    }
} finally {
    if ($started) { & (Join-Path $PostgresBin 'pg_ctl.exe') -D $clusterPath -m fast -w stop | Out-Null }
}
