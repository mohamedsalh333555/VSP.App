
import os, glob

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # We want to replace 'SingleChildScrollView(' with 'SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,'
    # But only if it doesn't already have it.
    if 'SingleChildScrollView(' in content and 'ScrollViewKeyboardDismissBehavior.onDrag' not in content:
        content = content.replace('SingleChildScrollView(', 'SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, ')
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Fixed {file_path}')

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

