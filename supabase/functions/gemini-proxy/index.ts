import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const geminiBaseUrl =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent";
const maxPromptLength = 12_000;
const maxOutputTokenLimit = 2_000;
const maxRequestsPerMinute = 10;

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const { prompt, temperature, maxOutputTokens, topP } = await req.json();

    if (!prompt || typeof prompt !== "string" || prompt.length > maxPromptLength) {
      return json({ error: "Invalid prompt" }, 400);
    }
    if (temperature !== undefined &&
        (!isFiniteNumber(temperature) || temperature < 0 || temperature > 1)) {
      return json({ error: "temperature must be between 0 and 1" }, 400);
    }
    if (topP !== undefined &&
        (!isFiniteNumber(topP) || topP <= 0 || topP > 1)) {
      return json({ error: "topP must be between 0 (exclusive) and 1" }, 400);
    }
    if (maxOutputTokens !== undefined &&
        (!Number.isInteger(maxOutputTokens) || maxOutputTokens < 1 ||
            maxOutputTokens > maxOutputTokenLimit)) {
      return json({ error: "maxOutputTokens is out of range" }, 400);
    }

    const authorization = req.headers.get("Authorization");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!authorization?.startsWith("Bearer ") || !supabaseUrl || !serviceRoleKey) {
      return json({ error: "Unauthorized" }, 401);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const token = authorization.substring("Bearer ".length);
    const { data: userData, error: userError } = await admin.auth.getUser(token);
    if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);

    const { data: allowed, error: quotaError } = await admin.rpc("consume_ai_quota", {
      p_user_id: userData.user.id,
      p_limit: maxRequestsPerMinute,
    });
    if (quotaError) throw quotaError;
    if (allowed !== true) return json({ error: "RATE_LIMIT" }, 429);

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return json({ error: "GEMINI_API_KEY is not configured" }, 500);

    const geminiResponse = await fetch(`${geminiBaseUrl}?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: temperature ?? 0.7,
          maxOutputTokens: maxOutputTokens ?? maxOutputTokenLimit,
          ...(topP !== undefined ? { topP } : {}),
        },
      }),
    });

    if (geminiResponse.status === 429) {
      return json({ error: "RATE_LIMIT" }, 429);
    }
    if (!geminiResponse.ok) {
      return json({ error: `Gemini API error ${geminiResponse.status}` }, 502);
    }

    const data = await geminiResponse.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    return json({ text });
  } catch (error) {
    console.error("gemini-proxy error", error);
    return json({ error: "AI service unavailable" }, 500);
  }
});
