
def find_imbalance(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    stack = []
    lines = content.split('\n')
    for row_idx, line in enumerate(lines):
        for col_idx, char in enumerate(line):
            if char == '{':
                stack.append(('{', row_idx+1, col_idx+1))
            elif char == '}':
                if not stack:
                    print(f"Excess '}}' at {row_idx+1}:{col_idx+1}")
                    return
                stack.pop()
    if stack:
        print(f"Unclosed '{stack[-1][0]}' at {stack[-1][1]}:{stack[-1][2]}")
    else:
        print("Perfectly balanced!")

find_imbalance(r'c:\Users\pc\.gemini\antigravity\scratch\vsp_application\lib\features\player\screens\booking_confirmation_screen.dart')
