import os
import re

def remove_comments(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    if ext in ['.py', '.yaml', '.yml']:
        # Python/Yaml comments: #
        # Be careful not to match # inside strings
        # This is a simplified version, but usually works for simple cases
        new_content = re.sub(r'(?m)^[ \t]*#.*$', '', content) # Whole line comments
        new_content = re.sub(r'(\s)#.*$', r'\1', new_content) # End of line comments
    
    elif ext in ['.ino', '.cpp', '.h', '.c', '.dart', '.go', '.rs', '.js', '.ts']:
        # C-style comments: // and /* */
        # Remove multi-line comments
        new_content = re.sub(r'/\*[\s\S]*?\*/', '', content)
        # Remove single-line comments (careful with URLs)
        # Match // only if not preceded by : (like http://)
        new_content = re.sub(r'(?<!:)//.*$', '', new_content, flags=re.MULTILINE)
    
    else:
        return # Skip unknown extensions

    # Optional: remove extra empty lines created by comment removal
    # new_content = re.sub(r'\n\s*\n', '\n', new_content)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

def main():
    root_dir = r'c:\Users\erika\Downloads\teste'
    exclude_dirs = {'.git', '.vscode', 'node_modules', '__pycache__', 'target', 'build', '.dart_tool'}
    
    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            file_path = os.path.join(root, file)
            if file.endswith(('.py', '.ino', '.dart', '.go', '.rs', '.js', '.ts', '.yaml', '.yml')):
                print(f"Limpando: {file_path}")
                remove_comments(file_path)

if __name__ == "__main__":
    main()
