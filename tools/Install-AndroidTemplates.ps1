$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$toolchain = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$cacheRoot = Join-Path $repoRoot '.tools/android'
New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
$archivePath = Join-Path $cacheRoot ("Godot_v" + $toolchain.godot_version + '-stable_export_templates.tpz')
if (-not (Test-Path $archivePath)) {
    Write-Host 'Descargando plantillas oficiales (aproximadamente 1,3 GB)...'
    Invoke-WebRequest -Uri $toolchain.android_templates_url -OutFile $archivePath
}
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA512).Hash.ToLowerInvariant()
if ($archiveHash -ne $toolchain.android_templates_sha512) { throw 'Las plantillas no coinciden con el SHA512 oficial fijado.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $templateRoot = Join-Path $env:APPDATA ("Godot/export_templates/" + $toolchain.godot_version + '.stable')
    New-Item -ItemType Directory -Path $templateRoot -Force | Out-Null
    foreach ($templateName in @('android_debug.apk', 'android_release.apk', 'version.txt')) {
        $entry = $archive.GetEntry("templates/$templateName")
        if (-not $entry) { throw "No existe $templateName en el paquete." }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $templateRoot $templateName), $true)
    }
} finally { $archive.Dispose() }
Write-Host "Plantillas Android verificadas e instaladas en $templateRoot"
