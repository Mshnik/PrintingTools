#!/bin/bash

# Default values
REVERSE=false
NATURAL=false
INPUT_DIR=""
OUTPUT_DIR=""

usage() {
    echo "Usage: $0 -i <input_dir> -o <output_dir> [-r] [-n] \"regex1:count\" \"regex2:count\" ..."
    echo "  -i : Input directory"
    echo "  -o : Output directory"
    echo "  -r : Reverse sorting order"
    echo "  -n : Natural/Numerical sort (e.g., file-2 before file-10)"
    exit 1
}

# Parse flags
while getopts "i:o:rn" opt; do
    case $opt in
        i) INPUT_DIR=$OPTARG ;;
        o) OUTPUT_DIR=$OPTARG ;;
        r) REVERSE=true ;;
        n) NATURAL=true ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ]; then usage; fi

# Function to handle sorting (Mac-compatible natural sort via Python)
smart_sort() {
    local rev_flag="False"
    [ "$REVERSE" = true ] && rev_flag="True"

    if [ "$NATURAL" = true ]; then
        # Fixed the \d escape sequence by using r'' (raw string)
        python3 -c "import sys, re; 
def natsort(s): return [int(t) if t.isdigit() else t.lower() for t in re.split(r'(\d+)', s)];
lines = sys.stdin.readlines();
lines.sort(key=natsort, reverse=$rev_flag);
print(''.join(lines), end='')"
    else
        if [ "$REVERSE" = true ]; then sort -r; else sort; fi
    fi
}

# Setup temp files using macOS compatible mktemp
TMP_ALL_STEMS=$(mktemp -t stems.XXXXXX)
TMP_BUCKET=$(mktemp -t bucket.XXXXXX)
TMP_MATCHED=$(mktemp -t matched.XXXXXX)

# Ensure absolute paths
ABS_IN=$(cd "$INPUT_DIR" && pwd)
mkdir -p "$OUTPUT_DIR"
ABS_OUT=$(cd "$OUTPUT_DIR" && pwd)

# 1. Gather all unique file stems (ignoring hidden files)
find "$ABS_IN" -type f ! -name ".*" | sed 's/_subtracted//' | sed 's/\.[^.]*$//' | sort -u > "$TMP_ALL_STEMS"

process_stem() {
    local stem_path="$1"
    local copies="$2"
    local current_counter="$3"

    local rel_stem="${stem_path#$ABS_IN/}"
    local rel_dir=$(dirname "$rel_stem")
    local base_name=$(basename "$rel_stem")
    local target_subdir="$ABS_OUT/$rel_dir"
    
    mkdir -p "$target_subdir"

    for ((i=0; i<copies; i++)); do
        local prefix=$(printf "%03d" "$current_counter")
        
        # Find all extensions for this stem
        local dir_of_file=$(dirname "$stem_path")
        local raw_base_name=$(basename "$stem_path")
        
        find "$dir_of_file" -maxdepth 1 -type f \( -name "$raw_base_name.*" -o -name "${raw_base_name}_subtracted.*" \) | while read -r actual_file; do
            local ext="${actual_file##*.}"
            local subtracted=""
            if [[ "$actual_file" =~ _subtracted ]]; then
                subtracted="_subtracted"
            fi
            cp "$actual_file" "$target_subdir/${prefix}${subtracted}.${ext}"
        done
        ((current_counter++))
    done
    echo "$current_counter"
}

# 2. Main Logic
global_counter=1

# Process each regex
for arg in "$@"; do
    regex=""
    num_copies=1

    if [[ "$arg" == *":"* ]]; then
        regex="${arg%:*}"
        num_copies="${arg##*:}"
    else
        regex="$arg"
    fi

    # Populate bucket: filter regex, exclude already matched, and sort
    # We use -E for extended regex and -a to treat input as text
    grep -E "$regex" "$TMP_ALL_STEMS" | grep -vFf "$TMP_MATCHED" | smart_sort > "$TMP_BUCKET"
    
    while read -r stem; do
        if [ -n "$stem" ]; then
            global_counter=$(process_stem "$stem" "$num_copies" "$global_counter")
            echo "$stem" >> "$TMP_MATCHED"
        fi
    done < "$TMP_BUCKET"
done

# 3. Final bucket (unmatched files)
grep -vFf "$TMP_MATCHED" "$TMP_ALL_STEMS" | smart_sort > "$TMP_BUCKET"
while read -r stem; do
    if [ -n "$stem" ]; then
        global_counter=$(process_stem "$stem" 1 "$global_counter")
    fi
done < "$TMP_BUCKET"

# Cleanup
rm "$TMP_ALL_STEMS" "$TMP_BUCKET" "$TMP_MATCHED"
echo "Done! Processed $((global_counter-1)) total files/slots."
