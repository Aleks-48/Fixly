import "@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type RequestBody = {
  task?: string;
  title?: string;
  description?: string;
  lang?: string;
  savingAccount?: number;
  capitalRepairAccount?: number;
  recentExpenses?: Array<Record<string, unknown>>;
  marketContext?: string;
  workTask?: string;
  price?: number;
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as RequestBody;
    const prompt = buildPrompt(body);
    const apiKey = Deno.env.get("GEMINI_API_KEY");

    if (!apiKey) {
      return json({ text: fallbackText(body) });
    }

    const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-1.5-flash";
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: body.task === "price_fairness" ? 0.3 : 0.7,
            maxOutputTokens: body.task === "chairman_financial_analysis"
              ? 1600
              : 1200,
          },
        }),
      },
    );

    if (!response.ok) {
      const errorText = await response.text();
      return json({ error: errorText }, response.status);
    }

    const data = await response.json();
    const text =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ?? fallbackText(body);
    return json({ text });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 400);
  }
});

function buildPrompt(body: RequestBody): string {
  const lang = body.lang || "ru";

  if (body.task === "chairman_financial_analysis") {
    const expenses = body.recentExpenses?.length
      ? body.recentExpenses
        .map((item) => `- ${item.title ?? "Расход"}: ${item.amount ?? 0} тг`)
        .join("\n")
      : "Расходов за период нет.";

    return `
Ты финансовый помощник председателя ОСИ/НСУ в Казахстане.
Язык ответа: ${lang}.

Данные дома:
- текущий счет: ${body.savingAccount ?? 0} тг
- фонд капитального ремонта: ${body.capitalRepairAccount ?? 0} тг
- последние расходы:
${expenses}
- рыночный контекст: ${body.marketContext ?? "нет данных"}

Дай краткий, практичный анализ: состояние бюджета, риски, что можно оплатить сейчас, на что нужно копить, один совет на неделю.
Не выдавай юридическое заключение.
`;
  }

  if (body.task === "price_fairness") {
    return `
Проверь ориентировочную справедливость цены для рынка Казахстана.
Язык ответа: ${lang}.
Работа: ${body.workTask ?? ""}
Цена: ${body.price ?? 0} тг.

Ответь кратко: диапазон, вердикт, причина.
`;
  }

  return `
Ты технический эксперт для сервиса заявок дома.
Язык ответа: ${lang}.
Заявка: ${body.title ?? ""}
Описание: ${body.description ?? ""}

Составь понятный пошаговый план работ для мастера: диагностика, инструменты, порядок действий, риски, критерии готовности.
`;
}

function fallbackText(body: RequestBody): string {
  if (body.task === "chairman_financial_analysis") {
    return "AI-сервис пока не настроен. Проверьте баланс дома, выделите срочные расходы и сравните крупные работы с несколькими сметами.";
  }
  if (body.task === "price_fairness") {
    return "AI-сервис пока не настроен. Сравните цену минимум с двумя исполнителями и зафиксируйте состав работ в заявке.";
  }
  return "AI-сервис пока не настроен. Начните с диагностики, зафиксируйте проблему фото, согласуйте объем работ и закрывайте заявку только после проверки результата.";
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
