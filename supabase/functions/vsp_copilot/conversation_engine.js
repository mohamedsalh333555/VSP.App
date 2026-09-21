// VSP Copilot Conversation Engine
// Deterministic turn analysis/state/decision layer. Gemini is downstream for wording.

const NUMBER_WORDS = {
  "واحد":1,"واحدة":1,"واحده":1,"اتنين":2,"اثنين":2,"اثنان":2,"تنين":2,
  "تلاتة":3,"ثلاثة":3,"تلاته":3,"ثلاثه":3,
  "اربعة":4,"أربعة":4,"اربعه":4,"أربعه":4,
  "خمسة":5,"خمسه":5,"ستة":6,"سته":6,"سبعة":7,"سبعه":7,
  "تمانية":8,"ثمانية":8,"تمانيه":8,"ثمانيه":8,
  "تسعة":9,"تسعه":9,"عشرة":10,"عشره":10,"عشر":10,"حداشر":11,"احداشر":11,
  "اتناشر":12,"اثناشر":12,"اتنا عشر":12,"تلتاشر":13,"ثلتاشر":13,"تلاتاشر":13,
  "اربعتاشر":14,"خمستاشر":15,"ستاشر":16,"سبعتاشر":17,
  "تمانتاشر":18,"تمنتاشر":18,"تممنتاشر":18,"تسعتاشر":19,
  "عشرين":20,"واحد وعشرين":21,"اتنين وعشرين":22,"تلاتة وعشرين":23,
  "اربعة وعشرين":24,"خمسة وعشرين":25,"ستة وعشرين":26,"سبعة وعشرين":27,
  "تمانية وعشرين":28,"تسعة وعشرين":29,"تلاتين":30,"ثلاثين":30,
};

const PARTICIPANT_WORD = "(?:نفر|نفار|تنفار|شخص|اشخاص|أشخاص|افراد|أفراد|لاعب|لاعبين|لاعيبة|فرد|افرادنا|لاعبه|لاعبة|لاعبات)";
const BOOKING_WORD = /(?:حجز|احجز|احجزلي|احجزلى|حجزلي|حجزلِي|ملعب|ملاعب)/i;
const HOWTO_WORD = /(?:ازاي|إزاي|ازاى|كيف|كيفية|طريقة|ازاي اقدر|إزاي أقدر|ازاى اقدر)/i;
const STRONG_BOOKING = /(?:احجزلي|احجز ليا|احجز لي|اعمللي حجز|اعمل ليا حجز|ثبتلي الحجز|ثبت الحجز|نفذ الحجز|احجزهولي|احجزه|عايزك تحجز|عايز احجز|عايزة احجز|عاوز احجز|عاوزة احجز|ممكن تحجزلي|ممكن تحجزهولي)/i;

function normalizeDigits(value = "") {
  const arabic = "٠١٢٣٤٥٦٧٨٩";
  return String(value).replace(/[٠-٩]/g, d => String(arabic.indexOf(d)));
}

function normalizeEgyptianText(value = "") {
  return normalizeDigits(String(value)
    .toLowerCase()
    .replace(/[إأآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ؤ/g, "و")
    .replace(/ئ/g, "ي")
    .replace(/(^|\s)عايزه(?=\s|$)/g, "$1عايزة")
    .replace(/(^|\s)عاوزه(?=\s|$)/g, "$1عاوزة")
    .replace(/(^|\s)محتاجه(?=\s|$)/g, "$1محتاجة")
    .replace(/احجزلى|حجزلى/g, "احجزلي")
    .replace(/احجز لى/g, "احجزلي")
    .replace(/(^|\s)(?:نهارده|النهاردة)(?=\s|$)/g, "$1النهارده")
    .replace(/تنفار|نفار/g, "نفر")
    .replace(/لاعيبة/g, "لاعبين")
    .replace(/الساعة|الساعه/g, "الساعة")
  ).replace(/\s+/g, " ").trim();
}

function escapeRx(s) {
  return s.replace(/[.*+?^$()|[\]\\]/g, "\\$&");
}

const NUMBER_WORD_ALT = Object.keys(NUMBER_WORDS)
  .sort((a,b) => b.length - a.length)
  .map(escapeRx)
  .join("|");

function parseNumberToken(token) {
  if (!token) return null;
  const s = normalizeEgyptianText(token).replace(/[،,]/g, " ").replace(/\s+/g, " ").trim();
  if (/^\d{1,2}$/.test(s)) return Number(s);
  if (NUMBER_WORDS[s] != null) return NUMBER_WORDS[s];

  const compound = /^(\d{1,2})\s+و\s+(.+)$/.exec(s);
  if (compound) {
    const a = Number(compound[1]);
    const b = NUMBER_WORDS[compound[2]];
    if (Number.isFinite(a) && b != null) return a + b;
  }

  const wordCompound = /^(واحد|اتنين|تلاتة|اربعة|خمسة|ستة|سبعة|تمانية|تسعة)\s+و\s+(عشرين|ثلاثين)$/.exec(s);
  if (wordCompound) return NUMBER_WORDS[wordCompound[1]] + NUMBER_WORDS[wordCompound[2]];
  return null;
}

function findCorrectionTail(input) {
  const normalized = normalizeEgyptianText(input);
  const matches = [...normalized.matchAll(/(?:^|\s)(?:قصدي|لأ|لا|اقصد|بدل|بدّل|غيرت رأيي|مش قصدي)(?=\s|$)/g)];
  if (!matches.length) return { text: normalized, corrected: false };
  return { text: normalized.slice(matches[matches.length - 1].index), corrected: true };
}

function participantContext(input, index, length) {
  const before = input.slice(Math.max(0, index - 12), index);
  const after = input.slice(index + length, Math.min(input.length, index + length + 24));
  return new RegExp(PARTICIPANT_WORD, "i").test(after) ||
    /(?:انا|احنا)\s*(?:و|معايا|معاي|معنا)\s*$/i.test(before);
}

function extractGroupSize(input) {
  const normalized = normalizeEgyptianText(input);

  const self = new RegExp(
    "(?:انا|احنا)\\s*(?:و|معايا|معاي|معنا)\\s*(" + NUMBER_WORD_ALT + "|\\d{1,2})\\s*" + PARTICIPANT_WORD,
    "i"
  ).exec(normalized);
  if (self) {
    const n = parseNumberToken(self[1]);
    if (n != null && n >= 1 && n <= 30) return Math.min(30, n + 1);
  }

  const direct = new RegExp("(" + NUMBER_WORD_ALT + "|\\d{1,2})\\s*" + PARTICIPANT_WORD, "gi");
  let m;
  while ((m = direct.exec(normalized)) !== null) {
    const n = parseNumberToken(m[1]);
    if (n != null && n >= 1 && n <= 30) return n;
  }

  const collective = new RegExp(
    "(?:احنا|إحنا)\\s*(?:حوالي\\s*)?(" + NUMBER_WORD_ALT + "|\\d{1,2})(?=\\s|$)",
    "i"
  ).exec(normalized);
  if (collective) {
    const n = parseNumberToken(collective[1]);
    if (n != null && n >= 1 && n <= 30) return n;
  }

  return null;
}

function hasTimeCue(text) {
  return /الساعة|ساعة|ساعه|وقت|ميعاد|موعد|بالليل|ليل|مساء|المساء|الصبح|صباح|صباحا|مسا|^\s*\d{1,2}:\d{2}/i.test(text);
}

function hourWordPattern() {
  return ["واحد","اتنين","تنين","تلاتة","ثلاثة","اربعة","أربعة","خمسة","ستة","سبعة","تمانية","ثمانية","تسعة","عشرة","عشره","عشر"]
    .sort((a,b) => b.length-a.length)
    .map(escapeRx)
    .join("|");
}

function parseTimeValue(hour, minute = 0, period = "") {
  let h = Number(hour), m = Number(minute) || 0;
  if (!Number.isFinite(h) || h < 0 || h > 23 || m < 0 || m > 59) return null;
  if (/مساء|مسا|بالليل|ليل|(?:^|\\s)م(?:\\s|$)/i.test(period) && h < 12) h += 12;
  if (/صباح|صبح|(?:^|\\s)ص(?:\\s|$)/i.test(period) && h === 12) h = 0;
  return String(h).padStart(2,"0") + ":" + String(m).padStart(2,"0");
}

function extractPreferredTimes(input) {
  const normalized = normalizeEgyptianText(input);
  const effective = findCorrectionTail(normalized).text;
  if (!hasTimeCue(effective)) return [];

  const results = [];
  const push = t => { if (t && !results.includes(t)) results.push(t); };
  const globalPm = /مساء|مسا|بالليل|ليل|(?:^|\\s)م(?=\\s|$)/i.test(effective);
  const globalAm = /صباح|صبح|(?:^|\\s)ص(?=\\s|$)/i.test(effective);

  const numericRe = /\b(\d{1,2})(?:\s*[:٫.]\s*(\d{1,2}))?\b/g;
  let m;
  while ((m = numericRe.exec(effective)) !== null) {
    if (participantContext(effective, m.index, m[0].length)) continue;
    const before = effective.slice(Math.max(0, m.index - 16), m.index);
    const after = effective.slice(m.index, Math.min(effective.length, m.index + 22));
    const directTime =
      /الساعة\s*$/i.test(before) ||
      /(?:بالليل|ليل|مساء|المساء|الصبح|صباح|مسا)|(?:^|\\s)[مص](?=\\s|$)/i.test(after) ||
      /[:٫.]\d{1,2}/.test(m[0]);
    if (!directTime) continue;
    const t = parseTimeValue(m[1], m[2] || 0, globalPm ? "مساء" : globalAm ? "صباح" : after);
    if (t) push(t);
  }

  if (globalPm || globalAm) {
    const chain = [...effective.matchAll(
      /\b(\d{1,2})\b\s*(?:او|أو|ولا|و|,|،)\s*\b(\d{1,2})\b(?:\s*(?:بالليل|ليل|مساء|المساء|الصبح|صباح|مسا))/gi
    )];
    for (const c of chain) {
      if (participantContext(effective, c.index, c[0].length)) continue;
      push(parseTimeValue(c[1],0,globalPm ? "مساء" : "صباح"));
      push(parseTimeValue(c[2],0,globalPm ? "مساء" : "صباح"));
    }
  }

  const wordRe = new RegExp(
    "(?:الساعة|ساعة|ساعه)\\s*(" + hourWordPattern() + ")(?=\\s|$)(?:\\s*(?:بالليل|ليل|مساء|المساء|الصبح|صباح))?",
    "gi"
  );
  while ((m = wordRe.exec(effective)) !== null) {
    const hour = parseNumberToken(m[1]);
    const t = parseTimeValue(hour, 0, m[0]);
    if (t) push(t);
  }

  return results.slice(0,4);
}

function extractTimeWindow(input) {
  const t = normalizeEgyptianText(input);
  if (/بعد\s+العصر|بعد\s+الضهر|بعد\s+الظهر|من\s+بعد\s+العصر/i.test(t))
    return {type:"after_afternoon",label:"بعد العصر",from_hour:16,to_hour:23};
  if (/بالليل|ليل|مساء|المساء/i.test(t) && extractPreferredTimes(t).length === 0)
    return {type:"evening",label:"بالليل",from_hour:20,to_hour:23};
  if (/الصبح|صباح|الصباح/i.test(t) && extractPreferredTimes(t).length === 0)
    return {type:"morning",label:"الصبح",from_hour:6,to_hour:12};
  return null;
}

function extractDateToken(input) {
  const t = normalizeEgyptianText(input);
  if (/بعد\s*بكره|بعد\s*بكرة|بعد\s*غد/i.test(t)) return "after_tomorrow";
  if (/بكره|بكرة|غدا|غداً|tomorrow/i.test(t)) return "tomorrow";
  if (/النهارده|اليوم|today/i.test(t)) return "today";
  const iso = /\b(20\d{2}-\d{2}-\d{2})\b/.exec(t);
  return iso ? iso[1] : null;
}

function resolveRelativeDate(token, now = new Date()) {
  const cairo = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Cairo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const get = type => Number(cairo.find(p => p.type === type)?.value || 0);
  const base = new Date(Date.UTC(get("year"), get("month") - 1, get("day"), 12, 0, 0));
  if (token === "tomorrow") base.setUTCDate(base.getUTCDate()+1);
  if (token === "after_tomorrow") base.setUTCDate(base.getUTCDate()+2);
  if (/^20\d{2}-\d{2}-\d{2}$/.test(token || "")) return token;
  return base.toISOString().slice(0,10);
}

function isBookingHowTo(input) {
  const t = normalizeEgyptianText(input);
  return HOWTO_WORD.test(t) && BOOKING_WORD.test(t) && !STRONG_BOOKING.test(t);
}

function isExplicitConfirmation(input) {
  return /^(?:ايوه|أيوه|اه|آه|تمام|ماشي|موافق|موافقة|أكد الحجز|اكد الحجز|أكدلي الحجز|اكدلي الحجز|ثبت الحجز|ثبّت الحجز|احجزه|احجزهولي|احجزه لي|نفذ الحجز|نفذه|اتفقنا)$/i.test(normalizeEgyptianText(input));
}

function hasNearby(input) {
  return /قريب مني|قريب عني|قريب|جنبى|جنبي|حواليا|هنا|في منطقتي|بالقرب مني/i.test(normalizeEgyptianText(input));
}

function resolveVisibleReference(context, input) {
  const visible = Array.isArray(context?.last_visible_stadiums) ? context.last_visible_stadiums : [];
  if (!visible.length) return null;
  const t = normalizeEgyptianText(input);
  const ord = [
    /(?:^|\s)(?:اول|الاول|الأول)(?=\s|$)/i,
    /(?:^|\s)(?:تاني|التاني|الثاني)(?=\s|$)/i,
    /(?:^|\s)(?:تالت|التالت|الثالث)(?=\s|$)/i,
    /(?:^|\s)(?:رابع|الرابع|الرابعة)(?=\s|$)/i,
  ];
  for (let i=0;i<ord.length;i++) if (ord[i].test(t) && visible[i]) return visible[i];
  if (visible.length===1 && /الملعب ده|الملعب دي|اللي فوق|ده الملعب|هو ده|دي هي|احجزه|احجزلي/i.test(t))
    return visible[0];
  return null;
}

function classifyIntent(input) {
  const t = normalizeEgyptianText(input);
  if (isBookingHowTo(t)) return "booking_howto";
  if (STRONG_BOOKING.test(t)) return "book_stadium";
  if (/(?:حجز|ملعب|ملاعب|مواعيد ملعب|سعر الملعب)/i.test(t)) return "search_stadiums";
  if (/(?:بطولات|بطولة|كأس|جوائز|تورنمنت)/i.test(t)) return "tournaments";
  if (/(?:ماتشات? مفتوحة|ناقص لاعيبة|تقسيمة|مباراة مفتوحة)/i.test(t)) return "open_matches";
  if (/(?:الترتيب|المتصدر|الرانك|اول واحد|الأول)/i.test(t)) return "leaderboard";
  if (/(?:دخل|دخلي|إيراد|ايراد|فلوس|رصيد|مديون|مستحق|كاش|اونلاين|أونلاين|عمولة|رسوم)/i.test(t)) return "owner_financial";
  return null;
}

function analyzeCopilotTurn(input, contextSnapshot = {}) {
  const original = String(input || "").trim();
  const normalized = normalizeEgyptianText(original);
  const correction = findCorrectionTail(original);
  const effective = correction.text;
  const dateToken = extractDateToken(effective);
  const times = extractPreferredTimes(effective);
  const timeWindow = extractTimeWindow(effective);
  const groupSize = extractGroupSize(effective);
  const nearby = hasNearby(effective);
  const stadiumReference = resolveVisibleReference(contextSnapshot,effective);
  const explicitConfirmation = isExplicitConfirmation(original);
  const intent = classifyIntent(effective);
  const ambiguities = [];

  if (times.length > 0 && !/(مساء|مسا|بالليل|ليل|صباح|صبح|(?:^|\\s)م(?:\\s|$)|(?:^|\\s)ص(?:\\s|$))/i.test(effective))
    ambiguities.push("time_period");
  if (/\b\d{1,2}\b/.test(effective) && times.length===0 && groupSize===null && /حجز|ملعب/i.test(effective))
    ambiguities.push("numeric_entity");

  return {
    normalized,
    effective_text: effective,
    corrected: correction.corrected,
    intent,
    entities: {
      date_token: dateToken,
      date: dateToken ? resolveRelativeDate(dateToken) : null,
      preferred_times: times,
      time_window: timeWindow,
      group_size: groupSize,
      location_scope: nearby ? "nearby" : null,
      stadium_reference: stadiumReference ? {id:stadiumReference.id,name:stadiumReference.name} : null,
      confirmation: explicitConfirmation,
    },
    ambiguities,
    signals: {
      how_to: isBookingHowTo(original),
      explicit_execution: intent === "book_stadium",
      explicit_period: /مساء|مسا|بالليل|ليل|صباح|صبح|(?:^|\\s)م(?:\\s|$)|(?:^|\\s)ص(?:\\s|$)/i.test(effective),
    },
  };
}

function mergeConversationState(contextSnapshot, analysis) {
  const current = contextSnapshot?.task_state && typeof contextSnapshot.task_state === "object" ? contextSnapshot.task_state : {};
  const next = {...current};
  const e = analysis.entities || {};

  if (analysis.intent === "booking_howto") {
    next.intent = "booking_howto";
    delete next.confirmation_pending;
  } else if (analysis.intent === "book_stadium") {
    next.intent = "book_stadium";
  } else if (analysis.intent && (!next.intent || next.intent === "booking_howto")) {
    next.intent = analysis.intent;
  }

  if (e.date) next.date = e.date;
  if (Array.isArray(e.preferred_times) && e.preferred_times.length) {
    next.preferred_times = e.preferred_times;
    delete next.time_window;
  } else if (e.time_window) {
    next.time_window = e.time_window;
    next.preferred_times = [];
  }
  if (e.group_size != null) next.group_size = e.group_size;
  if (e.location_scope) next.stadium_scope = e.location_scope;
  if (e.stadium_reference) {
    next.stadium_id = e.stadium_reference.id;
    next.stadium_name = e.stadium_reference.name;
  }

  if (next.intent === "book_stadium") {
    const hasExact = Array.isArray(next.preferred_times) && next.preferred_times.length > 0;
    const hasWindow = !!next.time_window;
    const needs = [];
    if (!next.stadium_id && next.stadium_scope !== "nearby") needs.push("stadium");
    if (!next.date) needs.push("date");
    if (!hasExact && !hasWindow) needs.push("time");
    const explicitPeriod = !!analysis.signals?.explicit_period || hasWindow;
    if (hasExact && !explicitPeriod) needs.push("time_period");

    if (analysis.corrected || e.date || hasExact || hasWindow || e.stadium_reference)
      delete next.confirmation_pending;

    next.missing_slots = needs;
    next.time_period_confirmed = !needs.includes("time_period");
    next.ready_for_execution =
      needs.length === 0 &&
      next.time_period_confirmed === true &&
      hasExact &&
      !!next.stadium_id;
  } else if (next.intent === "booking_howto") {
    next.missing_slots = [];
    next.ready_for_execution = false;
    next.time_period_confirmed = true;
  } else {
    next.missing_slots = Array.isArray(next.missing_slots) ? next.missing_slots : [];
  }

  next.updated_at = new Date().toISOString();
  contextSnapshot.task_state = next;
  return next;
}

function buildDialogueDecision(taskState, analysis) {
  if (taskState?.intent === "booking_howto") return {type:"EXPLAIN_HOW_TO",next_slot:null};

  if (taskState?.intent === "book_stadium") {
    const missing = Array.isArray(taskState.missing_slots) ? taskState.missing_slots : [];
    if (missing.includes("stadium")) return {type:"ASK_SLOT",next_slot:"stadium"};
    if (missing.includes("date")) return {type:"ASK_SLOT",next_slot:"date"};
    if (missing.includes("time")) return {type:"ASK_SLOT",next_slot:"time"};
    if (missing.includes("time_period")) return {type:"ASK_SLOT",next_slot:"time_period"};
    if (taskState.confirmation_pending) return {type:"ASK_CONFIRMATION",next_slot:null};
    if (
      taskState.stadium_scope === "nearby" &&
      taskState.date &&
      ((Array.isArray(taskState.preferred_times) && taskState.preferred_times.length > 0) || taskState.time_window)
    ) return {type:"SEARCH_AND_CHECK",next_slot:null};
    if (taskState.ready_for_execution) return {type:"CHECK_AVAILABILITY",next_slot:null};
  }

  return {type:"DELEGATE_TO_DOMAIN",next_slot:null};
}

function buildResponseContract(taskState, decision, analysis) {
  const contract = {
    decision: decision.type,
    next_slot: decision.next_slot,
    facts: {},
    constraints: [
      "لا تسأل عن حقل غير موجود في next_slot.",
      "لا تخترع ملعباً أو سعرًا أو توافرًا.",
      "الأرقام التشغيلية لا تأتي إلا من أدوات VSP أو قاعدة البيانات.",
      "لا تغيّر قيمة مفهومة من نفس الرسالة دون تصريح أو تصحيح من المستخدم.",
    ],
    quick_replies: [],
  };

  if (analysis.entities?.group_size != null) contract.facts.group_size = analysis.entities.group_size;
  if (analysis.entities?.location_scope) contract.facts.location_scope = analysis.entities.location_scope;
  if (taskState?.date) contract.facts.date = taskState.date;
  if (Array.isArray(taskState?.preferred_times) && taskState.preferred_times.length)
    contract.facts.preferred_times = taskState.preferred_times;
  if (taskState?.time_window) contract.facts.time_window = taskState.time_window;
  if (taskState?.stadium_id)
    contract.facts.stadium = {id:taskState.stadium_id,name:taskState.stadium_name};

  if (decision.next_slot === "date") contract.quick_replies = ["النهارده","بكرة"];
  if (decision.next_slot === "time") contract.quick_replies = ["8 بالليل","9 بالليل","10 بالليل"];
  if (decision.next_slot === "time_period") contract.quick_replies = ["10 الصبح","10 بالليل"];

  return contract;
}

export {
  normalizeEgyptianText,
  parseNumberToken,
  extractGroupSize,
  extractPreferredTimes,
  extractTimeWindow,
  extractDateToken,
  isBookingHowTo,
  classifyIntent,
  analyzeCopilotTurn,
  mergeConversationState,
  buildDialogueDecision,
  buildResponseContract,
};
