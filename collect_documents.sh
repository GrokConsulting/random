#!/usr/bin/env bash
# Finds all Word/Excel/PowerPoint files >10KB recursively and copies to /Volumes/Data/collected_documents

DRIVE="/Volumes/Data"
DEST="$DRIVE/collected_documents"
mkdir -p "$DEST"

echo "Scanning $DRIVE for Office documents (all sizes)..."
echo "Destination: $DEST"
echo ""

count=0
skipped=0

while IFS= read -r -d '' file; do
    filename=$(basename "$file")
    dest_file="$DEST/$filename"

    if [[ -e "$dest_file" ]]; then
        base="${filename%.*}"
        ext="${filename##*.}"
        if [[ "$base" == "$filename" ]]; then
            n=1
            while [[ -e "$DEST/${base}_${n}" ]]; do (( n++ )); done
            dest_file="$DEST/${base}_${n}"
        else
            n=1
            while [[ -e "$DEST/${base}_${n}.${ext}" ]]; do (( n++ )); done
            dest_file="$DEST/${base}_${n}.${ext}"
        fi
    fi

    cp "$file" "$dest_file" && (( count++ )) || (( skipped++ ))

    if (( count % 100 == 0 && count > 0 )); then
        echo "  Copied $count files so far..."
    fi

done < <(find "$DRIVE" \
    -path "$DEST" -prune -o \
    -path "$DRIVE/collected_images" -prune -o \
    -type f \
    \( \
        -iname "*.doc"  -o -iname "*.docx" -o \
        -iname "*.xls"  -o -iname "*.xlsx" -o \
        -iname "*.ppt"  -o -iname "*.pptx" \
    \) \
    -print0)

echo ""
echo "Done. Copied: $count  |  Failed: $skipped"
echo "Documents are in: $DEST"
