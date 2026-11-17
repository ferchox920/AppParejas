#!/usr/bin/env bash
set -euo pipefail

toolchain="$(dirname "${BASH_SOURCE[0]}")/toolchain.json"
read -r version flavor checksum < <(python3 -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as config:
    data = json.load(config)
print(data["godot_version"], data["godot_flavor"], data["linux_archive_sha256"])
' "$toolchain")

destination="$1"
asset="Godot_v${version}-${flavor}_linux.x86_64"
mkdir -p "$destination"
archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT
curl --fail --silent --show-error --location --retry 3 \
    "https://github.com/godotengine/godot-builds/releases/download/${version}-${flavor}/${asset}.zip" \
    --output "$archive"
printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check >&2
unzip -oq "$archive" -d "$destination"
printf '%s\n' "$(realpath "$destination/$asset")"
