import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { action, phone, role, token, platform, language } = await req.json();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (action === "save") {
      if (!phone || !role || !token || !platform) {
        return new Response(
          JSON.stringify({ error: "phone, role, token, and platform are required" }),
          { status: 400, headers: { "Content-Type": "application/json" } },
        );
      }
      const { error } = await supabase.from("device_tokens").upsert(
        { phone, role, token, platform, language: language ?? "ar" },
        { onConflict: "phone,role,platform" },
      );
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    if (action === "delete") {
      if (!token) {
        return new Response(
          JSON.stringify({ error: "token is required" }),
          { status: 400, headers: { "Content-Type": "application/json" } },
        );
      }
      const { error } = await supabase.from("device_tokens").delete().eq("token", token);
      if (error) throw error;
      return new Response(JSON.stringify({ success: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ error: "action must be 'save' or 'delete'" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
