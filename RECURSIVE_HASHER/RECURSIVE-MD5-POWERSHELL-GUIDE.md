# Recursive MD5 Hasher — PowerShell Edition

Hash all files in a directory recursively with progress tracking and batch output. Optimized for Windows hosts where Python is unavailable.

## Quick Start

```powershell
.\recursive_md5_hasher.ps1 -Path "C:\data\files"
```

This creates `hashes_YYYYMMDD_HHMMSS.csv` with all file hashes.

## Usage

```
.\recursive_md5_hasher.ps1 -Path <directory> [OPTIONS]

OPTIONS:
  -OutputFile FILE       Output CSV file (default: hashes_TIMESTAMP.csv)
  -ChunkSize N          Files per batch (default: 1000)
  -Workers N            Parallel workers (default: 4)
  -SkipSymlinks         Skip symbolic links (default: follow them)
  -Filter PATTERN       File pattern filter (e.g., "*.txt")
```

## Requirements

- **Windows PowerShell 5.1+** (Windows 7 SP1 and later)
- **PowerShell 7+** (for better parallel performance)
- **Administrator rights** (may be needed for some file access)

## Examples

### Hash entire directory
```powershell
.\recursive_md5_hasher.ps1 -Path "C:\data\files"
```

### Custom output file with 2000 files per chunk
```powershell
.\recursive_md5_hasher.ps1 -Path "C:\data\files" `
  -OutputFile "my_hashes.csv" `
  -ChunkSize 2000
```

### Use 8 parallel workers
```powershell
.\recursive_md5_hasher.ps1 -Path "C:\data\files" `
  -ChunkSize 1000 `
  -Workers 8
```

### Only hash specific file types
```powershell
.\recursive_md5_hasher.ps1 -Path "C:\data\files" `
  -Filter "*.jpg" `
  -OutputFile "images.csv"
```

### Skip symbolic links
```powershell
.\recursive_md5_hasher.ps1 -Path "C:\data\files" -SkipSymlinks
```

### Network share (reduce workers for slower I/O)
```powershell
.\recursive_md5_hasher.ps1 -Path "\\server\share\files" `
  -Workers 2 `
  -ChunkSize 500
```

## Output Format

CSV file with columns:
- **filepath** — Full path to file
- **md5** — MD5 hash (lowercase hex)
- **size** — File size in bytes
- **mtime** — Last modified time (Unix timestamp)
- **error** — Error message (if hashing failed)

Example:
```
filepath,md5,size,mtime,error
C:\data\doc.txt,5d41402abc4b2a76b9719d911017c592,11,1711447200.0,
C:\data\image.jpg,098f6bcd4621d373cade4e832627b4f6,2048,1711447220.5,
C:\data\broken_link,,,, Access to the path is denied.
```

## Performance Tuning

For 10 million files:

| Chunk Size | Workers | Est. Time | Memory |
|-----------|---------|-----------|--------|
| 500 | 2 | ~10 hours | ~150MB |
| 1000 | 4 | ~8 hours | ~250MB |
| 2000 | 8 | ~6 hours | ~400MB |
| 5000 | 16 | ~5 hours | ~600MB |

**Recommendations:**
- Start with `-ChunkSize 1000 -Workers 4`
- On PowerShell 7+, increase `-Workers` to 8 for better parallelism
- On slower storage, reduce `-Workers` (disk I/O becomes bottleneck)
- On network shares, use `-Workers 2` to avoid overwhelming the network

## Monitoring Progress

The script prints real-time feedback:
```
Found 10000000 files (scan time: 45.2s)

Processing chunk 1 (1000 files)... ✓ 850 files/sec
Processing chunk 2 (1000 files)... ✓ 920 files/sec
Processing chunk 3 (1000 files)... ✓ 880 files/sec
```

At the end:
```
======================================================================
Processing complete!
Total files hashed: 10000000
Errors: 42
Time elapsed: 21600s
Rate: 463 files/sec
Output file: hashes_20260326_170100.csv
Total data size: 2.5 TB
======================================================================
```

## Common Issues

### "Script execution disabled" error
PowerShell execution policy may block scripts. Run as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then run the script again.

### "Access denied" errors
Some files may be locked or require admin rights. These are logged in the `error` column.

To run with elevated privileges:
```powershell
# Right-click PowerShell > "Run as Administrator"
# Then run the script
```

### Slow performance on network shares
Network storage is slower. Reduce workers and chunk size:
```powershell
.\recursive_md5_hasher.ps1 -Path "\\server\share" `
  -Workers 1 `
  -ChunkSize 100
```

### Out of memory errors
Reduce chunk size and workers:
```powershell
.\recursive_md5_hasher.ps1 -Path "C:\data" `
  -ChunkSize 500 `
  -Workers 2
```

## Integration with Other Tools

### Find changed files
```powershell
# Compare two hash exports
Compare-Object `
  (Import-Csv hashes_old.csv) `
  (Import-Csv hashes_new.csv) `
  -Property filepath, md5
```

### Verify specific files
```powershell
$csv = Import-Csv hashes.csv
$csv | Where-Object { $_.filepath -like "*important*" }
```

### Count files by extension
```powershell
$csv = Import-Csv hashes.csv
$csv | Group-Object { [System.IO.Path]::GetExtension($_.filepath) } | 
  Select-Object Name, Count
```

### Total data size
```powershell
$csv = Import-Csv hashes.csv
$totalBytes = ($csv | Measure-Object -Property size -Sum).Sum
$totalGB = [Math]::Round($totalBytes / 1GB, 2)
Write-Host "Total: $totalGB GB"
```

### Find duplicate files
```powershell
$csv = Import-Csv hashes.csv
$csv | Group-Object md5 | 
  Where-Object { $_.Count -gt 1 } |
  ForEach-Object { 
    Write-Host "Duplicate: $($_.Name)"
    $_.Group | Select-Object filepath
  }
```

## PowerShell Version Differences

### PowerShell 7+ (Recommended)
- Faster parallel processing with `ForEach-Object -Parallel`
- Better performance on multi-core systems
- Native support for `-ThrottleLimit`

### PowerShell 5.1 (Windows 10/Server 2016+)
- Uses `Start-Job` for parallelism
- Slightly slower than PowerShell 7
- Still effective for large-scale hashing

**Note:** If you have PowerShell 7+ installed, use it for better performance:
```powershell
pwsh.exe -File .\recursive_md5_hasher.ps1 -Path "C:\data"
```

## Advanced: Resuming Interrupted Operations

If the script is interrupted, you can continue from where it left off by hashing only new/modified files:

```powershell
# Get previously hashed files
$old = Import-Csv hashes.csv | Select-Object -ExpandProperty filepath

# Get all files
$all = Get-ChildItem -Path "C:\data" -File -Recurse

# Hash only new files
$new = $all | Where-Object { $_.FullName -notin $old }
```

## Notes

- **CSV Format:** Compatible with Excel, Power Query, SQL import, Python pandas, etc.
- **Symlinks:** By default followed; use `-SkipSymlinks` to skip them
- **Progress:** Real-time feedback shows hashing rate per chunk
- **Error Handling:** Failed hashes logged in `error` column; script continues

---

**Created:** 2026-03-26  
**For:** Windows hosts without Python  
**Compatibility:** PowerShell 5.1+
