import urllib.request
import json
import os
import sys

def main():
    with open("env.json", "r") as f:
        env = json.load(f)

    token = env["SUPABASE_MANAGEMENT_KEY"]
    project_ref = "mktqkddbcddrxjxabdua"
    url = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"

    def run_query(sql):
        payload = json.dumps({"query": sql}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
                "User-Agent": "Mozilla/5.0",
            },
            method="POST",
        )
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))

    print("Fetching complete database schema...")
    output = []
    output.append("-- ==========================================================================")
    output.append("-- VSP SUPABASE SCHEMA REFERENCE BACKUP - PHASE 0")
    output.append(f"-- Project Ref: {project_ref}")
    output.append("-- Exported automatically via Supabase Management API")
    output.append("-- ==========================================================================\n")

    # 1. Extensions
    print("1. Exporting Extensions...")
    exts = run_query("SELECT extname, extversion FROM pg_extension WHERE extname NOT IN ('plpgsql');")
    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 1. EXTENSIONS")
    output.append("-- --------------------------------------------------------------------------")
    for ext in exts:
        output.append(f"CREATE EXTENSION IF NOT EXISTS \"{ext['extname']}\" WITH VERSION '{ext['extversion']}';")
    output.append("\n")

    # 2. Enums / Custom Types
    print("2. Exporting Custom Types / Enums...")
    types = run_query("""
        SELECT t.typname, string_agg(quote_literal(e.enumlabel), ', ' ORDER BY e.enumsortorder) AS enum_values
        FROM pg_type t
        JOIN pg_enum e ON t.oid = e.enumtypid
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
        GROUP BY t.typname;
    """)
    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 2. CUSTOM TYPES / ENUMS")
    output.append("-- --------------------------------------------------------------------------")
    for t in types:
        output.append(f"DO $$ BEGIN\n    CREATE TYPE public.\"{t['typname']}\" AS ENUM ({t['enum_values']});\nEXCEPTION\n    WHEN duplicate_object THEN null;\nEND $$;\n")
    output.append("\n")

    # 3. Tables and Columns
    print("3. Exporting Tables and Columns...")
    tables = run_query("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    """)

    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 3. TABLES DEFINITION")
    output.append("-- --------------------------------------------------------------------------")
    for tbl in tables:
        tname = tbl['table_name']
        cols = run_query(f"""
            SELECT 
                column_name, 
                data_type, 
                udt_name,
                is_nullable, 
                column_default,
                character_maximum_length
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = '{tname}'
            ORDER BY ordinal_position;
        """)
        
        output.append(f"CREATE TABLE IF NOT EXISTS public.\"{tname}\" (")
        col_defs = []
        for col in cols:
            cname = col['column_name']
            ctype = col['data_type'].upper()
            if ctype == 'USER-DEFINED':
                ctype = f"public.\"{col['udt_name']}\""
            elif col['character_maximum_length']:
                ctype = f"{ctype}({col['character_maximum_length']})"
            elif ctype == 'ARRAY':
                ctype = f"{col['udt_name'].replace('_', '')}[]"
            
            nullable = "NOT NULL" if col['is_nullable'] == 'NO' else ""
            default = f"DEFAULT {col['column_default']}" if col['column_default'] is not None else ""
            
            parts = [f"    \"{cname}\"", ctype, nullable, default]
            col_defs.append(" ".join([p for p in parts if p]))
        
        output.append(",\n".join(col_defs))
        output.append(");\n")

    # 4. Table RLS status
    print("4. Exporting RLS Status...")
    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 4. ROW LEVEL SECURITY STATUS")
    output.append("-- --------------------------------------------------------------------------")
    rls_status = run_query("""
        SELECT tablename, rowsecurity
        FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY tablename;
    """)
    for rls in rls_status:
        if rls['rowsecurity']:
            output.append(f"ALTER TABLE public.\"{rls['tablename']}\" ENABLE ROW LEVEL SECURITY;")
        else:
            output.append(f"ALTER TABLE public.\"{rls['tablename']}\" DISABLE ROW LEVEL SECURITY;")
    output.append("\n")

    # 5. Constraints (PK, FK, Unique, Check)
    print("5. Exporting Table Constraints...")
    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 5. CONSTRAINTS (PK, FK, UNIQUE, CHECK)")
    output.append("-- --------------------------------------------------------------------------")
    constraints = run_query("""
        SELECT 
            conrelid::regclass AS table_name,
            conname AS constraint_name,
            pg_get_constraintdef(c.oid, true) AS constraint_def
        FROM pg_constraint c
        JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE n.nspname = 'public'
        ORDER BY conrelid::regclass::text, c.contype DESC, conname;
    """)
    for con in constraints:
        output.append(f"ALTER TABLE {con['table_name']} DROP CONSTRAINT IF EXISTS \"{con['constraint_name']}\";")
        output.append(f"ALTER TABLE {con['table_name']} ADD CONSTRAINT \"{con['constraint_name']}\" {con['constraint_def']};\n")
    output.append("\n")

    # 6. Indexes
    print("6. Exporting Indexes...")
    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 6. INDEXES")
    output.append("-- --------------------------------------------------------------------------")
    indexes = run_query("""
        SELECT tablename, indexname, indexdef
        FROM pg_indexes
        WHERE schemaname = 'public' AND indexname NOT LIKE '%_pkey'
        ORDER BY tablename, indexname;
    """)
    for idx in indexes:
        output.append(f"{idx['indexdef']};")
    output.append("\n")

    # 7. RLS Policies
    print("7. Exporting RLS Policies...")
    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 7. ROW LEVEL SECURITY POLICIES")
    output.append("-- --------------------------------------------------------------------------")
    policies = run_query("""
        SELECT 
            tablename,
            policyname,
            permissive,
            roles,
            cmd,
            qual,
            with_check
        FROM pg_policies
        WHERE schemaname = 'public'
        ORDER BY tablename, policyname;
    """)
    for pol in policies:
        output.append(f"DROP POLICY IF EXISTS \"{pol['policyname']}\" ON public.\"{pol['tablename']}\";")
        cmd = pol['cmd']
        roles_str = ", ".join(pol['roles']) if pol['roles'] else "PUBLIC"
        permissive = "AS RESTRICTIVE" if pol['permissive'] == 'RESTRICTIVE' else "AS PERMISSIVE"
        
        pol_stmt = f"CREATE POLICY \"{pol['policyname']}\" ON public.\"{pol['tablename']}\" {permissive} FOR {cmd} TO {roles_str}"
        if pol['qual']:
            pol_stmt += f" USING ({pol['qual']})"
        if pol['with_check']:
            pol_stmt += f" WITH CHECK ({pol['with_check']})"
        output.append(f"{pol_stmt};\n")
    output.append("\n")

    # 8. Functions & Stored Procedures
    print("8. Exporting Functions...")
    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 8. FUNCTIONS & STORED PROCEDURES")
    output.append("-- --------------------------------------------------------------------------")
    functions = run_query("""
        SELECT 
            p.proname,
            p.oid,
            pg_get_functiondef(p.oid) AS def
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
        ORDER BY p.proname;
    """)
    for fn in functions:
        output.append(f"-- Function: {fn['proname']}")
        output.append(f"{fn['def']};\n")
    output.append("\n")

    # 9. Triggers
    print("9. Exporting Triggers...")
    output.append("-- --------------------------------------------------------------------------")
    output.append("-- 9. TRIGGERS")
    output.append("-- --------------------------------------------------------------------------")
    triggers = run_query("""
        SELECT 
            event_object_table,
            trigger_name,
            pg_get_triggerdef(t.oid, true) AS trigger_def
        FROM information_schema.triggers it
        JOIN pg_trigger t ON t.tgname = it.trigger_name
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE it.trigger_schema = 'public' AND n.nspname = 'public' AND NOT t.tgisinternal
        ORDER BY event_object_table, trigger_name;
    """)
    for trg in triggers:
        output.append(f"DROP TRIGGER IF EXISTS \"{trg['trigger_name']}\" ON public.\"{trg['event_object_table']}\";")
        output.append(f"{trg['trigger_def']};\n")
    output.append("\n")

    # Save to file
    backup_file = "supabase/schema_backup_reference_phase0.sql"
    with open(backup_file, "w", encoding="utf-8") as f:
        f.write("\n".join(output))

    print(f"\nSUCCESS! Complete schema reference backup written to {backup_file} ({len(output)} lines).")

if __name__ == "__main__":
    main()
