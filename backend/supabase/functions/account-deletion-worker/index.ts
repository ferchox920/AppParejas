// Administrative queue consumer. Supabase injects the service key on the server.
const baseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function rpc(name: string, body: Record<string, unknown>, authorization: string) {
  const response = await fetch(baseUrl + "/rest/v1/rpc/" + name, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: authorization,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error("database");
  const result = await response.json();
  if (result.ok !== true) throw new Error("database");
  return result;
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  const authorization = request.headers.get("Authorization");
  if (!serviceKey || !authorization?.startsWith("Bearer ")) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }
  let job;
  try {
    job = (await rpc("claim_account_deletion", {}, authorization)).job;
    if (!job) return Response.json({ ok: true, processed: 0 });
    const lease = { job_id: job.id, lease_token: job.lease_token };
    try {
      await rpc("purge_account_data", lease, authorization);
      const deleted = await fetch(baseUrl + "/auth/v1/admin/users/" + job.user_id, {
        method: "DELETE",
        headers: { apikey: serviceKey, Authorization: authorization },
        signal: AbortSignal.timeout(20000),
      });
      if (!deleted.ok && deleted.status !== 404) throw new Error("admin_auth");
      await rpc("finish_account_deletion", lease, authorization);
      return Response.json({ ok: true, processed: 1 });
    } catch (error) {
      const code = error instanceof Error && ["database", "admin_auth"].includes(error.message)
        ? error.message : "transport";
      await rpc("retry_account_deletion", { ...lease, error_code: code }, authorization);
      return Response.json({ ok: false, retry_scheduled: true }, { status: 503 });
    }
  } catch {
    return Response.json({ ok: false, retry_scheduled: false }, { status: 503 });
  }
});
