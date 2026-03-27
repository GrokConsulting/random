#!/usr/bin/env python3
"""
Recursively hash all files in a folder with MD5, processing in chunks.
Handles large directories (10M+ files) with progress tracking and batch output.

Usage:
  recursive_md5_hasher.py <root_directory> [--output output.csv] [--chunk-size 1000] [--workers 4] [--skip-symlinks]

Options:
  --output FILE          Output CSV file (default: hashes_TIMESTAMP.csv)
  --chunk-size N         Files per batch (default: 1000)
  --workers N            Parallel workers (default: 4)
  --skip-symlinks        Skip symbolic links (default: follow them)
  --filter PATTERN       Only hash files matching pattern (e.g., "*.txt")

Output format: filepath,md5hash,filesize,mtime
"""

import os
import sys
import hashlib
import argparse
from pathlib import Path
from datetime import datetime
import json
import csv
from multiprocessing import Pool, Queue, Process
from queue import Empty
import time
from collections import deque

class FileHasher:
    """Hash files with progress tracking"""
    
    def __init__(self, chunk_size=1000, workers=4, skip_symlinks=False, filter_pattern=None):
        self.chunk_size = chunk_size
        self.workers = workers
        self.skip_symlinks = skip_symlinks
        self.filter_pattern = filter_pattern
        self.processed_count = 0
        self.error_count = 0
        self.start_time = time.time()
        
    @staticmethod
    def hash_file(filepath):
        """Calculate MD5 hash of a single file"""
        try:
            md5 = hashlib.md5()
            with open(filepath, 'rb') as f:
                for chunk in iter(lambda: f.read(8192), b''):
                    md5.update(chunk)
            
            stat = os.stat(filepath)
            return {
                'filepath': str(filepath),
                'md5': md5.hexdigest(),
                'size': stat.st_size,
                'mtime': stat.st_mtime,
            }
        except Exception as e:
            return {
                'filepath': str(filepath),
                'error': str(e),
            }
    
    def should_process_file(self, filepath):
        """Check if file matches filter criteria"""
        if self.filter_pattern and not filepath.match(self.filter_pattern):
            return False
        return True
    
    def walk_directory(self, root_dir):
        """Generator: yield file paths recursively"""
        root = Path(root_dir)
        
        for dirpath, dirnames, filenames in os.walk(root):
            # Skip symlinks if requested
            if self.skip_symlinks:
                dirnames[:] = [d for d in dirnames if not os.path.islink(os.path.join(dirpath, d))]
            
            for filename in filenames:
                filepath = Path(dirpath) / filename
                
                # Skip symlinks
                if self.skip_symlinks and os.path.islink(str(filepath)):
                    continue
                
                if self.should_process_file(filepath):
                    yield filepath
    
    def process_chunk(self, file_list):
        """Process a chunk of files with parallel workers"""
        if not file_list:
            return []
        
        with Pool(processes=self.workers) as pool:
            results = pool.map(self.hash_file, file_list, chunksize=10)
        
        return results
    
    def hash_directory(self, root_dir, output_file=None):
        """Hash all files in directory, output in chunks"""
        
        output_file = output_file or f"hashes_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        
        print(f"Starting file hash operation")
        print(f"Root directory: {root_dir}")
        print(f"Output file: {output_file}")
        print(f"Chunk size: {self.chunk_size}")
        print(f"Workers: {self.workers}")
        print()
        
        # Open output CSV
        with open(output_file, 'w', newline='') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=['filepath', 'md5', 'size', 'mtime', 'error'])
            writer.writeheader()
            
            # Process files in chunks
            chunk = []
            chunk_num = 0
            
            for filepath in self.walk_directory(root_dir):
                chunk.append(str(filepath))
                
                if len(chunk) >= self.chunk_size:
                    chunk_num += 1
                    self._process_and_write_chunk(writer, chunk, chunk_num)
                    chunk = []
            
            # Process remaining files
            if chunk:
                chunk_num += 1
                self._process_and_write_chunk(writer, chunk, chunk_num)
        
        # Print summary
        elapsed = time.time() - self.start_time
        rate = self.processed_count / elapsed if elapsed > 0 else 0
        
        print()
        print("="*70)
        print(f"Processing complete!")
        print(f"Total files hashed: {self.processed_count}")
        print(f"Errors: {self.error_count}")
        print(f"Time elapsed: {elapsed:.1f}s")
        print(f"Rate: {rate:.0f} files/sec")
        print(f"Output file: {output_file}")
        print("="*70)
        
        return output_file
    
    def _process_and_write_chunk(self, writer, chunk, chunk_num):
        """Process a chunk and write to CSV"""
        print(f"Processing chunk {chunk_num} ({len(chunk)} files)...", end=' ', flush=True)
        
        start = time.time()
        results = self.process_chunk(chunk)
        elapsed = time.time() - start
        
        # Write results
        for result in results:
            writer.writerow(result)
            if 'error' in result:
                self.error_count += 1
            else:
                self.processed_count += 1
        
        rate = len(chunk) / elapsed if elapsed > 0 else 0
        print(f"✓ {rate:.0f} files/sec")

def main():
    parser = argparse.ArgumentParser(
        description='Recursively hash files in a directory with MD5',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument('directory', help='Root directory to hash')
    parser.add_argument('--output', '-o', help='Output CSV file')
    parser.add_argument('--chunk-size', '-c', type=int, default=1000,
                       help='Files per batch (default: 1000)')
    parser.add_argument('--workers', '-w', type=int, default=4,
                       help='Parallel workers (default: 4)')
    parser.add_argument('--skip-symlinks', action='store_true',
                       help='Skip symbolic links')
    parser.add_argument('--filter', '-f', help='File pattern filter (e.g., "*.txt")')
    
    args = parser.parse_args()
    
    # Validate directory
    root_dir = Path(args.directory)
    if not root_dir.exists():
        print(f"Error: Directory not found: {args.directory}")
        sys.exit(1)
    
    if not root_dir.is_dir():
        print(f"Error: Not a directory: {args.directory}")
        sys.exit(1)
    
    # Create hasher and run
    hasher = FileHasher(
        chunk_size=args.chunk_size,
        workers=args.workers,
        skip_symlinks=args.skip_symlinks,
        filter_pattern=args.filter
    )
    
    output_file = hasher.hash_directory(str(root_dir), args.output)
    
    # Print summary stats
    try:
        with open(output_file, 'r') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            if rows:
                total_size = sum(int(r.get('size', 0)) for r in rows if r.get('size'))
                print(f"\nTotal data size: {total_size / (1024**3):.2f} GB")
    except:
        pass

if __name__ == '__main__':
    main()
