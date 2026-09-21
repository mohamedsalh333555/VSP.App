// Coreference Resolution Layer for VSP Copilot
// Maps semantic user references ("ده", "التاني", "اللي فوق", "نفس المعاد") against trusted context.

import type { VisibleEntity, ConversationState } from "./conversation_state.ts";
import type { SemanticReference, SemanticAmbiguity } from "./semantic_schema.ts";

export interface ResolvedReferences {
  resolved_stadium: VisibleEntity | null;
  resolved_time: string | null;
  resolved_date: string | null;
  ambiguities: SemanticAmbiguity[];
}

export function resolveReferences(
  state: ConversationState,
  references: SemanticReference[],
  rawInput: string
): ResolvedReferences {
  const result: ResolvedReferences = {
    resolved_stadium: null,
    resolved_time: null,
    resolved_date: null,
    ambiguities: [],
  };

  const visible = state.last_visible_entities.filter(e => e.entity_type === "stadium");
  const candidates = visible.length > 0 ? visible : state.candidate_stadiums;

  for (const ref of references) {
    // 1. Ordinal References: "الأول", "التاني", "التالت", "الرابع", "الأخير"
    if (ref.target === "first" || ref.target === "1") {
      if (candidates[0]) result.resolved_stadium = candidates[0];
    } else if (ref.target === "second" || ref.target === "2") {
      if (candidates[1]) result.resolved_stadium = candidates[1];
    } else if (ref.target === "third" || ref.target === "3") {
      if (candidates[2]) result.resolved_stadium = candidates[2];
    } else if (ref.target === "fourth" || ref.target === "4") {
      if (candidates[3]) result.resolved_stadium = candidates[3];
    } else if (ref.target === "last") {
      if (candidates.length > 0) result.resolved_stadium = candidates[candidates.length - 1];
    }

    // 2. Relative References: "اللي بعده", "اللي قبله"
    else if (ref.target === "next") {
      const currIdx = candidates.findIndex(c => c.id === state.stadium.id);
      if (currIdx >= 0 && candidates[currIdx + 1]) {
        result.resolved_stadium = candidates[currIdx + 1];
      } else if (candidates.length > 1) {
        result.resolved_stadium = candidates[1];
      }
    } else if (ref.target === "previous") {
      const currIdx = candidates.findIndex(c => c.id === state.stadium.id);
      if (currIdx > 0 && candidates[currIdx - 1]) {
        result.resolved_stadium = candidates[currIdx - 1];
      }
    }

    // 3. Demonstrative/Visible Reference: "ده", "دي", "اللي فوق", "last_visible"
    else if (ref.target === "last_visible" || ref.reference_type === "visible_entity") {
      if (candidates.length === 1) {
        result.resolved_stadium = candidates[0];
      } else if (candidates.length > 1) {
        // If user said "ده" but there are multiple stadiums visible, don't guess!
        result.ambiguities.push({
          type: "entity_choice",
          description: "في أكتر من ملعب معروض، تحب تحجز أنهي واحد فيهم؟",
          options: candidates.slice(0, 4).map(c => c.name),
        });
      }
    }

    // 4. Persistence Coreferences: "نفس الملعب", "نفس المعاد", "نفس المكان"
    else if (ref.target === "same_stadium" || ref.target === "same_as_before") {
      if (state.stadium.id && state.stadium.name) {
        result.resolved_stadium = {
          reference_key: "previous_stadium",
          entity_type: "stadium",
          id: state.stadium.id,
          name: state.stadium.name,
          price_per_hour: state.stadium.price_per_hour,
        };
      }
    } else if (ref.target === "same_time") {
      if (state.times.length > 0) {
        result.resolved_time = state.times[0].time;
      }
    }
  }

  // Fallback: If only 1 stadium was visible in context, and user explicitly requested booking
  // without mentioning another stadium name, automatically bind the visible stadium.
  if (!result.resolved_stadium && candidates.length === 1 && state.stadium.status !== "cleared") {
    result.resolved_stadium = candidates[0];
  }

  return result;
}
