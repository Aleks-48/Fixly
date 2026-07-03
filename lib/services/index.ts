// supabase/functions/gemini-proxy/index.ts
//
// Прокси к Gemini API. Ключ GEMINI_API_KEY хранится только как секрет
// Supabase Edge Functions (никогда не попадает в Flutter-сборку).
//
// Деплой:
//   supabase functions deploy gemini-proxy
//   supabase secrets set GEMINI_API_KEY=AIzaSy...
//
// Вызов из Flutter (см. ai_service.dart):
//   supabase.functions.invoke('gemini-proxy', body: {
//     'prompt': '...',
//     'temperature': 0.7,
//     'maxOutputTokens': 2000,
//     'topP': 0.95,
//   });

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = "gemini-3-flash-preview";
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Используем глобальный Deno.serve вместо импорта из std/http/server.ts —
// внешний импорт у некоторых версий Supabase CLI/Edge Runtime не
// резолвится при деплое и роняет функцию с ошибкой загрузки модуля.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!GEMINI_API_KEY) {
    return new Response(
      JSON.stringify({ error: "GEMINI_API_KEY is not configured" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    const body = await req.json();
    const prompt: string | undefined = body?.prompt;

    if (!prompt || typeof prompt !== "string") {
      return new Response(
        JSON.stringify({ error: "Field 'prompt' (string) is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const temperature = typeof body?.temperature === "number" ? body.temperature : 0.7;
    const maxOutputTokens = typeof body?.maxOutputTokens === "number" ? body.maxOutputTokens : 1500;
    const topP = typeof body?.topP === "number" ? body.topP : 0.95;

    const geminiResponse = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature, maxOutputTokens, topP },
      }),
    });

    if (geminiResponse.status === 429) {
      return new Response(
        JSON.stringify({ error: "WAIT_LIMIT_REACHED" }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      return new Response(
        JSON.stringify({ error: `ERROR_${geminiResponse.status}`, details: errText }),
        { status: geminiResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const data = await geminiResponse.json();
    const text: string | undefined =
      data?.candidates?.[0]?.content?.parts?.[0]?.text;

    return new Response(
      JSON.stringify({ text: text ?? "" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "ERROR_NETWORK", details: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});