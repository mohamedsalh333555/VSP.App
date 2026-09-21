// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

import { hydrateConversationState } from "./conversation_state.ts";
import { parseUserMessageSemantically } from "./semantic_parser.ts";
import { resolveReferences } from "./reference_resolver.ts";
import { mergeState } from "./state_merger.ts";
import { planToolExecution } from "./tool_planner.ts";
import { executeGuardedTool } from "./tool_executor.ts";
import {
  buildResponseGeneratorPrompt,
  generateDeterministicResponse,
} from "./response_generator.ts";

declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // 1. Initialize Supabase Admin Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Strict Fail-Closed Authentication
    const authHeader = req.headers.get("Authorization") || req.headers.get("authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "").trim();
    const { data: { user: callerUser }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid or expired authentication token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Rate Limiting Check
    const { data: isAllowed, error: rateLimitErr } = await supabase.rpc("check_rate_limit", {
      p_user_id: callerUser.id,
      p_action: "copilot_chat",
      p_max_requests: 20,
      p_window_seconds: 60,
    });

    if (rateLimitErr || isAllowed === false) {
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Please wait a minute before sending more messages." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Parse Request Payload
    const body = await req.json();
    const userMessage = (body.message ?? "").toString().trim();
    let conversationId = (body.conversation_id ?? "").toString().trim();
    const requestedGov = (body.governorate ?? "").toString().trim();

    if (!userMessage) {
      return new Response(
        JSON.stringify({ error: "Bad Request: message is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Fetch User Profile
    const { data: userProfile } = await supabase
      .from("users")
      .select("name, governorate, position, role")
      .eq("id", callerUser.id)
      .maybeSingle();

    const userRole: "player" | "owner" | "admin" =
      userProfile?.role === "pitch_owner" || userProfile?.role === "owner" ? "owner" : "player";

    // 6. Retrieve or Initialize Conversation Session
    let contextSnapshot: Record<string, any> = {};
    if (conversationId) {
      const { data: existingConv } = await supabase
        .from("copilot_conversations")
        .select("id, context_snapshot")
        .eq("id", conversationId)
        .eq("user_id", callerUser.id)
        .maybeSingle();

      if (existingConv) {
        contextSnapshot = existingConv.context_snapshot || {};
      } else {
        conversationId = "";
      }
    }

    if (!conversationId) {
      const generatedTitle = userMessage.length > 35
        ? userMessage.substring(0, 35) + "..."
        : userMessage;

      const { data: newConv, error: convErr } = await supabase
        .from("copilot_conversations")
        .insert({
          user_id: callerUser.id,
          title: generatedTitle,
          context_snapshot: {},
        })
        .select("id, context_snapshot")
        .single();

      if (convErr || !newConv) {
        throw new Error("Failed to initialize conversation session: " + (convErr?.message || ""));
      }
      conversationId = newConv.id;
      contextSnapshot = newConv.context_snapshot || {};
    }

    // 7. Load Recent Message History
    const { data: priorMessages } = await supabase
      .from("copilot_messages")
      .select("role, content, ui_metadata")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true })
      .limit(6);

    const recentHistory: Array<{ role: string; content: string }> = (priorMessages || []).map((m: any) => ({
      role: m.role,
      content: m.content,
    }));

    // 8. Hydrate Conversation State
    const currentState = hydrateConversationState(contextSnapshot, userRole);
    if (requestedGov && !currentState.location_scope) {
      currentState.location_scope = requestedGov;
    }

    // 9. Semantic Language Understanding (Gemini Structured Output)
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    const semanticOutput = await parseUserMessageSemantically(
      userMessage,
      currentState,
      recentHistory,
      geminiApiKey
    );

    // 10. Reference Resolution against Trusted Context
    const resolvedReferences = resolveReferences(currentState, semanticOutput.references, userMessage);

    // 11. Deterministic State Merge
    const nextState = mergeState(currentState, semanticOutput, resolvedReferences);

    // 12. Deterministic Tool Planning
    const toolPlan = planToolExecution(nextState, semanticOutput);

    // 13. Guarded Tool Execution
    let toolResult: any = null;
    if (toolPlan.action === "EXECUTE_TOOL" && toolPlan.toolName) {
      toolResult = await executeGuardedTool(
        supabase,
        callerUser,
        toolPlan.toolName,
        toolPlan.toolArgs || {},
        nextState
      );

      // Apply any state updates produced by the verified tool result
      if (toolResult.updated_state) {
        Object.assign(nextState, toolResult.updated_state);
      }
    }

    // 14. Response Generation
    let assistantReply = "";
    let quickReplies: string[] = toolPlan.quick_replies || [];

    if (toolResult?.quick_replies) {
      quickReplies = toolResult.quick_replies;
    }

    // Use Gemini response generator if API key is available
    if (geminiApiKey) {
      try {
        const responsePrompt = buildResponseGeneratorPrompt(nextState, toolPlan, toolResult, userMessage);
        const genUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`;
        const genPayload = {
          contents: [{ role: "user", parts: [{ text: responsePrompt }] }],
          generationConfig: { temperature: 0.3 },
        };

        const genRes = await fetch(genUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(genPayload),
        });

        if (genRes.ok) {
          const genData = await genRes.json();
          const candidateText = genData.candidates?.[0]?.content?.parts?.[0]?.text;
          if (candidateText && candidateText.trim().length > 0) {
            assistantReply = candidateText.trim();
          }
        }
      } catch (genErr) {
        console.warn("[ResponseGenerator] Gemini generation failed, using deterministic fallback:", genErr);
      }
    }

    // Safe Deterministic Fallback if Gemini response is empty or failed
    if (!assistantReply) {
      const fallback = generateDeterministicResponse(nextState, toolPlan, toolResult);
      assistantReply = fallback.message;
      if (quickReplies.length === 0) {
        quickReplies = fallback.quick_replies;
      }
    }

    // 15. Prepare Enriched UI Metadata & Snapshot
    const stadiumResults = toolResult?.stadiums || (
      toolPlan.action === "EXECUTE_TOOL" && toolPlan.toolName === "checkStadiumAvailability" && nextState.stadium.id
        ? [{
            id: nextState.stadium.id,
            name: nextState.stadium.name,
            price_per_hour: nextState.stadium.price_per_hour || 0,
            governorate: userProfile?.governorate || "القاهرة",
          }]
        : []
    );

    const tournamentResults = toolResult?.tournaments || [];
    const leaderboardResults = toolResult?.leaderboard || [];
    const openMatchResults = toolResult?.open_matches || [];
    const appAction = toolResult?.app_action || null;

    // Synchronize snapshot for persistent state
    contextSnapshot.task_state = {
      intent: nextState.active_task,
      stadium_id: nextState.stadium.id,
      stadium_name: nextState.stadium.name,
      date: nextState.date.value,
      preferred_times: nextState.times.map(t => t.time),
      time_period_confirmed: nextState.time_period_confirmed,
      duration_hours: nextState.duration_hours,
      group_size: nextState.group_size,
      location_scope: nextState.location_scope,
      confirmation_pending: nextState.pending_confirmation,
      status: nextState.task_lifecycle,
    };
    contextSnapshot.last_stadium_id = nextState.stadium.id;
    contextSnapshot.last_stadium_name = nextState.stadium.name;
    contextSnapshot.last_date = nextState.date.value;
    contextSnapshot.last_visible_stadiums = stadiumResults.length > 0 ? stadiumResults : (contextSnapshot.last_visible_stadiums || []);
    contextSnapshot.conversation_state = nextState;

    const persistedUiMetadata = {
      stadiums: stadiumResults,
      tournaments: tournamentResults,
      leaderboard: leaderboardResults,
      open_matches: openMatchResults,
      action: appAction,
      task_state: contextSnapshot.task_state,
      plan: toolPlan,
      semantic_intent: semanticOutput.intent,
      semantic_speech_act: semanticOutput.speech_act,
    };

    // 16. Atomic Persistence via single database transaction
    const { data: persistedTurn, error: persistTurnErr } = await supabase.rpc("persist_copilot_turn", {
      p_conversation_id: conversationId,
      p_user_id: callerUser.id,
      p_user_content: userMessage,
      p_assistant_content: assistantReply,
      p_stadium_results: stadiumResults,
      p_ui_metadata: persistedUiMetadata,
      p_context_snapshot: contextSnapshot,
    });

    if (persistTurnErr || persistedTurn !== true) {
      console.error("[VSP Copilot] Failed to persist turn atomically:", persistTurnErr?.message);
      return new Response(
        JSON.stringify({ error: "Failed to persist Copilot conversation turn" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 17. Return Enriched Response Payload
    return new Response(
      JSON.stringify({
        conversation_id: conversationId,
        message: assistantReply,
        stadiums: stadiumResults,
        tournaments: tournamentResults,
        leaderboard: leaderboardResults,
        open_matches: openMatchResults,
        action: appAction,
        ui_metadata: persistedUiMetadata,
        task_state: contextSnapshot.task_state,
        quick_replies: quickReplies,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[VSP Copilot] Edge function unhandled exception:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
