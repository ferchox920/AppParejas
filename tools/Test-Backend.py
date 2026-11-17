#!/usr/bin/env python3
"""Apply every migration and run the SQL and concurrency suites in PostgreSQL 17."""

import argparse
from pathlib import Path
import secrets
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "backend/tests"
DATABASE_PREFIX = "appparejas_checks_"


def run_suites(psql, database):
    migrations = sorted((ROOT / "backend/supabase/migrations").glob("*.sql"))
    suites = sorted(path for path in TESTS.glob("*.sql") if path.name != "bootstrap.sql")
    if not migrations or not suites:
        raise SystemExit("Faltan las migraciones o las suites SQL.")

    for path in [TESTS / "bootstrap.sql", *migrations, *suites]:
        print(f"BACKEND: {path.relative_to(ROOT)}", flush=True)
        result = subprocess.run(
            [*psql, "-d", database, "-Xq", "-v", "ON_ERROR_STOP=1", "-f", "-"],
            input=path.read_bytes(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=120,
        )
        if result.returncode:
            sys.stderr.write(result.stdout.decode("utf-8", errors="replace"))
            result.check_returncode()

    subprocess.run(
        [sys.executable, TESTS / "concurrency.py", database, *psql],
        check=True, timeout=120,
    )
    print(f"OK · {len(migrations)} migraciones y {len(suites)} suites SQL, más concurrencia.")


def run_in_docker():
    database = DATABASE_PREFIX + secrets.token_hex(8)
    container = database.replace("_", "-")
    user = "appparejas_test"
    subprocess.run(
        ["docker", "run", "--detach", "--name", container,
         "--env", f"POSTGRES_USER={user}", "--env", f"POSTGRES_DB={database}",
         "--env", f"POSTGRES_PASSWORD={secrets.token_hex(24)}", "postgres:17-alpine"],
        check=True, timeout=300, stdout=subprocess.DEVNULL,
    )
    try:
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            ready = subprocess.run(
                ["docker", "exec", container, "pg_isready", "-h", "127.0.0.1",
                 "-U", user, "-d", database],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5,
            )
            if ready.returncode == 0:
                break
            time.sleep(0.25)
        else:
            subprocess.run(["docker", "logs", "--tail", "30", container], timeout=10)
            raise SystemExit("PostgreSQL de pruebas no quedó listo.")

        run_suites(["docker", "exec", "-i", container, "psql", "-U", user], database)
    finally:
        subprocess.run(
            ["docker", "rm", "-fv", container], check=True, timeout=30,
            stdout=subprocess.DEVNULL,
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", nargs=3, metavar=("PSQL", "PORT", "DATABASE"),
                        help="Base descartable creada por Test-Backend.ps1")
    args = parser.parse_args()
    if args.native:
        psql, port, database = args.native
        if not database.startswith(DATABASE_PREFIX):
            parser.error("La base debe ser la base descartable de Test-Backend.ps1.")
        run_suites([psql, "-h", "127.0.0.1", "-p", port, "-U", "appparejas_test"], database)
    else:
        run_in_docker()


if __name__ == "__main__":
    main()
