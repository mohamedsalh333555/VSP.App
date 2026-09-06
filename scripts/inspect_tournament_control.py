with open('../vsp_admin_panel/src/pages/TournamentControlPage.jsx', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.splitlines()
print(f"Total lines: {len(lines)}")
for i, line in enumerate(lines):
    if i < 150 or i > len(lines) - 150:
        print(f"{i+1}: {line}")
    elif i == 150:
        print("... [TRUNCATED] ...")
