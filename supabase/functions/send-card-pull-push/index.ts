// Lyft-style push: send (or repeat) card-pull push to all group members.
// Call with POST body { groupId, pullerName? } for immediate send after a pull.
// Call with POST body {} and ?repeat=1 for cron: send to everyone with unread cardPulled in last 10 min.
// Requires PUSH_WEBHOOK_URL secret: your endpoint that receives { tokens, title, body } and sends to APNs.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PUSH_WEBHOOK_URL = Deno.env.get("PUSH_WEBHOOK_URL");

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

interface Body {
  groupId?: string;
  pullerName?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: cors() });
  }
  try {
    const url = new URL(req.url);
    const isRepeat = url.searchParams.get("repeat") === "1";
    const body = (await req.json().catch(() => ({}))) as Body;
    let userIds: string[] = [];

    if (isRepeat) {
      const { data: notifications } = await supabase
        .from("notifications")
        .select("recipient_user_id")
        .eq("notification_type", "cardPulled")
        .eq("is_read", false)
        .gte("created_at", new Date(Date.now() - 10 * 60 * 1000).toISOString());
      const seen = new Set<string>();
      for (const n of notifications ?? []) {
        seen.add(n.recipient_user_id);
      }
      userIds = [...seen];
    } else {
      const groupId = body.groupId;
      if (!groupId) {
        return new Response(JSON.stringify({ error: "Missing groupId" }), {
          status: 400,
          headers: { ...cors(), "Content-Type": "application/json" },
        });
      }
      const { data: members } = await supabase
        .from("memberships")
        .select("user_id")
        .eq("group_id", groupId);
      userIds = (members ?? []).map((m) => m.user_id);
    }

    if (userIds.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), {
        headers: { ...cors(), "Content-Type": "application/json" },
      });
    }

    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .in("user_id", userIds);
    const tokenList = [...new Set((tokens ?? []).map((t) => t.token))];

    if (tokenList.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), {
        headers: { ...cors(), "Content-Type": "application/json" },
      });
    }

    const pullerName = body.pullerName;
    const title = "BLACKOUT CARD PULLED";
    const messageBody = pullerName
      ? `${pullerName} pulled their Blackout Card!`
      : "Someone pulled their Blackout Card!";

    if (!PUSH_WEBHOOK_URL) {
      console.warn("PUSH_WEBHOOK_URL not set; skipping push.");
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { ...cors(), "Content-Type": "application/json" },
      });
    }

    const webhookRes = await fetch(PUSH_WEBHOOK_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tokens: tokenList, title, body: messageBody }),
    });

    if (!webhookRes.ok) {
      console.error("Webhook error:", await webhookRes.text());
      return new Response(JSON.stringify({ error: "Webhook failed" }), {
        status: 502,
        headers: { ...cors(), "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true, sent: tokenList.length }), {
      headers: { ...cors(), "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors(), "Content-Type": "application/json" },
    });
  }
});

function cors() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}
