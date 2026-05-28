#!/usr/bin/env bash
# Finds all image files >10KB recursively and copies them to /Volumes/Data/collected_images

DRIVE="/Volumes/Data"
DEST="$DRIVE/collected_images"
MIN_SIZE="+10k"

mkdir -p "$DEST"

echo "Scanning $DRIVE for image files over 10KB..."
echo "Destination: $DEST"
echo ""

count=0
skipped=0

while IFS= read -r -d '' file; do
    filename=$(basename "$file")
    dest_file="$DEST/$filename"

    # If a file with this name already exists, append a counter
    if [[ -e "$dest_file" ]]; then
        base="${filename%.*}"
        ext="${filename##*.}"
        if [[ "$base" == "$filename" ]]; then
            # No extension
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

    # Print progress every 100 files
    if (( count % 100 == 0 && count > 0 )); then
        echo "  Copied $count files so far..."
    fi

done < <(find "$DRIVE" \
    -path "$DEST" -prune -o \
    -type f \
    -size "$MIN_SIZE" \
    \( \
        -iname "*.jpg"  -o -iname "*.jpeg" -o \
        -iname "*.png"  -o -iname "*.gif"  -o \
        -iname "*.bmp"  -o -iname "*.tiff" -o \
        -iname "*.tif"  -o -iname "*.webp" -o \
        -iname "*.heic" -o -iname "*.heif" -o \
        -iname "*.raw"  -o -iname "*.cr2"  -o \
        -iname "*.cr3"  -o -iname "*.nef"  -o \
        -iname "*.arw"  -o -iname "*.dng"  -o \
        -iname "*.orf"  -o -iname "*.rw2"  -o \
        -iname "*.psd"  -o -iname "*.svg"  \
    \) \
    -print0)

echo ""
echo "Done. Copied: $count  |  Failed: $skipped"
echo "Images are in: $DEST"
