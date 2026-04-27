import json
import subprocess
import sys
import re

def run_credo():
    result = subprocess.run(["mix", "credo", "--strict", "--format", "json"], capture_output=True, text=True)
    return result.stdout

def main():
    try:
        output = run_credo()
    except Exception as e:
        print(f"Error running credo: {e}")
        return

    # Find the JSON part
    start = output.find('{')
    if start == -1:
        print("Could not find JSON output")
        return
    
    try:
        data = json.loads(output[start:])
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}")
        return
        
    issues = data.get('issues', [])
    
    # Process files
    files = {}
    for issue in issues:
        files.setdefault(issue['filename'], []).append(issue)
        
    for filename, file_issues in files.items():
        with open(filename, 'r') as f:
            content = f.read()
            
        original_content = content
        
        # 1. Fix AliasUsage
        alias_usage_issues = [i for i in file_issues if i['check'] == 'Credo.Check.Design.AliasUsage']
        
        aliases_to_add = set()
        for issue in alias_usage_issues:
            trigger = issue['trigger']
            # trigger is like "Rindle.Upload.Broker"
            if trigger:
                aliases_to_add.add(trigger)
                # replace trigger with the last part
                last_part = trigger.split('.')[-1]
                # carefully replace word boundaries
                content = re.sub(rf'\b{trigger}\b', last_part, content)
        
        if aliases_to_add:
            # find where to insert aliases
            # look for existing alias lines
            lines = content.split('\n')
            insert_idx = -1
            for i, line in enumerate(lines):
                if line.strip().startswith('alias '):
                    insert_idx = i + 1
            
            if insert_idx == -1:
                # look for defmodule
                for i, line in enumerate(lines):
                    if line.strip().startswith('defmodule '):
                        insert_idx = i + 1
                        break
            
            if insert_idx != -1:
                # figure out indentation
                indent = ""
                if insert_idx > 0:
                    match = re.match(r'^(\s*)', lines[insert_idx - 1])
                    if match:
                        indent = match.group(1)
                if not indent:
                    indent = "  "
                
                # filter out aliases that are already there
                new_alias_lines = [f"{indent}alias {a}" for a in sorted(aliases_to_add) if f"alias {a}" not in content]
                
                lines = lines[:insert_idx] + new_alias_lines + lines[insert_idx:]
                content = '\n'.join(lines)
                
        # 2. Fix AliasOrder
        alias_order_issues = [i for i in file_issues if i['check'] == 'Credo.Check.Readability.AliasOrder']
        if alias_order_issues or aliases_to_add: # if we added aliases, we might have messed up the order
            lines = content.split('\n')
            new_lines = []
            i = 0
            while i < len(lines):
                line = lines[i]
                if line.strip().startswith('alias '):
                    # collect alias block
                    block = []
                    while i < len(lines) and lines[i].strip().startswith('alias '):
                        block.append(lines[i])
                        i += 1
                    # sort block by the alias content
                    block.sort(key=lambda x: x.strip())
                    new_lines.extend(block)
                    continue
                else:
                    new_lines.append(line)
                    i += 1
            content = '\n'.join(new_lines)
            
        if content != original_content:
            with open(filename, 'w') as f:
                f.write(content)
            print(f"Fixed {filename}")

if __name__ == "__main__":
    main()
