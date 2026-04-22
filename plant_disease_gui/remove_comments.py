import re
import sys
import os

def remove_comments(text):
    text = re.sub(re.compile(r"/\*.*?\*/", re.DOTALL), "", text)

    lines = text.split('\n')
    new_lines = []
    for line in lines:
        parts = re.split(r'(?<!:)\/\/.*$', line)
        new_lines.append(parts[0].rstrip())
    return '\n'.join(new_lines)

def process_file(file_path):
    if not os.path.exists(file_path):
        return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    clean_content = remove_comments(content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(clean_content)

if __name__ == "__main__":
    files = [
        r'c:\Users\erika\Downloads\teste\plant_disease_gui\lib\main.dart',
        r'c:\Users\erika\Downloads\teste\plant_disease_gui\lib\services\database_service.dart',
        r'c:\Users\erika\Downloads\teste\plant_disease_gui\lib\services\app_provider.dart'
    ]
    for f in files:
        print(f"Cleaning {f}...")
        process_file(f)
    print("Done!")
