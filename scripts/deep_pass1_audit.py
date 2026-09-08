import os
import re
import json

base_dir = "lib"

# 1. Collect all files and LOC
dart_files = []
for root, dirs, files in os.walk(base_dir):
    for f in files:
        if f.endswith(".dart"):
            path = os.path.join(root, f).replace("\\", "/")
            dart_files.append(path)

# Map all imports and exports across all dart files (including test and web)
imported_basenames = set()
for search_dir in ["lib", "test", "web"]:
    if not os.path.exists(search_dir):
        continue
    for root, dirs, files in os.walk(search_dir):
        for f in files:
            if f.endswith(".dart"):
                with open(os.path.join(root, f), "r", encoding="utf-8", errors="ignore") as fp:
                    for line in fp:
                        if "import " in line or "export " in line:
                            # extract package or relative path
                            matches = re.findall(r"['\"]([^'\"]+\.dart)['\"]", line)
                            for m in matches:
                                imported_basenames.add(os.path.basename(m))

print("==================================================")
print("ARCHITECTURAL AUDIT REPORT (PASS 1 - READ ONLY)")
print("==================================================")

# DIMENSION 1: Layer Collapse (Direct DB / Supabase client calls inside UI screens and widgets)
ui_supabase_calls = []
for f in dart_files:
    if "/screens/" in f or "/widgets/" in f:
        with open(f, "r", encoding="utf-8", errors="ignore") as fp:
            for idx, line in enumerate(fp):
                l = line.strip()
                if "Supabase.instance.client" in l or "_supabase.from(" in l or "supabase.from(" in l:
                    ui_supabase_calls.append((f, idx + 1, l))

print(f"\n[DIMENSION 1] LAYER COLLAPSE: {len(ui_supabase_calls)} direct DB calls in UI:")
by_file = {}
for path, line_no, content in ui_supabase_calls:
    by_file.setdefault(path, []).append((line_no, content))

for path, items in sorted(by_file.items(), key=lambda x: len(x[1]), reverse=True):
    print(f"  * {path} ({len(items)} direct calls):")
    for line_no, content in items[:3]:
        print(f"      L{line_no}: {content[:90]}")
    if len(items) > 3:
        print(f"      ... and {len(items)-3} more in this file.")

# DIMENSION 2: Duplicated Logic & Drift (Pricing, fees, deposits, calculations)
print("\n[DIMENSION 2] DUPLICATED LOGIC & DRIFT:")
drift_patterns = [
    ("Platform Fee / Commission (0.02 / 2%)", re.compile(r"0\.02\b|platform_fee|p_platform_fee")),
    ("Deposit parsing / fallback", re.compile(r"deposit_amount|depositAmount")),
    ("Cancellation / Refund rules", re.compile(r"refund|cancellation|cancel_booking")),
]

for name, pattern in drift_patterns:
    matches = []
    for f in dart_files:
        with open(f, "r", encoding="utf-8", errors="ignore") as fp:
            for idx, line in enumerate(fp):
                if pattern.search(line) and not f.endswith("_test.dart"):
                    matches.append((f, idx + 1, line.strip()))
    print(f"  - {name}: found in {len(set(m[0] for m in matches))} files ({len(matches)} occurrences)")
    # Show distinct files
    seen = set()
    for f, idx, line in matches:
        if f not in seen and len(seen) < 5:
            seen.add(f)
            print(f"      {f}:L{idx} -> {line[:80]}")

# DIMENSION 3: Bloated Files (>600 LOC)
print("\n[DIMENSION 3] BLOATED FILES (>600 LOC):")
bloated = []
for f in dart_files:
    with open(f, "r", encoding="utf-8", errors="ignore") as fp:
        cnt = len(fp.readlines())
        if cnt > 600:
            bloated.append((f, cnt))

bloated.sort(key=lambda x: x[1], reverse=True)
print(f"  Total bloated files: {len(bloated)}")
for path, count in bloated:
    # categorize
    tag = "GENERATED" if "l10n" in path else ("UI SCREEN" if "/screens/" in path else ("REPO/MODEL" if "/repositories/" in path or "/data/" in path else "CORE/OTHER"))
    print(f"  [{tag:11}] {path:<65} : {count:>5} lines")

# DIMENSION 4: Unearned Abstractions / Thin Wrappers
print("\n[DIMENSION 4] UNEARNED ABSTRACTIONS & THIN WRAPPERS:")
thin_wrappers = []
for f in dart_files:
    if "/services/" in f or "/repositories/" in f:
        with open(f, "r", encoding="utf-8", errors="ignore") as fp:
            lines = [l.strip() for l in fp.readlines() if l.strip() and not l.strip().startswith("//")]
            if len(lines) < 40:
                thin_wrappers.append((f, len(lines)))

for path, count in thin_wrappers:
    print(f"  * {path} ({count} non-empty lines) -> Candidate for consolidation")

# DIMENSION 5: Dead Code / Unused Files
print("\n[DIMENSION 5] DEAD CODE (Unreferenced Files):")
dead_files = []
special_entrypoints = {
    "main.dart", "app_localizations.dart", "app_localizations_ar.dart", "app_localizations_en.dart"
}
for f in dart_files:
    bn = os.path.basename(f)
    if bn not in special_entrypoints and bn not in imported_basenames:
        dead_files.append(f)

for df in dead_files:
    with open(df, "r", encoding="utf-8", errors="ignore") as fp:
        lc = len(fp.readlines())
    print(f"  * [ORPHAN] {df} ({lc} lines) - 0 imports in the entire project")

# DIMENSION 6: Security & Data Boundaries
print("\n[DIMENSION 6] SECURITY & DATA BOUNDARIES (Flutter Layer):")
security_concerns = []
for f in dart_files:
    with open(f, "r", encoding="utf-8", errors="ignore") as fp:
        for idx, line in enumerate(fp):
            l = line.strip()
            # check for hardcoded secrets or service_role keys
            if "service_role" in l.lower() or "secret" in l.lower():
                if not f.endswith(".json") and "client" in f:
                    security_concerns.append((f, idx + 1, "Possible privileged keyword: " + l[:60]))
            # check for raw execute / direct rpc bypasses in UI
            if ("/screens/" in f or "/widgets/" in f) and "rpc(" in l:
                security_concerns.append((f, idx + 1, "Direct RPC execution from UI widget: " + l[:60]))

for f, idx, desc in security_concerns:
    print(f"  * {f}:L{idx} -> {desc}")

# DIMENSION 7: Dependency & Asset Hygiene
print("\n[DIMENSION 7] DEPENDENCY & ASSET HYGIENE:")
with open("pubspec.yaml", "r", encoding="utf-8", errors="ignore") as fp:
    pubspec = fp.read()

# Check font assets
has_cairo = os.path.exists("assets/fonts/Cairo-Regular.ttf") or os.path.exists("assets/fonts")
print(f"  * Local fonts present: {has_cairo}")
print(f"  * google_fonts in pubspec: {'google_fonts' in pubspec}")
