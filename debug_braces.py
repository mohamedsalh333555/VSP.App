
def check_braces(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    stack = []
    for row_idx, line in enumerate(lines):
        line_num = row_idx + 1
        for col_idx, char in enumerate(line):
            col_num = col_idx + 1
            if char == '{':
                stack.append(('{', line_num, col_num))
            elif char == '}':
                if not stack:
                    print(f"Extra closing brace at {line_num}:{col_num}")
                    return
                stack.pop()
    
    if stack:
        for b, ln, cn in stack:
            print(f"Unclosed {b} at {ln}:{cn}")
    else:
        print("Balanced!")

check_braces(r'c:\Users\pc\.gemini\antigravity\scratch\vsp_application\lib\features\player\screens\booking_confirmation_screen.dart')
