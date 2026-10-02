param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$toolchain = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json

if (-not $GodotPath) { $GodotPath = $env:APPPAREJAS_GODOT }
if (-not $GodotPath) {
    $engineRoot = Join-Path $repoRoot '.tools/godot'
    $versionRoot = Join-Path $engineRoot $toolchain.godot_version
    $GodotPath = Join-Path $versionRoot ("Godot_v" + $toolchain.godot_version + '-stable_win64_console.exe')
    if (-not (Test-Path -LiteralPath $GodotPath)) {
        New-Item -ItemType Directory -Path $engineRoot -Force | Out-Null
        $archive = Join-Path $engineRoot ("Godot_v" + $toolchain.godot_version + '-stable_win64.exe.zip')
        if (-not (Test-Path -LiteralPath $archive)) {
            Write-Host 'Descargando la versión de Godot fijada para AppParejas...'
            Invoke-WebRequest -Uri $toolchain.windows_archive_url -OutFile $archive
        }
        $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        if ($archiveHash.ToLowerInvariant() -ne $toolchain.windows_archive_sha256) {
            throw 'El paquete de Godot no coincide con el SHA256 registrado. Revisar el archivo antes de extraerlo.'
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $versionRoot -Force
    }
}
$resolved = (Resolve-Path -LiteralPath $GodotPath).Path
$version = & $resolved --version
if ($LASTEXITCODE -ne 0 -or -not ($version -match ('^' + [regex]::Escape($toolchain.godot_version) + '\.stable'))) {
    throw "Usar Godot $($toolchain.godot_version) estable. Versión recibida: $version"
}
Write-Output $resolved
