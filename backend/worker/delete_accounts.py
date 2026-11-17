#!/usr/bin/env python3
"""Process account deletion tasks using a server-only Supabase service key."""

import argparse
import json
import os
import time
import urllib.error
import urllib.request


class DeletionError(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


def request(base_url, key, path, body=None, method="POST"):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        base_url + path,
        data=data,
        method=method,
        headers={
            "apikey": key,
            "Authorization": "Bearer " + key,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            data = response.read()
            result = json.loads(data) if data else {"ok": True}
    except urllib.error.HTTPError as error:
        if method == "DELETE" and error.code == 404:
            return {"ok": True}
        raise DeletionError("admin_auth" if method == "DELETE" else "database") from None
    except (urllib.error.URLError, TimeoutError, ValueError):
        raise DeletionError("transport") from None
    if isinstance(result, dict) and result.get("ok") is False:
        raise DeletionError("database")
    return result


def process_one(base_url, key):
    result = request(base_url, key, "/rest/v1/rpc/claim_account_deletion", {})
    job = result.get("job")
    if job is None:
        return False
    lease = {"job_id": job["id"], "lease_token": job["lease_token"]}
    try:
        request(base_url, key, "/rest/v1/rpc/purge_account_data", lease)
        request(base_url, key, "/auth/v1/admin/users/" + job["user_id"], method="DELETE")
        request(base_url, key, "/rest/v1/rpc/finish_account_deletion", lease)
        print("Eliminación completada", flush=True)
    except DeletionError as error:
        # No registrar identidades, respuestas HTTP, tokens ni textos personales.
        print("Eliminación pendiente de reintento: " + error.code, flush=True)
        request(
            base_url,
            key,
            "/rest/v1/rpc/retry_account_deletion",
            dict(lease, error_code=error.code),
        )
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--loop", action="store_true", help="Consultar tareas cada 30 segundos")
    args = parser.parse_args()
    base_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not base_url.startswith("https://") or not key:
        parser.error("Configurar SUPABASE_URL HTTPS y SUPABASE_SERVICE_ROLE_KEY en el entorno del servidor")
    while True:
        try:
            handled = process_one(base_url, key)
        except DeletionError as error:
            print("No se pudo procesar la cola: " + error.code, flush=True)
            if not args.loop:
                return 1
            handled = False
        if not args.loop:
            return 0
        if not handled:
            time.sleep(30)


if __name__ == "__main__":
    raise SystemExit(main())
