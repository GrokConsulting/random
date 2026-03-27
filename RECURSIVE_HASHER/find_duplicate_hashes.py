#!/usr/bin/env python3
"""
Find duplicate files by MD5 hash from recursive_md5_hasher output CSV.
Groups files with identical hashes and reports duplicates.
"""

import csv
import sys
from collections import defaultdict
from pathlib import Path

def find_duplicates(csv_file, output_file=None):
    """Read CSV and find all files with duplicate MD5 hashes."""
    
    if not Path(csv_file).exists():
        print(f"Error: File not found: {csv_file}")
        sys.exit(1)
    
    # Group files by MD5 hash
    hash_groups = defaultdict(list)
    error_count = 0
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                if not row['md5'] or row['error']:
                    # Skip errors
                    if row['error']:
                        error_count += 1
                    continue
                
                hash_groups[row['md5']].append({
                    'filepath': row['filepath'],
                    'size': row['size'],
                    'mtime': row['mtime']
                })
    except Exception as e:
        print(f"Error reading CSV: {e}")
        sys.exit(1)
    
    # Filter to only groups with duplicates (2+ files)
    duplicates = {h: files for h, files in hash_groups.items() if len(files) > 1}
    
    if not duplicates:
        print("No duplicates found!")
        return
    
    print(f"Found {len(duplicates)} hash groups with duplicates")
    print(f"Total duplicate files: {sum(len(files) for files in duplicates.values())}")
    print(f"Skipped errors: {error_count}")
    print("")
    
    # Prepare output
    output_lines = []
    output_lines.append("MD5 Hash,File Count,Total Size,Files\n")
    
    # Sort by number of duplicates (most duplicates first)
    sorted_dupes = sorted(duplicates.items(), key=lambda x: len(x[1]), reverse=True)
    
    for md5_hash, files in sorted_dupes:
        file_count = len(files)
        total_size = sum(int(f['size']) if f['size'].isdigit() else 0 for f in files)
        
        # Format size
        if total_size > 1e9:
            size_str = f"{total_size / 1e9:.2f} GB"
        elif total_size > 1e6:
            size_str = f"{total_size / 1e6:.2f} MB"
        else:
            size_str = f"{total_size / 1e3:.2f} KB"
        
        # Build file list
        file_list = " | ".join(f['filepath'] for f in files)
        
        # Print to console
        print(f"Hash: {md5_hash}")
        print(f"  Count: {file_count} files | Total size: {size_str}")
        for f in files:
            print(f"    - {f['filepath']}")
        print("")
        
        # Add to output
        output_lines.append(f'"{md5_hash}",{file_count},"{size_str}","{file_list}"\n')
    
    # Write to output file if specified
    if output_file:
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.writelines(output_lines)
            print(f"Duplicate report saved to: {output_file}")
        except Exception as e:
            print(f"Error writing output file: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python find_duplicate_hashes.py <csv_file> [output_file]")
        print("")
        print("Arguments:")
        print("  csv_file   - Path to CSV output from recursive_md5_hasher.ps1/py")
        print("  output_file - (Optional) CSV file to write duplicate report")
        print("")
        print("Example:")
        print("  python find_duplicate_hashes.py hashes_20260327_120000.csv duplicates.csv")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    find_duplicates(csv_file, output_file)
