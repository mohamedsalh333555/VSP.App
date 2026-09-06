import json

log_path = r'C:\Users\pc\.gemini\antigravity-ide\brain\cfccf243-831e-4119-9de6-acb3bee89077\.system_generated\logs\transcript.jsonl'

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        if 'hana.ramadan' in line or 'vsp_admin_panel' in line:
            if 'password' in line.lower():
                try:
                    obj = json.loads(line)
                    print(json.dumps(obj, indent=2)[:500])
                except:
                    print(line[:300])
