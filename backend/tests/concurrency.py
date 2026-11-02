"""Dos sesiones PostgreSQL reales; usar únicamente la base aislada de Test-Backend."""
import concurrent.futures
import json
import subprocess
import sys
import uuid

psql, database, port = sys.argv[1:]
assert database.startswith('appparejas_checks_')

def query(sql):
    result = subprocess.run([psql, '-X', '-qAt', '-h', '127.0.0.1', '-p', port,
                             '-U', 'appparejas_test', '-d', database, '-v', 'ON_ERROR_STOP=1'],
                            input=sql, capture_output=True, text=True, check=True)
    return result.stdout.strip().splitlines()[-1]

def actor_query(actor, sql):
    return json.loads(query(f"set role authenticated; set request.jwt.claim.sub = '{actor}'; {sql}"))

users = [str(uuid.uuid4()) for _ in range(5)]
query('insert into auth.users(id) values ' + ','.join(f"('{u}')" for u in users) + '; select 1;')
for i, user in enumerate(users):
    assert actor_query(user, f"select register_profile('Persona {i}',true);")['ok']

token = uuid.uuid4().hex
actor_query(users[0], f"select create_invitation('{token}','{uuid.uuid4()}');")
with concurrent.futures.ThreadPoolExecutor(2) as pool:
    futures = [pool.submit(actor_query, user, f"select accept_invitation('{token}','{uuid.uuid4()}');")
               for user in users[1:3]]
    results = [f.result() for f in futures]
assert sum(r['ok'] for r in results) == 1, results
assert query('select count(*) from app_private.pairs;') == '1'
assert query('select count(*) from app_private.pair_members where active;') == '2'

# Una misma cuenta acepta simultáneamente dos invitaciones diferentes.
recipient = users[1] if not results[0]['ok'] else users[2]
tokens = [uuid.uuid4().hex for _ in range(2)]
for user, secret in zip(users[3:], tokens):
    assert actor_query(user, f"select create_invitation('{secret}','{uuid.uuid4()}');")['ok']
with concurrent.futures.ThreadPoolExecutor(2) as pool:
    futures = [pool.submit(actor_query, recipient,
               f"select accept_invitation('{secret}','{uuid.uuid4()}');") for secret in tokens]
    results = [f.result() for f in futures]
assert sum(r['ok'] for r in results) == 1, results
assert query(f"select count(*) from app_private.pair_members where user_id = '{recipient}' and active;") == '1'
print('BACKEND: dos aceptaciones concurrentes y un vínculo máximo por cuenta aprobados.')
