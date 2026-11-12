#!/bin/bash

# Configuration paths
TEST_DIR="Test"
INPUT_DIR="$TEST_DIR/Input"
GOLDEN_PDF="$TEST_DIR/GoldenOutput.pdf"
TEST_OUTPUT_DIR="$TEST_DIR/output_actual"
ACTUAL_PDF="$TEST_OUTPUT_DIR/ConversionTest_output.pdf"
MAIN_SCRIPT="./figmaToPdf.sh"

UPDATE_GOLDEN=false

# Cleanup function to remove temporary test artifacts
cleanup() {
    echo -e "\n-> Cleaning up test workspace ($TEST_OUTPUT_DIR)..."
    rm -rf "$TEST_OUTPUT_DIR"
}

# Trap exits, errors, and interruptions (Ctrl+C) to guarantee cleanup runs
trap cleanup EXIT INT TERM

# Initial cleanup at the start in case a previous run was aborted midway
if [ -d "$TEST_OUTPUT_DIR" ]; then
    echo "-> Pre-run cleanup: Removing stale test outputs..."
    rm -rf "$TEST_OUTPUT_DIR"
fi

# Parse arguments
for arg in "$@"; do
    case $arg in
        --update)
            UPDATE_GOLDEN=true
            shift
            ;;
    esac
done

echo "================================================================="
echo " Starting PrintingTools Test Suite"
echo "================================================================="

# 1. Ensure dependencies / script exist
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo "[ERROR] Main script '$MAIN_SCRIPT' not found in root directory."
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "[ERROR] Test input directory '$INPUT_DIR' not found."
    exit 1
fi

# 2. Set up clean actual output directory
mkdir -p "$TEST_OUTPUT_DIR"

echo "-> Running main pipeline on test inputs..."
$MAIN_SCRIPT -i "$INPUT_DIR" -o "$ACTUAL_PDF" -p 300 -c 100

if [ ! -f "$ACTUAL_PDF" ]; then
    echo "[ERROR] Pipeline completed, but expected output PDF was not generated at '$ACTUAL_PDF'."
    exit 1
fi

# 3. Handle Golden Output update mode if requested
if [ "$UPDATE_GOLDEN" = true ]; then
    echo "-> [--update flag detected] Overwriting GoldenOutput.pdf with current actual output..."
    cp "$ACTUAL_PDF" "$GOLDEN_PDF"
    echo "-> Golden output successfully updated."
    exit 0
fi

if [ ! -f "$GOLDEN_PDF" ]; then
    echo "[ERROR] No golden output found at '$GOLDEN_PDF'."
    echo "        Run the test with '--update' to establish the initial baseline golden file."
    exit 1
fi

echo "-> Performing validation checks against GoldenOutput.pdf..."

# --- Validation Checks ---
TEST_PASSED=true

# Check A: Page Count Match
PAGE_COUNT_GOLDEN=$(pdfinfo "$GOLDEN_PDF" | grep "Pages:" | awk '{print $2}')
PAGE_COUNT_ACTUAL=$(pdfinfo "$ACTUAL_PDF" | grep "Pages:" | awk '{print $2}')

if [ "$PAGE_COUNT_GOLDEN" -ne "$PAGE_COUNT_ACTUAL" ]; then
    echo "  [FAIL] Page count mismatch! Expected: $PAGE_COUNT_GOLDEN, Got: $PAGE_COUNT_ACTUAL"
    TEST_PASSED=false
else
    echo "  [PASS] Page count matches ($PAGE_COUNT_ACTUAL pages)."
fi

# Check B: Image / Stream Configuration (pdfimages inspection)
GOLDEN_IMAGE_COUNT=$(pdfimages -list "$GOLDEN_PDF" | tail -n +3 | grep -E '^[[:space:]]*[0-9]+' | wc -l)
ACTUAL_IMAGE_COUNT=$(pdfimages -list "$ACTUAL_PDF" | tail -n +3 | grep -E '^[[:space:]]*[0-9]+' | wc -l)

if [ "$GOLDEN_IMAGE_COUNT" -ne "$ACTUAL_IMAGE_COUNT" ]; then
    echo "  [FAIL] Embedded image/plate stream count mismatch! Expected: $GOLDEN_IMAGE_COUNT, Got: $ACTUAL_IMAGE_COUNT"
    TEST_PASSED=false
else
    echo "  [PASS] Stream element count matches ($ACTUAL_IMAGE_COUNT streams)."
fi

# Check C: Color Space Integrity
NON_CMYK_ACTUAL=$(pdfimages -list "$ACTUAL_PDF" | tail -n +3 | awk '{if (!($6 == "cmyk" || ($6 == "icc" && $7 == 4))) print}')
if [ -n "$NON_CMYK_ACTUAL" ]; then
    echo "  [FAIL] Actual output contains non-CMYK streams."
    TEST_PASSED=false
else
    echo "  [PASS] 100% CMYK color space integrity verified on output streams."
fi

echo "================================================================="
if [ "$TEST_PASSED" = true ]; then
    echo " ALL TESTS PASSED SUCCESSFULLY!"
    echo "================================================================="
    exit 0
else
    echo " TEST SUITE FAILED. Review discrepancies above."
    echo "================================================================="
    exit 1
fi
