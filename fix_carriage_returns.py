#!/usr/bin/env python3
"""
Script to fix carriage return issues in Python files
"""
import os
import glob

def fix_carriage_returns(file_path):
    """Fix carriage returns in a file"""
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
        
        # Replace \r\n with \n and standalone \r with \n
        content = content.replace(b'\r\n', b'\n').replace(b'\r', b'\n')
        
        with open(file_path, 'wb') as f:
            f.write(content)
        
        print(f"Fixed: {file_path}")
        return True
    except Exception as e:
        print(f"Error fixing {file_path}: {e}")
        return False

def main():
    """Main function to fix carriage returns in Python files"""
    # Get all Python files in the appointments directory
    python_files = glob.glob("appointments/**/*.py", recursive=True)
    
    # Also check main Python files
    python_files.extend(glob.glob("*.py"))
    
    fixed_count = 0
    for file_path in python_files:
        if fix_carriage_returns(file_path):
            fixed_count += 1
    
    print(f"\nFixed {fixed_count} files")

if __name__ == "__main__":
    main()