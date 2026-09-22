// Gemini Semantic Parser with Strict Structured Output
// Translates colloquial Egyptian user messages into typed SemanticParseOutput.

import type { SemanticParseOutput } from "./semantic_schema.ts";
import {
  GEMINI_SEMANTIC_RESPONSE_SCHEMA,
  validateAndNormalizeSemanticOutput,
  createSafeFallbackOutput,
} from "./semantic_schema.ts";
import type { ConversationState } from "./conversation_state.ts";
import { getCairoDateParts } from "./business_rules.ts";

export interface SemanticAttemptTelemetry {
  model: string;
  status: number;
  latency_ms: number;
  error?: "RATE_LIMIT" | "TRANSIENT_SERVER_ERROR" | "CLIENT_ERROR" | "TIMEOUT" | "SCHEMA_ERROR" | "UNKNOWN";
}

export interface SemanticTelemetry {
  primary_model: string;
  model_used: string | null;
  attempts: SemanticAttemptTelemetry[];
  degraded: boolean;
  fallback_reason: "RATE_LIMIT" | "TRANSIENT_SERVER_ERROR" | "TIMEOUT" | "CLIENT_ERROR" | "ALL_MODELS_EXHAUSTED" | null;
}

export interface SemanticParseResult {
  output: SemanticParseOutput;
  isDegraded: boolean;
  telemetry: SemanticTelemetry;
}

export const SEMANTIC_MODEL_CHAIN = [
  "gemini-3.5-flash-lite",
  "gemini-3.1-flash-lite",
];

export async function parseUserMessageSemantically(
  userMessage: string,
  state: ConversationState,
  recentHistory: Array<{ role: string; content: string }>,
  geminiApiKey: string | undefined
): Promise<SemanticParseResult> {
  const telemetry: SemanticTelemetry = {
    primary_model: SEMANTIC_MODEL_CHAIN[0],
    model_used: null,
    attempts: [],
    degraded: false,
    fallback_reason: null,
  };

  if (!geminiApiKey) {
    console.warn("[SemanticParser] GEMINI_API_KEY missing, using degraded fallback");
    telemetry.degraded = true;
    telemetry.fallback_reason = "CLIENT_ERROR";
    return {
      output: createSafeFallbackOutput(userMessage),
      isDegraded: true,
      telemetry,
    };
  }

  const cairo = getCairoDateParts();
  const cairoTodayStr = `${cairo.year}-${String(cairo.month).padStart(2, "0")}-${String(cairo.day).padStart(2, "0")}`;

  const visibleContext = state.last_visible_entities.map(e => ({
    reference_key: e.reference_key,
    type: e.entity_type,
    name: e.name,
    price_per_hour: e.price_per_hour,
  }));

  const systemInstruction = `You are the Pitch Owner Copilot & Business Advisory Engine of VSP Sports Platform in Egypt.
Your task is to interpret inquiries from Pitch Owners (أصحاب ومسؤولو الملاعب) in Egyptian Arabic into strict structured JSON.

CORE FOCUS AREAS FOR PITCH OWNERS:
1. Financial Inquiries (الأرباح، الرصيد، الكشف المالي):
   - "كسبت كام النهاردة/الشهر ده", "أرباحي كام", "الرصيد القابل للسحب", "في فلوس معلقة؟", "حساباتي":
     => domain: "financials", object: "financials", action: "inspect", scope: "owner_owned", intent: "financial_question", operation: "inspect"

2. Stadium Bookings & Schedule (جدول الحجوزات والمواعيد):
   - "مين حاجز النهاردة", "جدول الحجوزات بكرة", "الحجوزات القادمة في ملعبي", "في ماتشات محجوزة الليلة؟":
     => domain: "owner_operations", object: "booking", action: "inspect", scope: "owner_owned", intent: "booking", operation: "inspect"

3. Slot Availability & Dead Hours (الساعات المتاحة والفارغة):
   - "الملعب فاضي امتى النهاردة", "إيه الساعات الميتة", "في أوقات فاضية الجمعة الجاية؟":
     => domain: "booking", object: "stadium", action: "inspect", sub_action: "availability", scope: "owner_owned", intent: "booking", operation: "inspect"

4. Bot Identity / Greetings:
   - "مين انت", "بتساعدني في ايه":
     => speech_act: "question", domain: "general", object: "bot_identity", action: "answer", sub_action: "identity", intent: "general_question", operation: "answer"

Context:
- Egypt Local Date Today: ${cairoTodayStr}
- User Role: ${state.user_role}
- Current State: ${JSON.stringify({ active_task: state.active_task })}`;

  const promptContents: any[] = [];
  // Include last 3 turns of context
  for (const msg of recentHistory.slice(-3)) {
    promptContents.push({
      role: msg.role === "user" ? "user" : "model",
      parts: [{ text: msg.content }],
    });
  }
  promptContents.push({
    role: "user",
    parts: [{ text: userMessage }],
  });

  const payload = {
    systemInstruction: { parts: [{ text: systemInstruction }] },
    contents: promptContents,
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: GEMINI_SEMANTIC_RESPONSE_SCHEMA,
      temperature: 0.1,
    },
  };

  // Classified Model Failover Loop
  for (let i = 0; i < SEMANTIC_MODEL_CHAIN.length; i++) {
    const model = SEMANTIC_MODEL_CHAIN[i];
    const startTime = Date.now();
    const abortController = new AbortController();
    const timeoutHandle = setTimeout(() => abortController.abort(), 4000);

    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        signal: abortController.signal,
      });
      clearTimeout(timeoutHandle);
      const latency = Date.now() - startTime;

      if (res.ok) {
        const data = await res.json();
        const rawJsonText = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (rawJsonText) {
          try {
            const parsed = JSON.parse(rawJsonText);
            const normalized = validateAndNormalizeSemanticOutput(parsed, userMessage);
            telemetry.attempts.push({ model, status: 200, latency_ms: latency });
            telemetry.model_used = model;
            if (model !== telemetry.primary_model && !telemetry.fallback_reason) {
              telemetry.fallback_reason = "RATE_LIMIT";
            }
            return {
              output: normalized,
              isDegraded: false,
              telemetry,
            };
          } catch (jsonErr) {
            console.warn(`[SemanticParser] JSON/Schema parse error on ${model}:`, jsonErr);
            telemetry.attempts.push({ model, status: 200, latency_ms: latency, error: "SCHEMA_ERROR" });
            continue;
          }
        }
      }

      // Handle classified HTTP statuses
      if (res.status === 429) {
        console.warn(`[SemanticParser] 429 RateLimit/Quota on model ${model}, attempting next model...`);
        telemetry.attempts.push({ model, status: 429, latency_ms: latency, error: "RATE_LIMIT" });
        if (!telemetry.fallback_reason) {
          telemetry.fallback_reason = "RATE_LIMIT";
        }
        continue;
      }

      if (res.status === 404) {
        console.warn(`[SemanticParser] 404 Model Not Found for ${model}, attempting next model...`);
        telemetry.attempts.push({ model, status: 404, latency_ms: latency, error: "CLIENT_ERROR" });
        if (!telemetry.fallback_reason) {
          telemetry.fallback_reason = "RATE_LIMIT";
        }
        continue;
      }

      if (res.status >= 500) {
        console.warn(`[SemanticParser] Server error ${res.status} on model ${model}, backoff and next...`);
        telemetry.attempts.push({ model, status: res.status, latency_ms: latency, error: "TRANSIENT_SERVER_ERROR" });
        if (!telemetry.fallback_reason) {
          telemetry.fallback_reason = "TRANSIENT_SERVER_ERROR";
        }
        await new Promise(r => setTimeout(r, 200));
        continue;
      }

      if (res.status >= 400 && res.status < 500) {
        // Unrecoverable auth/permission client error (400, 401, 403) - Stop searching!
        const errText = await res.text();
        console.error(`[SemanticParser] Unrecoverable client error ${res.status} on ${model}:`, errText);
        telemetry.attempts.push({ model, status: res.status, latency_ms: latency, error: "CLIENT_ERROR" });
        telemetry.fallback_reason = "CLIENT_ERROR";
        break;
      }
    } catch (netErr: any) {
      clearTimeout(timeoutHandle);
      const latency = Date.now() - startTime;
      if (netErr?.name === "AbortError") {
        console.warn(`[SemanticParser] Timeout (4s) on model ${model}, trying next...`);
        telemetry.attempts.push({ model, status: 408, latency_ms: latency, error: "TIMEOUT" });
        if (!telemetry.fallback_reason) {
          telemetry.fallback_reason = "TIMEOUT";
        }
      } else {
        console.warn(`[SemanticParser] Network transient error on model ${model}:`, netErr);
        telemetry.attempts.push({ model, status: 0, latency_ms: latency, error: "TRANSIENT_SERVER_ERROR" });
        if (!telemetry.fallback_reason) {
          telemetry.fallback_reason = "TRANSIENT_SERVER_ERROR";
        }
      }
      continue;
    }
  }

  // All models exhausted -> Safe Degraded Mode (Zero Regex, Zero Semantic Guessing)
  telemetry.degraded = true;
  if (!telemetry.fallback_reason) {
    telemetry.fallback_reason = "ALL_MODELS_EXHAUSTED";
  }
  console.warn("[SemanticParser] All models failed. Entering Safe Degraded Mode.");

  return {
    output: createSafeFallbackOutput(userMessage),
    isDegraded: true,
    telemetry,
  };
}
