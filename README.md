# random

Collection of random scripts - use at peril unless you know what you're actually doing. No warranty and may be destructive.

## RECURSIVE_HASHER

Tools for recursively hashing files and finding duplicates.

### Recursive MD5 Hasher

Efficiently computes MD5 hashes for all files in a directory tree. Handles large directories with chunked processing and optional parallel execution.

**Available versions:**
- `recursive_md5_hasher.ps1` (PowerShell)
- `recursive_md5_hasher.py` (Python)

**Usage:**

PowerShell:
```powershell
.\recursive_md5_hasher.ps1 -Path "C:\path\to\folder" -OutputFile "hashes.csv"
.\recursive_md5_hasher.ps1 -Path "C:\path\to\folder" -ChunkSize 2000 -Workers 8
```

Python:
```bash
python recursive_md5_hasher.py -path "/path/to/folder" -output hashes.csv
python recursive_md5_hasher.py -path "/path/to/folder" --chunk-size 2000 --workers 8
```

**Output:** CSV file with columns: `filepath, md5, size, mtime, error`

**Options:**
- `-Path` / `-path`: Root directory to hash (required)
- `-OutputFile` / `-output`: Output CSV filename (default: `hashes_TIMESTAMP.csv`)
- `-ChunkSize` / `--chunk-size`: Files per batch (default: 1000)
- `-Workers` / `--workers`: Parallel jobs (default: 4)
- `-Filter` / `--filter`: File pattern filter (e.g., `*.jpg`)
- `-SkipSymlinks`: Skip symbolic links (PowerShell only)

### Find Duplicate Hashes

Analyzes hash output CSV to find all files with duplicate MD5 hashes. Groups duplicates and reports total space that could be saved.

**Available versions:**
- `find_duplicate_hashes.ps1` (PowerShell)
- `find_duplicate_hashes.py` (Python)
- `find_duplicate_hashes.sh` (Bash)

**Usage:**

PowerShell:
```powershell
.\find_duplicate_hashes.ps1 -CsvFile "hashes.csv"
.\find_duplicate_hashes.ps1 -CsvFile "hashes.csv" -OutputFile "duplicates_report.csv"
```

Python:
```bash
python find_duplicate_hashes.py hashes.csv
python find_duplicate_hashes.py hashes.csv duplicates_report.csv
```

Bash:
```bash
./find_duplicate_hashes.sh hashes.csv
./find_duplicate_hashes.sh hashes.csv duplicates_report.csv
```

**Output:**
- Console: List of duplicate hash groups sorted by frequency, with file paths and total size
- CSV (optional): Report file with columns: `MD5 Hash, File Count, Total Size, Files`

**Example Workflow:**

```powershell
# 1. Hash all files
.\recursive_md5_hasher.ps1 -Path "C:\MyFiles" -OutputFile "my_hashes.csv"

# 2. Find duplicates
.\find_duplicate_hashes.ps1 -CsvFile "my_hashes.csv" -OutputFile "duplicates.csv"

# 3. Review results
# - View console output for immediate summary
# - Open duplicates.csv for detailed report
```

### Notes

- **Performance:** PowerShell version supports parallel execution; Python version uses sequential processing by default
- **Large directories:** Both scripts handle 10M+ files efficiently with progress tracking
- **Cloud storage:** If hashing files on OneDrive/Google Drive, copy to local disk first to avoid "cloud provider not running" errors
- **Symbolic links:** PowerShell version can skip symlinks with `-SkipSymlinks` flag
