<#
.SYNOPSIS
    Find duplicate files by MD5 hash from recursive_md5_hasher output CSV.

.DESCRIPTION
    Reads CSV output from recursive_md5_hasher.ps1 and groups files by MD5 hash.
    Reports all files with duplicate hashes, sorted by frequency.

.PARAMETER CsvFile
    Path to CSV file from recursive_md5_hasher.ps1 (required)

.PARAMETER OutputFile
    Path to save duplicate report as CSV (optional)

.EXAMPLE
    .\find_duplicate_hashes.ps1 -CsvFile "hashes_20260327_120000.csv"
    
.EXAMPLE
    .\find_duplicate_hashes.ps1 -CsvFile "hashes_20260327_120000.csv" -OutputFile "duplicates_report.csv"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CsvFile,
    
    [string]$OutputFile
)

# Validate input file
if (-not (Test-Path -Path $CsvFile -PathType Leaf)) {
    Write-Host "Error: CSV file not found: $CsvFile" -ForegroundColor Red
    exit 1
}

Write-Host "Reading CSV file: $CsvFile" -ForegroundColor Cyan

# Read CSV and group by MD5 hash
$hashGroups = @{}
$errorCount = 0
$totalCount = 0

try {
    $csv = Import-Csv -Path $CsvFile
    
    foreach ($row in $csv) {
        $totalCount++
        
        # Skip rows with errors or missing hash
        if ([string]::IsNullOrEmpty($row.md5) -or -not [string]::IsNullOrEmpty($row.error)) {
            if (-not [string]::IsNullOrEmpty($row.error)) {
                $errorCount++
            }
            continue
        }
        
        # Group by MD5
        if (-not $hashGroups.ContainsKey($row.md5)) {
            $hashGroups[$row.md5] = @()
        }
        
        $hashGroups[$row.md5] += @{
            filepath = $row.filepath
            size = $row.size
            mtime = $row.mtime
        }
    }
}
catch {
    Write-Host "Error reading CSV: $_" -ForegroundColor Red
    exit 1
}

# Filter to only duplicates (2+ files with same hash)
$duplicates = @{}
foreach ($hash in $hashGroups.Keys) {
    if ($hashGroups[$hash].Count -gt 1) {
        $duplicates[$hash] = $hashGroups[$hash]
    }
}

# Report results
Write-Host ""
Write-Host "Results:" -ForegroundColor Green
Write-Host "  Total rows processed: $totalCount"
Write-Host "  Unique hashes: $($hashGroups.Count)"
Write-Host "  Duplicate hash groups: $($duplicates.Count)"
Write-Host "  Total duplicate files: $(($duplicates.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum)"
Write-Host "  Skipped (errors): $errorCount"
Write-Host ""

if ($duplicates.Count -eq 0) {
    Write-Host "No duplicates found!" -ForegroundColor Yellow
    exit 0
}

# Output duplicate details
$outputLines = @()
$outputLines += "MD5 Hash,File Count,Total Size,Files"

# Sort by count descending
$sortedDupes = $duplicates.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending

foreach ($item in $sortedDupes) {
    $md5Hash = $item.Key
    $files = $item.Value
    $fileCount = $files.Count
    
    # Calculate total size
    $totalSize = 0
    foreach ($file in $files) {
        if ([int64]::TryParse($file.size, [ref]$size)) {
            $totalSize += $size
        }
    }
    
    # Format size
    $sizeStr = ""
    if ($totalSize -gt 1GB) {
        $sizeStr = "{0:N2} GB" -f ($totalSize / 1GB)
    } elseif ($totalSize -gt 1MB) {
        $sizeStr = "{0:N2} MB" -f ($totalSize / 1MB)
    } else {
        $sizeStr = "{0:N2} KB" -f ($totalSize / 1KB)
    }
    
    # Console output
    Write-Host "Hash: $md5Hash" -ForegroundColor Yellow
    Write-Host "  Count: $fileCount files | Total size: $sizeStr"
    foreach ($file in $files) {
        Write-Host "    - $($file.filepath)"
    }
    Write-Host ""
    
    # CSV output
    $fileList = $files.filepath -join " | "
    $outputLines += "`"$md5Hash`",$fileCount,`"$sizeStr`",`"$fileList`""
}

# Save to file if specified
if ($OutputFile) {
    try {
        $outputLines | Out-File -FilePath $OutputFile -Encoding UTF8
        Write-Host "Duplicate report saved to: $(Resolve-Path $OutputFile)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error writing output file: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Analysis complete!" -ForegroundColor Green
