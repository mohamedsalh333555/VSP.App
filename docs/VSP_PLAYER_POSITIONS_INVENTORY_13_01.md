# 13.01 — Inventory of selectable playing positions

The authoritative client registry is `SportPositionsRegistry` in `lib/core/ui/tokens/vsp_tokens.dart`. `VSPPositionSelector` in `lib/shared/widgets/vsp_position_selector.dart` obtains the options from `getPositionsForSport(sport)`, shows localized Arabic/English names and returns the **position code** in `onPositionSelected`.

| Sport | Supported stored codes | Default |
|---|---|---|
| Football | `GK` goalkeeper, `DF` defender, `MF` midfielder, `FW` forward | `FW` |
| Padel | `Drive`, `Revés`, `All-Round` | `All-Round` |
| Basketball | `PG`, `SG`, `SF`, `PF`, `C` | `SF` |
| Volleyball | `Setter`, `Spiker`, `Libero`, `Blocker` | `Spiker` |
| Handball | `GK`, `Wing`, `Back`, `Pivot`, `Playmaker` | `Wing` |

The VSP football player profile should store **codes**, not localized labels. Unknown sport names fall back to football positions; this is existing registry behavior, not proof that unsupported sports should be selectable. Codes like `GK` are **sport-scoped** and must not be interpreted without a sport context.

**Completion boundary:** 13.01 is a complete inventory of positions available through the shared selector. Persistence of primary/secondary positions (13.02), preferences (13.03), discovery (13.04), server validation (13.05), and runtime testing (13.06) are separate and not accepted here.
