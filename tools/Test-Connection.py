#!/usr/bin/env python3
"""Run the two-account connection test against a disposable local backend."""

import base64
from contextlib import ExitStack
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hmac
import json
import os
from pathlib import Path
import secrets
import shutil
import ssl
import subprocess
import sys
import tempfile
from threading import Thread
import time
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
HOST = "127.0.0.1"
ACCOUNTS = ("sol@example.test", "luna@example.test")


def run(*args, **kwargs):
    return subprocess.run(args, check=True, timeout=300, **kwargs)


def jwt(secret, role):
    def encode(data):
        return base64.urlsafe_b64encode(data).rstrip(b"=")
    body = encode(b'{"alg":"HS256","typ":"JWT"}') + b"." + encode(json.dumps({
        "role": role, "exp": int(time.time()) + 3600,
    }).encode())
    return (body + b"." + encode(hmac.digest(secret.encode(), body, "sha256"))).decode()


def wait_for(probe, name):
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        try:
            if probe():
                return
        except OSError:
            pass
        time.sleep(0.25)
    raise RuntimeError(f"{name} no quedó listo")


def request(port, path, token="", body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None if body is None else json.dumps(body).encode()
    return urlopen(Request(f"http://{HOST}:{port}{path}", data, headers), timeout=3)


def start_backend(stack, prefix):
    run("docker", "network", "create", prefix, stdout=subprocess.DEVNULL)
    stack.callback(run, "docker", "network", "rm", prefix, stdout=subprocess.DEVNULL)

    def container(name, image, options):
        full_name = f"{prefix}-{name}"
        run("docker", "run", "-d", "--name", full_name, "--network", prefix,
            "--network-alias", name, *options, image, stdout=subprocess.DEVNULL)
        stack.callback(run, "docker", "rm", "-fv", full_name, stdout=subprocess.DEVNULL)
        return full_name

    password = secrets.token_hex(16)
    secret = secrets.token_hex(32)
    database = container("db", "postgres:17-alpine", ["-e", f"POSTGRES_PASSWORD={password}"])

    def sql(statement):
        run("docker", "exec", "-i", database, "psql", "-Xq", "-U", "postgres",
            "-v", "ON_ERROR_STOP=1", input=statement, text=True)

    wait_for(lambda: subprocess.run(
        ["docker", "exec", database, "pg_isready", "-h", "127.0.0.1", "-U", "postgres"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5,
    ).returncode == 0, "PostgreSQL")
    sql("""
        create schema auth;
        create role anon nologin;
        create role authenticated nologin;
        create role service_role nologin;
        grant usage on schema auth to authenticated;
        create function auth.uid() returns uuid language sql stable as $$
          select (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid
        $$;
    """)

    db_url = f"postgres://postgres:{password}@db:5432/postgres"
    auth = container("auth", "supabase/gotrue:v2.177.0", [
        "-p", f"{HOST}::9999", "-e", "GOTRUE_API_HOST=0.0.0.0", "-e", "GOTRUE_API_PORT=9999",
        "-e", "API_EXTERNAL_URL=http://localhost", "-e", "GOTRUE_SITE_URL=http://localhost",
        "-e", "GOTRUE_DB_DRIVER=postgres", "-e", f"GOTRUE_DB_DATABASE_URL={db_url}?search_path=auth",
        "-e", "GOTRUE_DB_NAMESPACE=auth", "-e", f"GOTRUE_JWT_SECRET={secret}",
        "-e", "GOTRUE_JWT_ADMIN_ROLES=service_role", "-e", "GOTRUE_JWT_AUD=authenticated",
        "-e", "GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated", "-e", "GOTRUE_JWT_EXP=3600",
        "-e", "GOTRUE_EXTERNAL_EMAIL_ENABLED=true", "-e", "GOTRUE_MAILER_OTP_EXP=3600",
        "-e", "GOTRUE_MAILER_OTP_LENGTH=6",
    ])

    def published_port(name, port):
        return int(subprocess.check_output(
            ["docker", "port", name, f"{port}/tcp"], text=True, timeout=10,
        ).strip().rsplit(":", 1)[1])

    auth_port = published_port(auth, 9999)
    try:
        wait_for(lambda: request(auth_port, "/health").close() is None, "Supabase Auth")
    except RuntimeError:
        run("docker", "logs", "--tail", "15", auth)
        raise
    for migration in sorted((ROOT / "backend/supabase/migrations").glob("*.sql")):
        sql(migration.read_text())

    rest = container("rest", "postgrest/postgrest:v12.2.12", [
        "-p", f"{HOST}::3000", "-e", f"PGRST_DB_URI={db_url}",
        "-e", "PGRST_DB_SCHEMAS=public", "-e", "PGRST_DB_ANON_ROLE=anon",
        "-e", f"PGRST_JWT_SECRET={secret}",
    ])
    rest_port = published_port(rest, 3000)
    wait_for(lambda: request(rest_port, "/").close() is None, "PostgREST")

    def issue(email):
        with request(auth_port, "/admin/generate_link", jwt(secret, "service_role"),
                     {"email": email, "type": "signup", "password": secrets.token_urlsafe(24)}) as response:
            code = json.load(response)["email_otp"]
        if len(code) != 6 or not code.isascii() or not code.isdigit():
            raise RuntimeError("Auth no devolvió un OTP numérico de seis caracteres")
        return code

    expired = issue(ACCOUNTS[0])
    sql(f"""update auth.users set confirmation_sent_at = now() - interval '2 hours'
            where email = '{ACCOUNTS[0]}';""")
    return auth_port, rest_port, sql, issue, expired


def start_gateway(stack, work, auth_port, rest_port, sql):
    class Gateway(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path == "/fixture/expire-invitation":
                sql("""update app_private.invitations set expires_at = now() - interval '1 minute'
                        where status = 'active';""")
                self.send_response(204)
                self.end_headers()
                return
            # Only the verification and RPC routes are forwarded to the backend.
            if self.path == "/auth/v1/verify":
                port, route = auth_port, "/verify"
            elif self.path.startswith("/rest/v1/rpc/"):
                port, route = rest_port, self.path.removeprefix("/rest/v1")
            else:
                self.send_error(404)
                return
            headers = {"Content-Type": "application/json"}
            if self.headers.get("Authorization"):
                headers["Authorization"] = self.headers["Authorization"]
            upstream = HTTPConnection(HOST, port, timeout=8)
            try:
                upstream.request("POST", route, self.rfile.read(int(self.headers["Content-Length"])), headers)
                response = upstream.getresponse()
                data = response.read()
            finally:
                upstream.close()
            self.send_response(response.status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *_):
            pass

    cert, key = work / "test.crt", work / "test.key"
    run("openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
        "-subj", f"/CN={HOST}", "-addext", f"subjectAltName=IP:{HOST}",
        "-keyout", key, "-out", cert, stderr=subprocess.DEVNULL)
    tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls.load_cert_chain(cert, key)
    server = stack.enter_context(ThreadingHTTPServer((HOST, 0), Gateway))
    server.socket = tls.wrap_socket(server.socket, server_side=True)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    stack.callback(server.shutdown)
    return f"https://{HOST}:{server.server_port}", cert


def main():
    godot = os.environ.get("APPPAREJAS_GODOT", "godot")
    for executable in (godot, "docker", "openssl"):
        if not shutil.which(executable):
            raise SystemExit(f"Falta {executable}")
    with ExitStack() as stack:
        work = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="appparejas-test-")))
        app = work / "app"
        shutil.copytree(ROOT / "app", app, ignore=shutil.ignore_patterns(".godot", "connection.local.json"))
        venv = work / "venv"
        run(sys.executable, "-m", "venv", venv)
        decoder = venv / "bin/python"
        run(decoder, "-m", "pip", "install", "--disable-pip-version-check", "--quiet",
            "zxing-cpp==3.1.1", "Pillow==13.0.0")
        auth_port, rest_port, sql, issue, expired = start_backend(
            stack, f"appparejas-test-{secrets.token_hex(5)}",
        )
        url, cert = start_gateway(stack, work, auth_port, rest_port, sql)
        shutil.copyfile(cert, app / "connection-test.crt")
        (app / "override.cfg").write_text(
            '[network]\ntls/certificate_bundle_override="res://connection-test.crt"\n',
        )
        env = {
            **os.environ,
            "XDG_DATA_HOME": str(work / "user"),
            "XDG_CONFIG_HOME": str(work / "config"),
            "XDG_CACHE_HOME": str(work / "cache"),
        }
        run(godot, "--headless", "--path", app, "--import", env=env, stdout=subprocess.DEVNULL)
        # Run the expired case before generating its replacement, so Auth sees the original hash.
        command = [godot, "--headless", "--path", app, "--script", "res://tests/connection_e2e.gd"]
        settings = work / "settings.json"

        def client(**fixtures):
            settings.write_text(json.dumps({"url": url, "emails": ACCOUNTS, "decoder": str(decoder),
                                            "work": str(work), **fixtures}))
            run(*command, "--", str(settings), env=env)

        client(expired=expired)
        fresh = issue(ACCOUNTS[0])
        while fresh == expired:
            fresh = issue(ACCOUNTS[0])
        other = issue(ACCOUNTS[1])
        while other in (fresh, expired):
            other = issue(ACCOUNTS[1])
        client(fresh=fresh, other=other, expired=expired)
        sql("""
            do $$ begin
              if (select count(*) from app_private.profiles) <> 2
                 or (select count(*) from app_private.pairs where status = 'active') <> 1
                 or (select count(*) from app_private.pair_members where active) <> 2
              then raise exception 'Estado bilateral inesperado'; end if;
            end $$;
        """)
        print("OK · PostgreSQL confirma dos perfiles y un único vínculo activo con dos integrantes")


if __name__ == "__main__":
    main()
