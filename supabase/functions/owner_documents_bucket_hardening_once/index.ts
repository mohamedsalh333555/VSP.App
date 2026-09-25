import { createClient } from "npm:@supabase/supabase-js@2.57.4";

declare const Deno: any;

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "GET") return new Response("Not found", { status: 404 });

    const url = new URL(req.url);
    const token = url.searchParams.get("token") || "";
    if (!token) return new Response("Not found", { status: 404 });

    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    if (!supabaseUrl || !serviceRoleKey) return new Response("Server unavailable", { status: 503 });

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: row } = await admin
      .from("internal_function_secrets")
      .select("secret")
      .eq("name", "owner_documents_bucket_hardening_once")
      .maybeSingle();

    if (!row?.secret || row.secret !== token) {
      return new Response("Not found", { status: 404 });
    }

    const { data, error } = await admin.storage.updateBucket("owner_documents", {
      public: false,
      fileSizeLimit: "10MB",
    });

    await admin
      .from("internal_function_secrets")
      .delete()
      .eq("name", "owner_documents_bucket_hardening_once")
      .eq("secret", token);

    if (error) {
      return new Response(JSON.stringify({ success: false, error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      success: true,
      bucket: "owner_documents",
      public: data?.public ?? false,
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ success: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
