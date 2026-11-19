#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $# != 2 || ! "$2" =~ ^([[:xdigit:]]{40}|[[:xdigit:]]{64})$ ]]; then
    printf 'Uso: %s DIRECTORIO_DE_RESPALDOS HUELLA_COMPLETA_GPG\n' "$0" >&2
    exit 2
fi

: "${APPPAREJAS_BACKUP_SOURCE:?Indicá la referencia de Supabase en APPPAREJAS_BACKUP_SOURCE}"
destination=$1
recipient=$2
cli=${SUPABASE_BIN:-supabase}
mkdir -p -- "$destination"
destination=$(cd -- "$destination" && pwd -P)
stage=$(mktemp -d -- "$destination/.appparejas-XXXXXXXX")
archive="$destination/appparejas-$(date -u +%Y%m%dT%H%M%SZ)-${stage##*-}"

cleanup() {
    if [[ -d "$stage" ]]; then
        for part in roles schema data; do
            if [[ -f "$stage/$part.sql.gpg" ]]; then
                unlink "$stage/$part.sql.gpg"
            fi
        done
        if [[ -f "$stage/SHA256SUMS" ]]; then
            unlink "$stage/SHA256SUMS"
        fi
        rmdir -- "$stage"
    fi
}
trap cleanup EXIT

encrypt_dump() {
    local part=$1
    shift
    "$cli" db dump "--remote=$APPPAREJAS_BACKUP_SOURCE" "$@" |
        gpg --batch --trust-model always --recipient "$recipient" --output "$stage/$part.sql.gpg" --encrypt
    test -s "$stage/$part.sql.gpg"
}

encrypt_dump roles --role-only
encrypt_dump schema --schema public,app_private,supabase_migrations
encrypt_dump data --data-only --use-copy --schema auth,public,app_private,supabase_migrations --exclude auth.schema_migrations
(
    cd -- "$stage"
    sha256sum roles.sql.gpg schema.sql.gpg data.sql.gpg > SHA256SUMS
)
mv -T -- "$stage" "$archive"
printf '%s\n' "$archive"
