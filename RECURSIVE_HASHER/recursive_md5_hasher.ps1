<#
.SYNOPSIS
    Recursively hash all files in a folder with MD5, processing in chunks.
    Handles large directories (10M+ files) with progress tracking and batch output.

.DESCRIPTION
    Efficiently hashes files using MD5 with chunked processing and parallel job execution.
    Outputs results to CSV format: filepath, md5hash, filesize, mtime

.PARAMETER Path
    Root directory to hash

.PARAMETER OutputFile
    Output CSV file (default: hashes_TIMESTAMP.csv)

.PARAMETER ChunkSize
    Files per batch (default: 1000)

.PARAMETER Workers
    Parallel jobs (default: 4)

.PARAMETER SkipSymlinks
    Skip symbolic links (default: follow them)

.PARAMETER Filter
    File pattern filter (e.g., "*.txt")

.EXAMPLE
    .\recursive_md5_hasher.ps1 -Path "C:\data\files"
    Hashes all files, outputs to hashes_20260326_170100.csv

.EXAMPLE
    .\recursive_md5_hasher.ps1 -Path "C:\data\files" -ChunkSize 2000 -Workers 8 -OutputFile "my_hashes.csv"
    Uses 2000 files per batch and 8 parallel workers

.EXAMPLE
    .\recursive_md5_hasher.ps1 -Path "C:\data\files" -Filter "*.jpg"
    Only hashes JPEG files
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    
    [string]$OutputFile,
    
    [int]$ChunkSize = 1000,
    
    [int]$Workers = 4,
    
    [switch]$SkipSymlinks,
    
    [string]$Filter = "*"
)

# Validate path
if (-not (Test-Path -Path $Path -PathType Container)) {
    Write-Host "Error: Directory not found: $Path" -ForegroundColor Red
    exit 1
}

# Set default output file
if (-not $OutputFile) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputFile = "hashes_$timestamp.csv"
}

# Script block for hashing a single file
$hashFileScript = {
    param([string]$FilePath)
    
    try {
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $fileStream = [System.IO.File]::OpenRead($FilePath)
        $hash = $md5.ComputeHash($fileStream)
        $fileStream.Close()
        $hashHex = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
        
        $file = Get-Item -Path $FilePath
        $mtime = [datetime]::new(1970,1,1,0,0,0) + [timespan]::fromseconds(($file.LastWriteTime - [datetime]::new(1970,1,1)).TotalSeconds)
        
        [PSCustomObject]@{
            filepath = $FilePath
            md5 = $hashHex
            size = $file.Length
            mtime = ($file.LastWriteTime - [datetime]::new(1970,1,1)).TotalSeconds
            error = ""
        }
    }
    catch {
        [PSCustomObject]@{
            filepath = $FilePath
            md5 = ""
            size = ""
            mtime = ""
            error = $_.Exception.Message
        }
    }
}

Write-Host "Starting file hash operation" -ForegroundColor Green
Write-Host "Root directory: $Path"
Write-Host "Output file: $OutputFile"
Write-Host "Chunk size: $ChunkSize"
Write-Host "Workers: $Workers"
Write-Host ""

# Initialize CSV file with headers
$csvHeaders = "filepath,md5,size,mtime,error"
$csvHeaders | Out-File -FilePath $OutputFile -Encoding UTF8

# Get all files recursively
Write-Host "Scanning directory..." -ForegroundColor Cyan
$startScan = Get-Date

$allFiles = @()
if ($SkipSymlinks) {
    $allFiles = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { -not ((Get-Item -Path $_.FullName -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) }
} else {
    $allFiles = Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue
}

# Apply filter
if ($Filter -ne "*") {
    $allFiles = $allFiles | Where-Object { $_.Name -like $Filter }
}

$scanTime = (Get-Date) - $startScan
Write-Host "Found $($allFiles.Count) files (scan time: $([Math]::Round($scanTime.TotalSeconds, 1))s)" -ForegroundColor Cyan
Write-Host ""

# Process files in chunks
$startTime = Get-Date
$processedCount = 0
$errorCount = 0
$chunkNum = 0

for ($i = 0; $i -lt $allFiles.Count; $i += $ChunkSize) {
    $chunkNum++
    $chunk = $allFiles[$i..([Math]::Min($i + $ChunkSize - 1, $allFiles.Count - 1))]
    $chunkStartTime = Get-Date
    
    Write-Host "Processing chunk $chunkNum ($($chunk.Count) files)... " -NoNewline -ForegroundColor Yellow
    
    # Process chunk with parallel jobs
    $results = @()
    
    if ($Workers -eq 1) {
        # Single-threaded mode
        $results = $chunk | ForEach-Object { & $hashFileScript -FilePath $_.FullName }
    } else {
        # Multi-threaded mode using parallel foreach (PowerShell 7+) or sequential jobs
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $results = $chunk | ForEach-Object -Parallel {
                $hashFileScript = $using:hashFileScript
                & $hashFileScript -FilePath $_.FullName
            } -ThrottleLimit $Workers
        } else {
            # PowerShell 5.1 fallback: process with controlled concurrency
            $jobs = @()
            foreach ($file in $chunk) {
                $job = Start-Job -ScriptBlock $hashFileScript -ArgumentList $file.FullName
                $jobs += $job
                
                # Throttle: limit concurrent jobs
                while ((Get-Job -State Running).Count -ge $Workers) {
                    Start-Sleep -Milliseconds 100
                }
            }
            
            # Wait for remaining jobs
            $results = Get-Job -Id $jobs.Id | Wait-Job | Receive-Job
            Remove-Job -Id $jobs.Id
        }
    }
    
    # Write results to CSV
    foreach ($result in $results) {
        $csvLine = "$($result.filepath),$($result.md5),$($result.size),$($result.mtime),$($result.error)"
        $csvLine | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
        
        if ([string]::IsNullOrEmpty($result.error)) {
            $processedCount++
        } else {
            $errorCount++
        }
    }
    
    # Calculate rate
    $chunkTime = (Get-Date) - $chunkStartTime
    $rate = if ($chunkTime.TotalSeconds -gt 0) { [Math]::Round($chunk.Count / $chunkTime.TotalSeconds) } else { 0 }
    
    Write-Host "✓ $rate files/sec" -ForegroundColor Green
}

# Print summary
$totalTime = (Get-Date) - $startTime
$totalRate = if ($totalTime.TotalSeconds -gt 0) { [Math]::Round($processedCount / $totalTime.TotalSeconds) } else { 0 }

Write-Host ""
Write-Host ("=" * 70)
Write-Host "Processing complete!" -ForegroundColor Green
Write-Host "Total files hashed: $processedCount"
Write-Host "Errors: $errorCount"
Write-Host "Time elapsed: $([Math]::Round($totalTime.TotalSeconds, 1))s"
Write-Host "Rate: $totalRate files/sec"
Write-Host "Output file: $OutputFile"
Write-Host ("=" * 70)

# Calculate total data size
$totalSize = 0
$csv = Import-Csv -Path $OutputFile
foreach ($row in $csv) {
    if ([int64]::TryParse($row.size, [ref]$size)) {
        $totalSize += $size
    }
}

if ($totalSize -gt 0) {
    $sizeGB = [Math]::Round($totalSize / 1GB, 2)
    Write-Host "Total data size: $sizeGB GB"
}

Write-Host ""
Write-Host "Log file locations:" -ForegroundColor Cyan
Write-Host "  CSV output: $(Resolve-Path $OutputFile)"
