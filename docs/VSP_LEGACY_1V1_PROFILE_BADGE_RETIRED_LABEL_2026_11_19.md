# VSP — retired 1v1 trophy badge is explicitly historical
19 November 2026. Branch uxlp-44-implementation, Draft PR #35.

The old player-profile trophy badge had only a number and medal; only hover/semantics described it as historical. The visible chip now adds “تاريخي” in Arabic or “Legacy” in English while retaining the existing historical title lookup, full tooltip and archived records. It does not represent a current 1v1 competition or a new Team Skills Cup award. One-line ellipsis bounds the chip on mobile.

Four widget checks cover both locales, absence of trophies, and a pending old-account lookup during account switch. The focused Team Profile CI workflow now analyzes and runs this contract. This improves but does not fully accept 86.04; the remaining cross-surface publication and live-state checks remain open. Tracker: 640 total / 346 accepted / 294 open. No main merge or production writes.
