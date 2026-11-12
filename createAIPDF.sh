#!/bin/bash

# Usage: ./batch_process.sh <input_dir> <output_dir> <template_ai_path>
INPUT_DIR=$(realpath "$1")
OUTPUT_DIR=$(realpath "$2")
TEMPLATE_PATH=$(realpath "$3")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_JSX="$SCRIPT_DIR/CombineLayersToPdf.jsx"
TEMP_JSX="${CORE_JSX}_tmp.jsx"

# 2. Open the template in Illustrator
osascript -e "tell application \"Adobe Illustrator\" to open POSIX file \"$TEMPLATE_PATH\""

# 3. Loop through files based on the cmyk naming convention
# This grabs "foo_final", strips the extension, then strips "_final" to get just "foo"
filenames=$(find "$INPUT_DIR" -maxdepth 1 -name "*final.tif*" | xargs -n 1 basename | sed 's/\.[^.]*$//' | sed 's/_final$//' | sort -u)

for foo in $filenames; do
    echo "Processing: $(basename $INPUT_DIR)/$foo"
    
    # Construct paths based on your specific naming rules
    # TIFF: foo_final.tiff (or .tif)
    TIFF_P="$INPUT_DIR/${foo}_final.tiff"
    if [ ! -f "$TIFF_P" ]; then TIFF_P="$INPUT_DIR/${foo}_final.tif"; fi
    
    W=$(sips -g pixelWidth "$TIFF_P" | awk '/pixelWidth/ {print $2}')
    H=$(sips -g pixelHeight "$TIFF_P" | awk '/pixelHeight/ {print $2}')

    # SVG: foo_green.svg
    SVG_P="$INPUT_DIR/${foo}_green.svg"
    
    # PDF: foo.pdf
    PDF_P="$OUTPUT_DIR/$foo.pdf"

    if [[ "${TIFF_P}" =~ .*ActionBack.* ]]; then
        allowSpecialSvgPlacement=true
    else
        allowSpecialSvgPlacement=false
    fi

    # Verify both source files exist before running the script
    if [[ -f "$TIFF_P" && -f "$SVG_P" ]]; then
        echo "(function() {" > "$TEMP_JSX";
        cat "$CORE_JSX" >> "$TEMP_JSX"      

        # Create the Temp JSX file
        cat <<EOF >> "$TEMP_JSX"

main("${TEMPLATE_PATH}",
    $W, $H, 
    "${TIFF_P}", 
    "${SVG_P}", 
    "${PDF_P}",
    $allowSpecialSvgPlacement);
})();
EOF

        # Execute in Illustrator
        osascript -e "tell application \"Adobe Illustrator\" to do javascript POSIX file \"$TEMP_JSX\""

        # Cleanup
        rm "$TEMP_JSX"
    else
        echo "Skip: Missing pair for $foo (Expected ${foo}_final.tiff and $foo.svg)"
    fi
done

echo "Done."
