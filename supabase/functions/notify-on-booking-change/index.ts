import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID")!;
const FCM_CLIENT_EMAIL = Deno.env.get("FCM_CLIENT_EMAIL")!;
const FCM_PRIVATE_KEY = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");

type Lang = "ar" | "en" | "ku";
type MsgMap = Record<Lang, { title: string; body: string }>;

const MESSAGES: Record<string, MsgMap> = {
  new_booking: {
    ar: { title: "حجز جديد", body: "لديك حجز جديد في محطتك" },
    en: { title: "New Booking", body: "You have a new booking at your station" },
    ku: { title: "حجزێکی نوێ", body: "حجزێکی نوێت هەیە لە ئیستگاکەتدا" },
  },
  confirmed: {
    ar: { title: "تم تأكيد حجزك", body: "تم تأكيد حجزك بنجاح" },
    en: { title: "Booking Confirmed", body: "Your booking has been confirmed" },
    ku: { title: "حجزەکەت دڵنیا کرایەوە", body: "حجزەکەت بە سەرکەوتوویی دڵنیا کرایەوە" },
  },
  rejected: {
    ar: { title: "تم رفض حجزك", body: "عذراً، تم رفض طلب حجزك" },
    en: { title: "Booking Rejected", body: "Sorry, your booking was rejected" },
    ku: { title: "حجزەکەت رەتکرایەوە", body: "ببورە، حجزەکەت رەتکرایەوە" },
  },
  cancelled: {
    ar: { title: "تم إلغاء حجزك", body: "تم إلغاء حجزك" },
    en: { title: "Booking Cancelled", body: "Your booking has been cancelled" },
    ku: { title: "حجزەکەت هەڵوەشێنرایەوە", body: "حجزەکەت هەڵوەشێنرایەوە" },
  },
  pending_customer_approval: {
    ar: { title: "طلب تأجيل", body: "طلب صاحب المحطة تغيير موعد حجزك" },
    en: { title: "Reschedule Request", body: "The station owner requested to reschedule your booking" },
    ku: { title: "داوای گۆڕینی کات", body: "خاوەنی ئیستگاکە داوای گۆڕینی کاتی حجزەکەت کرد" },
  },
  completed: {
    ar: { title: "اكتملت الخدمة", body: "شكراً! تمت خدمتك بنجاح" },
    en: { title: "Service Completed", body: "Thank you! Your car wash is complete" },
    ku: { title: "خزمەتگوزاری تەواو بوو", body: "سوپاس! جووڵەکەشتنی ئۆتۆمبێلەکەت تەواو بوو" },
  },
};

async function getFcmAccessToken(): Promise<string> {
  const pemBody = FCM_PRIVATE_KEY.replace(
    /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,
    "",
  );
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
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

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

async function sendToTokens(
  tokens: Array<{ token: string; language: string }>,
  messageKey: string,
  data: Record<string, string>,
) {
  if (tokens.length === 0) return;
  const accessToken = await getFcmAccessToken();
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;

  await Promise.all(
    tokens.map(async ({ token, language }) => {
      const lang = (["ar", "en", "ku"].includes(language) ? language : "ar") as Lang;
      const msg = MESSAGES[messageKey]?.[lang] ?? MESSAGES[messageKey]?.ar;
      if (!msg) return;
      await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: msg.title, body: msg.body },
            data,
          },
        }),
      });
    }),
  );
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { type, record, old_record } = await req.json();

    if (!type || !record) {
      return new Response(JSON.stringify({ ok: true, skipped: "missing type or record" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (type === "INSERT") {
      // New booking → notify station owner
      const { data: ownerRow } = await supabase
        .from("station_owners")
        .select("owner_phone")
        .eq("station_id", record.station_id)
        .single();

      if (!ownerRow?.owner_phone) {
        return new Response(JSON.stringify({ ok: true, skipped: "owner not found" }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("token, language")
        .eq("phone", ownerRow.owner_phone)
        .eq("role", "owner");

      await sendToTokens(tokens ?? [], "new_booking", {
        booking_id: record.id ?? "",
        station_id: record.station_id ?? "",
      });
    } else if (type === "UPDATE") {
      const newStatus: string = record.status;
      const oldStatus: string | undefined = old_record?.status;

      // Skip if status unchanged or not a tracked status
      if (newStatus === oldStatus || !MESSAGES[newStatus]) {
        return new Response(
          JSON.stringify({ ok: true, skipped: `status '${newStatus}' not tracked or unchanged` }),
          { headers: { "Content-Type": "application/json" } },
        );
      }

      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("token, language")
        .eq("phone", record.customer_phone)
        .eq("role", "customer");

      await sendToTokens(tokens ?? [], newStatus, {
        booking_id: record.id ?? "",
        status: newStatus,
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
