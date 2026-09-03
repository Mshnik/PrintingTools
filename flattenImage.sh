#!/bin/bash

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_directory> <output_directory>"
    exit 1
fi

# Convert to absolute paths to avoid issues with relative path navigation
INPUT_DIR=$(cd "$1" && pwd)
OUTPUT_DIR=$(mkdir -p "$2" && cd "$2" && pwd)

# Find all .tiff files in subdirectories
find "$INPUT_DIR" -type f -name "*cmyk.tiff" | while read -r tiff_file; do
    
    # Get the directory containing the current png
    current_subdir=$(dirname "$tiff_file")
    
    # Calculate the relative path from the INPUT_DIR
    # This turns /Users/me/in/folder1/file.png into folder1
    relative_path="${current_subdir#$INPUT_DIR/}"
    
    # If the file is in the root of INPUT_DIR, relative_path might equal INPUT_DIR
    # We check to make sure we don't create a loop
    if [ "$relative_path" == "$INPUT_DIR" ]; then relative_path="."; fi

    # Define the target directory and create it
    target_dir="$OUTPUT_DIR/$relative_path"
    mkdir -p "$target_dir"

    # Get the base name (without extension)
    base_path="${tiff_file%_cmyk.*}"
    svg_file="${base_path}.svg"
    
    # Check if the matching .svg exists
    if [ -f "$svg_file" ]; then
        filename=$(basename "$base_path")
        output_file="$target_dir/${filename}_flat.tiff"
        mask_file="$target_dir/${filename}_mask.tiff"
        
        echo "Processing: $relative_path/$filename"

        # Write finished file.
        magick -background None "$svg_file" \
            -fill "#FF00FF" +opaque none \
            -resize $(identify -format %wx%h "$tiff_file") \
            "$mask_file"

        magick composite \
          "$mask_file" "$tiff_file" \
          -quality 100 \
          -compress ZIP \
          "$output_file"

        # remove mask file.
        rm "$mask_file"
    else
        echo "Warning: No matching SVG found for $tiff_file"
    fi
done

echo "Done! Results are in $OUTPUT_DIR"
