path = r'K:\.gemini\antigravity\scratch\vsp_admin_panel\src\services\adminService.js'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'name: p.name?.trim() ||' in line:
        lines[i] = "          name: p.name?.trim() || `لاعب #${idx + 1}`,\n"
        print(f"Replaced line {i+1}: {lines[i]}")

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print("Done!")
