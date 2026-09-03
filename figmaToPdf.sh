#!/bin/bash

# Catch Ctrl+C (SIGINT) and exit immediately
trap "echo -e '\n[!] Process interrupted by user. Exiting...'; exit 1" SIGINT

usage() {
    echo "Usage: $0 -i <input_dir> -o <output_pdf> [-c <complexity_threshold>] [-p <ppi>] [-k]"
    echo "  -i : Directory containing matching Figma PNG and SVG exports"
    echo "  -o : Path/filename of the final PPI CMYK PDF output"
    echo "  -c : Path complexity threshold for text separation (default: 100)"
    echo "  -p : PPI density of resulting PDF (default: 300)"
    echo "  -k : Keep intermediate work_pipeline directory upon completion"
    exit 1
}

COMPLEXITY_THRESHOLD=100
PPI=300
KEEP_WORK=false
IGNORE_HEX="#123456"

# Parse CLI arguments (handling flags including optional -k)
while getopts "i:o:c:p:k" opt; do
    case $opt in
        i) INPUT_DIR="$OPTARG" ;;
        o) OUTPUT_PDF="$OPTARG" ;;
        c) COMPLEXITY_THRESHOLD="$OPTARG" ;;
        p) PPI="$OPTARG" ;;
        k) KEEP_WORK=true ;;
        *) usage ;;
    esac
done

if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_PDF" ]; then
    usage
fi

if [[ "$OUTPUT_PDF" != *.pdf ]]; then
    echo "[ERROR] Output file must have a .pdf extension."
    exit 1
fi

echo "================================================================="
echo " Starting Print-Ready CMYK PDF Compilation Pipeline"
echo " Timestamp: $(date)"
echo "================================================================="

UTILS_DIRECTORY="/Users/michaelpatashnik/Utilities"

# --- Step 0: Dependency Verification ---
echo -e "\n>> Step 0: Checking Environment & Script Availability..."

for cmd in magick python3 pdfimages; do
    if ! command -v $cmd &> /dev/null; then
        echo "[ERROR] Required dependency command '$cmd' is not installed."
        exit 1
    fi
done

if [ ! -f "$UTILS_DIRECTORY/create_pdf.py" ]; then
    echo "[ERROR] 'create_pdf.py' not found in $UTILS_DIRECTORY"
    exit 1
fi

python3 -m venv venv && source venv/bin/activate
pip install --upgrade pip &> /dev/null
pip install pypdf img2pdf natsort &> /dev/null

chmod +x "$UTILS_DIRECTORY/sliceSvg.sh" "$UTILS_DIRECTORY/ConvertImageColors.sh"

STAGE_DIR="work_pipeline"
SRC_PNG_DIR="$STAGE_DIR/0_source_pngs"
SLICED_SVG_DIR="$STAGE_DIR/1_sliced_svgs"
CONVERTED_TIFF_DIR="$STAGE_DIR/2_converted_tiffs"
VERIFY_DIR="$STAGE_DIR/verification"

rm -rf "$STAGE_DIR" "$VERIFY_DIR"
mkdir -p "$SRC_PNG_DIR" "$SLICED_SVG_DIR" "$CONVERTED_TIFF_DIR" "$VERIFY_DIR"

cp "$INPUT_DIR"/*.png "$SRC_PNG_DIR/" 2>/dev/null
PNG_COUNT=$(ls -1 "$SRC_PNG_DIR"/*.png 2>/dev/null | wc -l)

if [ "$PNG_COUNT" -eq 0 ]; then
    echo "[ERROR] No PNG files found in '$INPUT_DIR'. Exiting."
    rm -rf "$STAGE_DIR"
    exit 1
fi
echo "   -> Staged $PNG_COUNT design assets for batch processing."

# --- Step 1: Vector Complexity Slicing ---
echo -e "\n>> Step 1: Isolating Low-Complexity Art Paths via Slicing..."
$UTILS_DIRECTORY/sliceSvg.sh "$INPUT_DIR" '' "$SLICED_SVG_DIR" '_black_full' '#000000' 'none' 0
$UTILS_DIRECTORY/sliceSvg.sh "$SLICED_SVG_DIR" '_black_full' "$SLICED_SVG_DIR" '_black_split' '#000000' '#FF0000' "$COMPLEXITY_THRESHOLD"
$UTILS_DIRECTORY/sliceSvg.sh "$SLICED_SVG_DIR" '_black_split' "$SLICED_SVG_DIR" '_black_rich' '#000000' 'none' 0
$UTILS_DIRECTORY/sliceSvg.sh "$INPUT_DIR" '' "$SLICED_SVG_DIR" '_ignore_box' "$IGNORE_HEX" 'none' 0

if [ $? -ne 0 ]; then
    echo "[ERROR] Step 1 (sliceSvg.sh) failed."
    exit 1
fi

# --- Step 2: Advanced CMYK Channel Separation ---
echo -e "\n>> Step 2: Processing Images and Overprinting Black Plates..."
$UTILS_DIRECTORY/ConvertImageColors.sh "$SRC_PNG_DIR" "$CONVERTED_TIFF_DIR" "$SLICED_SVG_DIR" "$VERIFY_DIR"

if [ $? -ne 0 ]; then
    echo "[ERROR] Step 2 (ConvertImageColors.sh) failed."
    exit 1
fi

# --- Step 3: Lossless PPI PDF Assembly ---
echo -e "\n>> Step 3: Assembling Multi-Page PDF Stream at intended PPI..."
python3 "$UTILS_DIRECTORY/create_pdf.py" "$CONVERTED_TIFF_DIR/*_final.tiff" "$OUTPUT_PDF" --ppi $PPI

if [ $? -ne 0 ]; then
    echo "[ERROR] Step 3 (create_pdf.py) failed."
    exit 1
fi

# --- Step 4: Automated Preflight Stream Validation ---
echo -e "\n>> Step 4: Auditing Production Stream Resolution & Color Spaces..."
echo "------------------------------------------------------------------------------------------------------------------------"
pdfimages -list "$OUTPUT_PDF"
echo "------------------------------------------------------------------------------------------------------------------------"

IMAGE_DATA_ROWS=$(pdfimages -list "$OUTPUT_PDF" | grep -E '^[[:space:]]*[0-9]+')
NON_CMYK_ROWS=$(echo "$IMAGE_DATA_ROWS" | awk '{if (!($6 == "cmyk" || ($6 == "icc" && $7 == 4))) print}')
NON_PPI_ROWS=$(echo "$IMAGE_DATA_ROWS" | grep -vE "$PPI[[:space:]]+$PPI")

STATUS_PASS=true

if [ -n "$NON_CMYK_ROWS" ]; then
    echo -e "\n[COLOR SPACE CRITICAL WARNING] Embedded streams deviate from target profile:"
    echo "$NON_CMYK_ROWS"
    STATUS_PASS=false
else
    echo "  [PASS] Color Space Integrity: 100% CMYK/Tagged ICC verified."
fi

if [ -n "$NON_PPI_ROWS" ]; then
    echo -e "\n[RESOLUTION CRITICAL WARNING] Elements deviate from $PPI PPI print requirement:"
    echo "$NON_PPI_ROWS"
    STATUS_PASS=false
else
    echo "  [PASS] Resolution Density: 100% of elements match target $PPI PPI."
fi

# --- Step 5: Cleanup Workspace ---
if [ "$KEEP_WORK" = true ]; then
    echo -e "\n>> Step 5: Retaining intermediate work directory '$STAGE_DIR' (-k flag active)."
else
    echo -e "\n>> Step 5: Cleaning up intermediate pipeline workspace..."
    rm -rf "$STAGE_DIR"
fi

echo "================================================================="
if [ "$STATUS_PASS" = true ]; then
    echo " Pipeline Execution Successfully Complete!"
else
    echo " Pipeline Completed with warnings. Please check preflight logs above."
fi
echo " Output Production PDF: $OUTPUT_PDF"
echo " Verification Folder:   ./$VERIFY_DIR/"
echo "================================================================="
