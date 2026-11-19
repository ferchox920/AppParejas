#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
engine=${APPPAREJAS_GODOT:-godot}
verifier=${APPPAREJAS_APKSIGNER:-apksigner}
: "${APPPAREJAS_PILOT_URL:?Indicá la URL esperada en APPPAREJAS_PILOT_URL}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Falta la ruta al almacén de firma}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Falta el alias de firma}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Falta la contraseña de firma}"

output=${1:-"$root/build/android/AppParejas-piloto-candidato.apk"}
if [[ "$output" != *.apk ]]; then
    printf 'El destino debe terminar en .apk.\n' >&2
    exit 2
fi
mkdir -p -- "$(dirname -- "$output")"
output="$(cd -- "$(dirname -- "$output")" && pwd)/$(basename -- "$output")"
stage=$(mktemp -d -- "$(dirname -- "$output")/.android-pilot.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
mkdir "$stage/app"
tar -C "$root/app" --exclude=.godot --exclude=export_credentials.cfg -cf - . | tar -C "$stage/app" -xf -

cat > "$stage/check-config.gd" <<'GDSCRIPT'
extends SceneTree

func _initialize() -> void:
	var settings := BackendConfig.load_settings()
	var expected := OS.get_environment("APPPAREJAS_PILOT_URL").trim_suffix("/")
	if settings.get("mode") != "supabase" or settings.get("url") != expected:
		push_error("La candidata requiere la configuración HTTPS del proyecto esperado y una clave publicable.")
		quit(1)
		return
	quit()
GDSCRIPT

"$engine" --headless --path "$stage/app" --editor --import --quit
"$engine" --headless --path "$stage/app" --script "$stage/check-config.gd"
"$engine" --headless --path "$stage/app" --export-release 'Android piloto' "$stage/candidate.apk"
"$verifier" verify "$stage/candidate.apk"
mv -f -- "$stage/candidate.apk" "$output"
printf '%s\n' "$output"
