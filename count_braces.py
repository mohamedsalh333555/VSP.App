
import sys

with open(r'c:\Users\pc\.gemini\antigravity\scratch\vsp_application\lib\features\player\screens\booking_confirmation_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
    open_braces = content.count('{')
    close_braces = content.count('}')
    open_parens = content.count('(')
    close_parens = content.count(')')
    print(f"Braces: {{: {open_braces}, }}: {close_braces}")
    print(f"Parens: (: {open_parens}, ): {close_parens}")
