#!/bin/bash

# Find duplicate files by MD5 hash from recursive_md5_hasher output CSV.
# Groups files by MD5 hash and reports all duplicates.
#
# Usage:
#   ./find_duplicate_hashes.sh hashes_20260327_120000.csv [output_file.csv]

set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Validate arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <csv_file> [output_file]"
    echo ""
    echo "Arguments:"
    echo "  csv_file   - Path to CSV output from recursive_md5_hasher.sh/py"
    echo "  output_file - (Optional) CSV file to write duplicate report"
    echo ""
    echo "Example:"
    echo "  $0 hashes_20260327_120000.csv duplicates.csv"
    exit 1
fi

CSV_FILE="$1"
OUTPUT_FILE="${2:-}"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: CSV file not found: $CSV_FILE${NC}"
    exit 1
fi

echo -e "${CYAN}Reading CSV file: $CSV_FILE${NC}"

# Use awk to process the CSV and group by MD5
# Create temporary files for intermediate results
TEMP_DIR=$(mktemp -d)
HASH_FILE="$TEMP_DIR/hashes.txt"
SORTED_FILE="$TEMP_DIR/sorted.txt"
DUPLICATES_FILE="$TEMP_DIR/duplicates.txt"

trap "rm -rf $TEMP_DIR" EXIT

# Extract hash and filepath from CSV, skipping header and error rows
# Format: hash|filepath|size|mtime
awk -F',' '
NR > 1 && $2 != "" && $5 == "" {
    # Skip header, empty hashes, and error rows
    print $2 "|" $1 "|" $3 "|" $4
}
' "$CSV_FILE" > "$HASH_FILE"

# Count occurrences of each hash
awk -F'|' '
{
    hashes[$1]++
    files[$1] = (files[$1] ? files[$1] "|" : "") $2
    sizes[$1] = (sizes[$1] ? sizes[$1] "|" : "") $3
}
END {
    for (hash in hashes) {
        if (hashes[hash] > 1) {
            print hashes[hash] "|" hash "|" files[hash] "|" sizes[hash]
        }
    }
}
' "$HASH_FILE" | sort -t'|' -k1 -rn > "$DUPLICATES_FILE"

# Count statistics
TOTAL_HASHES=$(awk -F'|' '{print $2}' "$HASH_FILE" | sort -u | wc -l)
ERROR_COUNT=$(awk -F',' 'NR > 1 && $5 != "" {count++} END {print count+0}' "$CSV_FILE")
TOTAL_ROWS=$(($(wc -l < "$HASH_FILE") + ERROR_COUNT + 1))
DUP_COUNT=$(wc -l < "$DUPLICATES_FILE")
DUP_FILES=$(awk -F'|' '{sum += $1} END {print sum+0}' "$DUPLICATES_FILE")

echo ""
echo -e "${GREEN}Results:${NC}"
echo "  Total rows processed: $TOTAL_ROWS"
echo "  Unique hashes: $TOTAL_HASHES"
echo "  Duplicate hash groups: $DUP_COUNT"
echo "  Total duplicate files: $DUP_FILES"
echo "  Skipped (errors): $ERROR_COUNT"
echo ""

if [ "$DUP_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No duplicates found!${NC}"
    exit 0
fi

# Function to format bytes to human-readable
format_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "scale=2; $bytes / 1073741824" | bc -l | sed 's/$/\n/' | tr -d '\n' | awk '{printf "%.2f GB", $0}'
    elif [ "$bytes" -ge 1048576 ]; then
        echo "scale=2; $bytes / 1048576" | bc -l | sed 's/$/\n/' | tr -d '\n' | awk '{printf "%.2f MB", $0}'
    else
        echo "scale=2; $bytes / 1024" | bc -l | sed 's/$/\n/' | tr -d '\n' | awk '{printf "%.2f KB", $0}'
    fi
}

# Output duplicate details
OUTPUT_LINES=()
OUTPUT_LINES+=("MD5 Hash,File Count,Total Size,Files")

while IFS='|' read -r count hash files sizes; do
    # Calculate total size
    total_size=0
    IFS='|' read -ra SIZE_ARRAY <<< "$sizes"
    for size in "${SIZE_ARRAY[@]}"; do
        if [[ "$size" =~ ^[0-9]+$ ]]; then
            total_size=$((total_size + size))
        fi
    done
    
    # Format size
    if command -v numfmt &> /dev/null; then
        size_str=$(numfmt --to=iec-i --suffix=B "$total_size" 2>/dev/null || echo "$total_size B")
    else
        # Fallback if numfmt not available
        if [ "$total_size" -ge 1073741824 ]; then
            size_str=$(printf "%.2f GB" "$(echo "scale=2; $total_size / 1073741824" | bc -l)")
        elif [ "$total_size" -ge 1048576 ]; then
            size_str=$(printf "%.2f MB" "$(echo "scale=2; $total_size / 1048576" | bc -l)")
        else
            size_str=$(printf "%.2f KB" "$(echo "scale=2; $total_size / 1024" | bc -l)")
        fi
    fi
    
    # Console output
    echo -e "${YELLOW}Hash: $hash${NC}"
    echo "  Count: $count files | Total size: $size_str"
    
    IFS='|' read -ra FILE_ARRAY <<< "$files"
    for filepath in "${FILE_ARRAY[@]}"; do
        echo "    - $filepath"
    done
    echo ""
    
    # CSV output
    OUTPUT_LINES+=("\"$hash\",$count,\"$size_str\",\"$files\"")
    
done < "$DUPLICATES_FILE"

# Save to file if specified
if [ -n "$OUTPUT_FILE" ]; then
    {
        printf '%s\n' "${OUTPUT_LINES[@]}"
    } > "$OUTPUT_FILE"
    echo -e "${GREEN}Duplicate report saved to: $(cd "$(dirname "$OUTPUT_FILE")" && pwd)/$(basename "$OUTPUT_FILE")${NC}"
fi

echo ""
echo -e "${GREEN}Analysis complete!${NC}"
