import json
import os

ar_path = r'c:\Users\pc\.gemini\antigravity\scratch\vsp_application\lib\l10n\app_ar.arb'
en_path = r'c:\Users\pc\.gemini\antigravity\scratch\vsp_application\lib\l10n\app_en.arb'

with open(en_path, 'r', encoding='utf-8') as f:
    en_data = json.load(f)

with open(ar_path, 'r', encoding='utf-8') as f:
    ar_data = json.load(f)

en_keys = set(k for k in en_data.keys() if not k.startswith('@'))
ar_keys = set(k for k in ar_data.keys() if not k.startswith('@'))

missing_in_ar = en_keys - ar_keys
missing_in_en = ar_keys - en_keys

print(f"Keys missing in AR: {missing_in_ar}")
print(f"Keys missing in EN: {missing_in_en}")
