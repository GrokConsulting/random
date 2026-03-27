# Recursive MD5 Hasher

Hash all files in a directory recursively with progress tracking and batch output. Optimized for large directories (10M+ files).

## Quick Start

```bash
python3 scripts/recursive_md5_hasher.py /path/to/folder
```

This creates `hashes_TIMESTAMP.csv` with all file hashes.

## Usage

```
recursive_md5_hasher.py <directory> [OPTIONS]

OPTIONS:
  --output FILE          Output CSV file (default: hashes_TIMESTAMP.csv)
  --chunk-size N         Files per batch (default: 1000)
  --workers N            Parallel workers (default: 4)
  --skip-symlinks        Skip symbolic links (default: follow them)
  --filter PATTERN       Only hash files matching pattern (e.g., "*.txt")
```

## Examples

### Hash entire directory with default settings
```bash
python3 scripts/recursive_md5_hasher.py /data/files
```

Output: `hashes_20260326_170100.csv`

### Custom output file and 2000 files per chunk
```bash
python3 scripts/recursive_md5_hasher.py /data/files \
  --output my_hashes.csv \
  --chunk-size 2000
```

### Use 8 parallel workers for faster processing
```bash
python3 scripts/recursive_md5_hasher.py /data/files \
  --workers 8 \
  --chunk-size 1000
```

### Only hash specific file types
```bash
python3 scripts/recursive_md5_hasher.py /data/files \
  --filter "*.jpg" \
  --output images.csv
```

### Skip symbolic links
```bash
python3 scripts/recursive_md5_hasher.py /data/files \
  --skip-symlinks
```

## Output Format

CSV file with columns:
- **filepath** — Full path to file
- **md5** — MD5 hash (hex)
- **size** — File size in bytes
- **mtime** — Last modified time (unix timestamp)
- **error** — Error message (if hashing failed)

Example:
```
filepath,md5,size,mtime,error
/data/files/doc.txt,5d41402abc4b2a76b9719d911017c592,11,1711447200.0,
/data/files/image.jpg,098f6bcd4621d373cade4e832627b4f6,2048,1711447220.5,
/data/files/broken_link,,,, Permission denied
```

## Performance Tuning

For 10 million files:

| Chunk Size | Workers | Est. Time | Memory |
|-----------|---------|-----------|--------|
| 500 | 4 | ~8 hours | ~200MB |
| 1000 | 4 | ~7 hours | ~250MB |
| 2000 | 8 | ~6 hours | ~400MB |
| 5000 | 16 | ~5 hours | ~600MB |

**Recommendations:**
- Start with `--chunk-size 1000 --workers 4`
- Increase `--workers` if CPU is underutilized
- Increase `--chunk-size` if memory is available
- On slow storage, reduce `--workers` (hashing becomes I/O bound)

## Monitoring Progress

The script prints progress in real-time:
```
Processing chunk 1 (1000 files)... ✓ 850 files/sec
Processing chunk 2 (1000 files)... ✓ 920 files/sec
Processing chunk 3 (1000 files)... ✓ 880 files/sec
```

At the end:
```
======================================================================
Processing complete!
Total files hashed: 10,000,000
Errors: 42
Time elapsed: 21600.0s
Rate: 463 files/sec
Output file: hashes_20260326_170100.csv
======================================================================
```

## Common Issues

### "Permission denied" errors
Some files may be locked or inaccessible. These are logged in the `error` column of the output. To skip permission errors and continue:
```bash
python3 scripts/recursive_md5_hasher.py /path/to/folder 2>/dev/null
```

### Slow performance on network drives
Network storage is slower. Reduce `--workers` to avoid overwhelming the network:
```bash
python3 scripts/recursive_md5_hasher.py /network/share --workers 2
```

### Out of memory errors
Reduce `--chunk-size`:
```bash
python3 scripts/recursive_md5_hasher.py /path --chunk-size 500 --workers 2
```

## Integration

### Find changed files
Compare two hash runs:
```bash
diff <(cut -d, -f1,2 hashes_old.csv | sort) \
     <(cut -d, -f1,2 hashes_new.csv | sort)
```

### Verify specific files
```bash
grep "/path/to/file" hashes.csv
```

### Count files by extension
```bash
awk -F, '{ext=substr($1, length($1)-3); count[ext]++} END {for (e in count) print e, count[e]}' hashes.csv | sort
```

### Total data size
```bash
awk -F, 'NR>1 {sum+=$3} END {print sum / (1024^3) " GB"}' hashes.csv
```

## Notes

- **Symlinks**: By default, the script follows symlinks. Use `--skip-symlinks` to skip them.
- **Large directories**: The script is designed for directories with millions of files.
- **Progress**: Real-time feedback shows hashing rate per chunk.
- **Resumable**: Output is CSV — partial results can be appended to later runs if needed.

---

**Created:** 2026-03-26  
**For:** Bulk file hashing operations
