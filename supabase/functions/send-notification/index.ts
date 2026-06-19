import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID")!;
const FCM_CLIENT_EMAIL = Deno.env.get("FCM_CLIENT_EMAIL")!;
// Firebase stores newlines as \n in the JSON — restore them
const FCM_PRIVATE_KEY = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");

// Exchange service-account credentials for a short-lived FCM access token
async function getFcmAccessToken(): Promise<string> {
  const pemBody = FCM_PRIVATE_KEY.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const binaryDer = atob(pemBody);
  const buffer = new Uint8Array(binaryDer.length);
  for (let i = 0; i < binaryDer.length; i++) buffer[i] = binaryDer.charCodeAt(i);

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    buffer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const now = Math.floor(Date.now() / 1000);
  const b64url = (o: object) =>
    btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const header = b64url({ alg: "RS256", typ: "JWT" });
  const payload = b64url({
    iss: FCM_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  });

  const signingInput = `${header}.${payload}`;
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(signingInput),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const jwt = `${signingInput}.${sigB64}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const json = await res.json();
  if (!json.access_token) throw new Error(`OAuth2 failed: ${JSON.stringify(json)}`);
  return json.access_token;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { phone, role, title, body, data } = await req.json();

    if (!phone || !role || !title || !body) {
      return new Response(
        JSON.stringify({ error: "phone, role, title, and body are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Look up device tokens for this user
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: rows, error: dbError } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("phone", phone)
      .eq("role", role);

    if (dbError) throw dbError;
    if (!rows || rows.length === 0) {
      return new Response(
        JSON.stringify({ message: "No device tokens found", sent: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getFcmAccessToken();
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;

    const results = await Promise.all(
      rows.map(async (row: { token: string }) => {
        const res = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: row.token,
              notification: { title, body },
              data: data ?? {},
            },
          }),
        });
        return res.json();
      }),
    );

    return new Response(
      JSON.stringify({ sent: results.length, results }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
