path = r'K:\.gemini\antigravity\scratch\vsp_admin_panel\src\services\adminService.js'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'لاعب #' in line and '`' not in line:
        # replace any unquoted Arabic لاعب #
        lines[i] = line.replace('لاعب #', '`لاعب #${idx + 1}`')
        print(f"Fixed line {i+1}: {lines[i]}")

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print("Finished fixing adminService.js!")
