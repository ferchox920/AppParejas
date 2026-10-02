param(
    [string]$GodotPath = '',
    [string]$JavaSdkPath = '',
    [string]$AndroidSdkPath = '',
    [switch]$Install,
    [string]$DeviceSerial = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$engine = & (Join-Path $PSScriptRoot 'Get-Godot.ps1') -GodotPath $GodotPath
if (-not $JavaSdkPath) { $JavaSdkPath = $env:JAVA_HOME }
if (-not $JavaSdkPath) {
    $javaCommand = Get-Command java -ErrorAction Stop
    $JavaSdkPath = Split-Path -Parent (Split-Path -Parent $javaCommand.Source)
}
if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_HOME }
if (-not $AndroidSdkPath) { $AndroidSdkPath = Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
if (-not (Test-Path (Join-Path $JavaSdkPath 'bin/keytool.exe'))) { throw 'No se encontró el JDK. Pasar -JavaSdkPath.' }
$adb = Join-Path $AndroidSdkPath 'platform-tools/adb.exe'
if (-not (Test-Path $adb)) { throw 'No se encontró Android SDK. Pasar -AndroidSdkPath.' }
$appRoot = Join-Path $repoRoot 'app'
$outputRoot = Join-Path $repoRoot 'build/android'
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$settingsPath = Join-Path $env:APPDATA 'Godot/editor_settings-4.7.tres'
if (-not (Test-Path $settingsPath)) {
    & $engine --headless --path $appRoot --editor --quit
    if ($LASTEXITCODE -ne 0) { throw 'Falló la inicialización del editor.' }
}
$settingsText = Get-Content -LiteralPath $settingsPath -Raw
$settingsBackup = Join-Path $outputRoot 'editor-settings.before-android.tres'
if (-not (Test-Path $settingsBackup)) { Copy-Item -LiteralPath $settingsPath -Destination $settingsBackup }
foreach ($setting in @(
    @{ Key = 'export/android/java_sdk_path'; Value = $JavaSdkPath },
    @{ Key = 'export/android/android_sdk_path'; Value = $AndroidSdkPath }
)) {
    $settingLine = $setting.Key + ' = "' + $setting.Value.Replace('\', '/') + '"'
    $pattern = '(?m)^' + [regex]::Escape($setting.Key) + ' = .*\r?$'
    if ([regex]::IsMatch($settingsText, $pattern)) {
        $settingsText = [regex]::Replace($settingsText, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $settingLine })
    } else { $settingsText += "`n$settingLine`n" }
}
Set-Content -LiteralPath $settingsPath -Value $settingsText -Encoding utf8
$apk = Join-Path $outputRoot 'AppParejas-debug.apk'
$exportLog = & $engine --headless --path $appRoot --export-debug Android $apk 2>&1
$exportExit = $LASTEXITCODE
$exportLog | Set-Content (Join-Path $outputRoot 'export.log') -Encoding utf8
$exportLog | Write-Output
if ($exportExit -ne 0 -or ($exportLog -match 'ERROR:|SCRIPT ERROR:') -or -not (Test-Path $apk)) {
    throw 'Falló la exportación Android. Consultar build/android/export.log y docs/ANDROID.md.'
}
Write-Host "APK generado: $apk"
if ($Install) {
    $deviceArgs = @()
    if ($DeviceSerial) { $deviceArgs = @('-s', $DeviceSerial) }
    & $adb @deviceArgs install -r $apk
    if ($LASTEXITCODE -ne 0) { throw 'Falló la instalación. Verificar adb devices o pasar -DeviceSerial.' }
    & $adb @deviceArgs shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p org.appparejas.preview
    if ($LASTEXITCODE -ne 0) { throw 'Falló el inicio de la app.' }
}
