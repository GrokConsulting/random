import json
import csv
import argparse
import os
from glob import glob

def flatten_json(y, parent_key='', sep='_'):
    items = []
    if isinstance(y, dict):
        for k, v in y.items():
            new_key = f"{parent_key}{sep}{k}" if parent_key else k
            items.extend(flatten_json(v, new_key, sep=sep).items())
    elif isinstance(y, list):
        for i, v in enumerate(y):
            new_key = f"{parent_key}{sep}{i}"
            items.extend(flatten_json(v, new_key, sep=sep).items())
    else:
        items.append((parent_key, y))
    return dict(items)


def load_files(input_paths):
    files = []
    for path in input_paths:
        if os.path.isdir(path):
            files.extend(glob(os.path.join(path, "*.json")))
        else:
            files.extend(glob(path))  # supports wildcards
    return files


def main():
    parser = argparse.ArgumentParser(description="Flatten JSON to single-row CSV")
    parser.add_argument("input", nargs="+", help="JSON file(s), folder(s), or wildcard(s)")
    parser.add_argument("-o", "--output", default="output.csv", help="Output CSV file")

    args = parser.parse_args()

    files = load_files(args.input)

    if not files:
        print("No JSON files found.")
        return

    all_rows = []

    for file in files:
        with open(file, "r") as f:
            data = json.load(f)

        flat = flatten_json(data)
        flat["source_file"] = os.path.basename(file)  # useful for batch tracking
        all_rows.append(flat)

    # Collect all possible headers across files
    headers = set()
    for row in all_rows:
        headers.update(row.keys())

    headers = sorted(headers)

    # Write CSV
    with open(args.output, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"CSV created: {args.output} ({len(all_rows)} rows)")


if __name__ == "__main__":
    main()
