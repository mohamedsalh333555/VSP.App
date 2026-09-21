// Semantic Schema & Validation Contract for VSP Copilot
// Strongly-typed definitions for LLM Structured Output and deterministic parsing.

export interface TimeEntity {
  time: string; // "HH:mm" (e.g., "10:00", "22:00")
  period: "am" | "pm" | "unknown";
  period_certainty: "explicit" | "inferred" | "ambiguous";
  preference_order: number; // 1-based priority (e.g. 1 for 10:00, 2 for 11:00 in "10 أو 11")
}

export interface SemanticEntities {
  stadium?: {
    name?: string;
    reference_key?: string; // e.g. "stadium_1", "last_visible"
    is_explicit?: boolean;
  };
  date?: {
    type: "today" | "tomorrow" | "after_tomorrow" | "iso_date" | "unknown";
    value?: string; // ISO date string "YYYY-MM-DD" if resolved, or relative keyword
  };
  times?: TimeEntity[];
  time_range?: {
    from_hour?: number; // 0..23
    to_hour?: number;   // 0..23
    label?: string;     // e.g. "بعد العصر", "بالليل", "الصبح"
  };
  duration_hours?: number; // e.g., 2 for "لمدة ساعتين", defaults to 1
  group_size?: number;     // e.g., 11 for "أنا وصاحبي و10 نفر"
  location?: {
    governorate?: string;
    area?: string;
    near_user?: boolean;
  };
  money?: {
    max_price?: number;
    metric?: string;
  };
}

export interface SemanticReference {
  reference_type: "visible_entity" | "previous_state" | "ordinal" | "relative";
  target: "last_visible" | "first" | "second" | "third" | "fourth" | "last" | "same_stadium" | "same_time" | "next" | "previous" | string;
  raw_phrase: string; // e.g., "الملعب ده", "التاني", "نفس المعاد"
}

export interface SemanticChange {
  field: "stadium" | "date" | "time" | "duration" | "group_size" | "location" | "task" | "all";
  operation: "set" | "replace" | "clear" | "preserve";
  value?: any;
  reason?: string;
}

export interface SemanticAmbiguity {
  type: "time_period" | "entity_choice" | "date" | "financial_metric" | "financial_period" | "other";
  description: string;
  options?: string[];
}

export interface SemanticConfirmation {
  meaning: "none" | "requested" | "accepted" | "rejected" | "ambiguous";
  target?: "time_period" | "booking_proposal" | "cancellation" | "general" | null;
}

export interface SemanticExecutionRequest {
  requested: boolean;
  target?: "booking" | "search" | "availability" | "cancellation" | "navigation" | null;
}

export interface SemanticParseOutput {
  schema_version: number;
  speech_act: "request" | "question" | "inform" | "clarify" | "confirm" | "reject" | "correct" | "cancel" | "select" | "acknowledge" | "switch_task";
  intent: "booking" | "stadium_search" | "availability" | "tournament" | "challenge" | "profile" | "owner_operations" | "financial_question" | "navigation" | "general_question" | "unknown";
  operation: "create" | "search" | "inspect" | "modify" | "confirm" | "cancel" | "select" | "navigate" | "answer" | "none";
  entities: SemanticEntities;
  references: SemanticReference[];
  changes: SemanticChange[];
  ambiguities: SemanticAmbiguity[];
  confirmation: SemanticConfirmation;
  execution_request: SemanticExecutionRequest;
  raw_user_language?: string; // original user input
}

// JSON Schema for Gemini v1beta responseSchema (Structured Output)
export const GEMINI_SEMANTIC_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    schema_version: { type: "NUMBER" },
    speech_act: {
      type: "STRING",
      enum: [
        "request", "question", "inform", "clarify", "confirm", "reject",
        "correct", "cancel", "select", "acknowledge", "switch_task"
      ],
    },
    intent: {
      type: "STRING",
      enum: [
        "booking", "stadium_search", "availability", "tournament", "challenge",
        "profile", "owner_operations", "financial_question", "navigation", "general_question", "unknown"
      ],
    },
    operation: {
      type: "STRING",
      enum: [
        "create", "search", "inspect", "modify", "confirm", "cancel", "select", "navigate", "answer", "none"
      ],
    },
    entities: {
      type: "OBJECT",
      properties: {
        stadium: {
          type: "OBJECT",
          properties: {
            name: { type: "STRING" },
            reference_key: { type: "STRING" },
            is_explicit: { type: "BOOLEAN" },
          },
        },
        date: {
          type: "OBJECT",
          properties: {
            type: {
              type: "STRING",
              enum: ["today", "tomorrow", "after_tomorrow", "iso_date", "unknown"],
            },
            value: { type: "STRING" },
          },
        },
        times: {
          type: "ARRAY",
          items: {
            type: "OBJECT",
            properties: {
              time: { type: "STRING" },
              period: { type: "STRING", enum: ["am", "pm", "unknown"] },
              period_certainty: { type: "STRING", enum: ["explicit", "inferred", "ambiguous"] },
              preference_order: { type: "NUMBER" },
            },
            required: ["time", "period", "preference_order"],
          },
        },
        time_range: {
          type: "OBJECT",
          properties: {
            from_hour: { type: "NUMBER" },
            to_hour: { type: "NUMBER" },
            label: { type: "STRING" },
          },
        },
        duration_hours: { type: "NUMBER" },
        group_size: { type: "NUMBER" },
        location: {
          type: "OBJECT",
          properties: {
            governorate: { type: "STRING" },
            area: { type: "STRING" },
            near_user: { type: "BOOLEAN" },
          },
        },
        money: {
          type: "OBJECT",
          properties: {
            max_price: { type: "NUMBER" },
            metric: { type: "STRING" },
          },
        },
      },
    },
    references: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          reference_type: {
            type: "STRING",
            enum: ["visible_entity", "previous_state", "ordinal", "relative"],
          },
          target: { type: "STRING" },
          raw_phrase: { type: "STRING" },
        },
        required: ["reference_type", "target"],
      },
    },
    changes: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          field: {
            type: "STRING",
            enum: ["stadium", "date", "time", "duration", "group_size", "location", "task", "all"],
          },
          operation: {
            type: "STRING",
            enum: ["set", "replace", "clear", "preserve"],
          },
          value: { type: "STRING" },
          reason: { type: "STRING" },
        },
        required: ["field", "operation"],
      },
    },
    ambiguities: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          type: {
            type: "STRING",
            enum: ["time_period", "entity_choice", "date", "financial_metric", "financial_period", "other"],
          },
          description: { type: "STRING" },
          options: { type: "ARRAY", items: { type: "STRING" } },
        },
        required: ["type", "description"],
      },
    },
    confirmation: {
      type: "OBJECT",
      properties: {
        meaning: {
          type: "STRING",
          enum: ["none", "requested", "accepted", "rejected", "ambiguous"],
        },
        target: { type: "STRING" },
      },
      required: ["meaning"],
    },
    execution_request: {
      type: "OBJECT",
      properties: {
        requested: { type: "BOOLEAN" },
        target: { type: "STRING" },
      },
      required: ["requested"],
    },
  },
  required: [
    "schema_version",
    "speech_act",
    "intent",
    "operation",
    "entities",
    "references",
    "changes",
    "ambiguities",
    "confirmation",
    "execution_request",
  ],
};

// Runtime Normalizer & Type Guard
export function validateAndNormalizeSemanticOutput(raw: any, rawInputText: string): SemanticParseOutput {
  if (!raw || typeof raw !== "object") {
    return createSafeFallbackOutput(rawInputText);
  }

  const speechActList = [
    "request", "question", "inform", "clarify", "confirm", "reject",
    "correct", "cancel", "select", "acknowledge", "switch_task"
  ];
  const intentList = [
    "booking", "stadium_search", "availability", "tournament", "challenge",
    "profile", "owner_operations", "financial_question", "navigation", "general_question", "unknown"
  ];
  const opList = [
    "create", "search", "inspect", "modify", "confirm", "cancel", "select", "navigate", "answer", "none"
  ];

  const speech_act = speechActList.includes(raw.speech_act) ? raw.speech_act : "inform";
  const intent = intentList.includes(raw.intent) ? raw.intent : "unknown";
  const operation = opList.includes(raw.operation) ? raw.operation : "none";

  const entities: SemanticEntities = {};
  if (raw.entities && typeof raw.entities === "object") {
    const re = raw.entities;
    if (re.stadium && typeof re.stadium === "object") {
      entities.stadium = {
        name: typeof re.stadium.name === "string" ? re.stadium.name.trim() : undefined,
        reference_key: typeof re.stadium.reference_key === "string" ? re.stadium.reference_key.trim() : undefined,
        is_explicit: Boolean(re.stadium.is_explicit),
      };
    }
    if (re.date && typeof re.date === "object") {
      const allowedDateTypes = ["today", "tomorrow", "after_tomorrow", "iso_date", "unknown"];
      entities.date = {
        type: allowedDateTypes.includes(re.date.type) ? re.date.type : "unknown",
        value: typeof re.date.value === "string" ? re.date.value.trim() : undefined,
      };
    }
    if (Array.isArray(re.times)) {
      entities.times = re.times
        .filter((t: any) => t && typeof t === "object" && typeof t.time === "string")
        .map((t: any, idx: number) => ({
          time: t.time.trim(),
          period: ["am", "pm", "unknown"].includes(t.period) ? t.period : "unknown",
          period_certainty: ["explicit", "inferred", "ambiguous"].includes(t.period_certainty) ? t.period_certainty : "ambiguous",
          preference_order: typeof t.preference_order === "number" ? t.preference_order : (idx + 1),
        }));
    }
    if (re.time_range && typeof re.time_range === "object") {
      entities.time_range = {
        from_hour: typeof re.time_range.from_hour === "number" ? re.time_range.from_hour : undefined,
        to_hour: typeof re.time_range.to_hour === "number" ? re.time_range.to_hour : undefined,
        label: typeof re.time_range.label === "string" ? re.time_range.label : undefined,
      };
    }
    if (typeof re.duration_hours === "number" && re.duration_hours > 0) {
      entities.duration_hours = re.duration_hours;
    }
    if (typeof re.group_size === "number" && re.group_size > 0 && re.group_size <= 50) {
      entities.group_size = Math.round(re.group_size);
    }
    if (re.location && typeof re.location === "object") {
      entities.location = {
        governorate: typeof re.location.governorate === "string" ? re.location.governorate.trim() : undefined,
        area: typeof re.location.area === "string" ? re.location.area.trim() : undefined,
        near_user: Boolean(re.location.near_user),
      };
    }
    if (re.money && typeof re.money === "object") {
      entities.money = {
        max_price: typeof re.money.max_price === "number" ? re.money.max_price : undefined,
        metric: typeof re.money.metric === "string" ? re.money.metric : undefined,
      };
    }
  }

  const references: SemanticReference[] = Array.isArray(raw.references)
    ? raw.references
        .filter((r: any) => r && typeof r === "object" && typeof r.target === "string")
        .map((r: any) => ({
          reference_type: ["visible_entity", "previous_state", "ordinal", "relative"].includes(r.reference_type)
            ? r.reference_type
            : "visible_entity",
          target: r.target,
          raw_phrase: typeof r.raw_phrase === "string" ? r.raw_phrase : "",
        }))
    : [];

  const changes: SemanticChange[] = Array.isArray(raw.changes)
    ? raw.changes
        .filter((c: any) => c && typeof c === "object" && typeof c.field === "string")
        .map((c: any) => ({
          field: ["stadium", "date", "time", "duration", "group_size", "location", "task", "all"].includes(c.field)
            ? c.field
            : "task",
          operation: ["set", "replace", "clear", "preserve"].includes(c.operation)
            ? c.operation
            : "set",
          value: c.value,
          reason: typeof c.reason === "string" ? c.reason : undefined,
        }))
    : [];

  const ambiguities: SemanticAmbiguity[] = Array.isArray(raw.ambiguities)
    ? raw.ambiguities
        .filter((a: any) => a && typeof a === "object" && typeof a.type === "string")
        .map((a: any) => ({
          type: ["time_period", "entity_choice", "date", "financial_metric", "financial_period", "other"].includes(a.type)
            ? a.type
            : "other",
          description: typeof a.description === "string" ? a.description : "",
          options: Array.isArray(a.options) ? a.options.map(String) : undefined,
        }))
    : [];

  const conf = raw.confirmation && typeof raw.confirmation === "object" ? raw.confirmation : {};
  const confirmation: SemanticConfirmation = {
    meaning: ["none", "requested", "accepted", "rejected", "ambiguous"].includes(conf.meaning)
      ? conf.meaning
      : "none",
    target: conf.target || null,
  };

  const exec = raw.execution_request && typeof raw.execution_request === "object" ? raw.execution_request : {};
  const execution_request: SemanticExecutionRequest = {
    requested: Boolean(exec.requested),
    target: exec.target || null,
  };

  return {
    schema_version: 1,
    speech_act,
    intent,
    operation,
    entities,
    references,
    changes,
    ambiguities,
    confirmation,
    execution_request,
    raw_user_language: rawInputText,
  };
}

export function createSafeFallbackOutput(rawInputText: string): SemanticParseOutput {
  return {
    schema_version: 1,
    speech_act: "inform",
    intent: "unknown",
    operation: "none",
    entities: {},
    references: [],
    changes: [],
    ambiguities: [],
    confirmation: { meaning: "none" },
    execution_request: { requested: false },
    raw_user_language: rawInputText,
  };
}
