#!/bin/bash

IN="$1"
OUT="$2"
BLACK_MASK_IN="$3"
VERIFY="$4"

CMYK_PROFILE="/Library/Application Support/Adobe/Color/Profiles/Recommended/CoatedGRACoL2006.icc"
SRGB_PROFILE="/System/Library/ColorSync/Profiles/sRGB Profile.icc"

mkdir -p "$OUT" "$VERIFY"

makeIntermediateColor() {
    local INPUT="$1"
    local OUTPUT="$2"

    # Base CMYK Profile Conversion (Handles full-color elements)
    magick "$INPUT" \
        -profile "$SRGB_PROFILE" \
        -strip \
        -profile "$SRGB_PROFILE" \
        -intent Perceptual \
        -profile "$CMYK_PROFILE" \
        -sampling-factor 4:4:4 \
        -quality 100 \
        -compress LZW \
        "$OUTPUT"
}

makeRasterMask() {
    local SVG_INPUT="$1"
    local REF_IMG="$2"
    local MASK_OUT="$3"
    magick -background none "$SVG_INPUT" \
            -resize $(identify -format %wx%h "$REF_IMG")\! \
            -alpha extract \
            "$MASK_OUT"
}

makeNonBlackTopMask() {
    local INPUT_PNG="$1"
    local MASK_OUT="$2"
    
    magick "$INPUT_PNG" \
        -fuzz 2% -fill white +opaque "#000000" \
        -fill black -opaque "#000000" \
        "$MASK_OUT"
}

makeVectorPlate() {
    local BASE_CMYK="$1"
    local SVG_MASK="$2"
    local NON_BLACK_MASK="$3"
    local IGNORE_MASK="$4"
    local COLOR_FORMULA="$5"
    local OUTPUT_LAYER="$6"

    local TEMP_FINAL_MASK="${OUTPUT_LAYER%.*}_final_mask.png"

    if [ -f "$IGNORE_MASK" ]; then
        magick "$SVG_MASK" \( "$NON_BLACK_MASK" -negate \) -compose Multiply -composite \
               \( "$IGNORE_MASK" -negate \) -compose Multiply -composite \
               "$TEMP_FINAL_MASK"
    else
        magick "$SVG_MASK" \( "$NON_BLACK_MASK" -negate \) -compose Multiply -composite "$TEMP_FINAL_MASK"
    fi

    magick -size $(identify -format %wx%h "$BASE_CMYK") canvas:"$COLOR_FORMULA" \
        "$TEMP_FINAL_MASK" -alpha off -compose CopyOpacity -composite \
        -sampling-factor 4:4:4 \
        -quality 100 \
        -compress LZW \
        "$OUTPUT_LAYER"

    rm -f "$TEMP_FINAL_MASK"
}

flattenLayers() {
    local BASE_COLOR="$1"
    local PLAIN_BLACK="$2"
    local RICH_BLACK="$3"
    local OUTPUT="$4"
    
    magick "$BASE_COLOR" "$PLAIN_BLACK" "$RICH_BLACK" \
        -layers flatten \
        -alpha remove -alpha off \
        -sampling-factor 4:4:4 \
        -quality 100 \
        -compress LZW \
        "$OUTPUT"
}

makeCMYK() {
    local INPUT="$1"
    local MASK_PLAIN_SVG="$2"
    local MASK_RICH_SVG="$3"
    local OUTPUT="$4"
    local MASK_IGNORE_SVG="$5"

    local TEMP_COLOR="${OUTPUT%.*}_color.tiff"
    local TEMP_MASK_RICH_SVG="${OUTPUT%.*}_mask_rich_svg.png"
    local TEMP_MASK_PLAIN_SVG="${OUTPUT%.*}_mask_plain_svg.png"
    local TEMP_MASK_IGNORE_SVG="${OUTPUT%.*}_mask_ignore_svg.png"
    local TEMP_MASK_NON_BLACK="${OUTPUT%.*}_mask_non_black.png"

    local TEMP_PLAIN_BLACK="${OUTPUT%.*}_plain_black.tiff"
    local TEMP_RICH_BLACK="${OUTPUT%.*}_rich_black.tiff"

    makeIntermediateColor "$INPUT" "$TEMP_COLOR"
    
    makeRasterMask "$MASK_RICH_SVG" "$TEMP_COLOR" "$TEMP_MASK_RICH_SVG"
    makeRasterMask "$MASK_PLAIN_SVG" "$TEMP_COLOR" "$TEMP_MASK_PLAIN_SVG"
    makeNonBlackTopMask "$INPUT" "$TEMP_MASK_NON_BLACK"

    if [ -f "$MASK_IGNORE_SVG" ]; then
        makeRasterMask "$MASK_IGNORE_SVG" "$TEMP_COLOR" "$TEMP_MASK_IGNORE_SVG"
    fi

    makeVectorPlate "$TEMP_COLOR" "$TEMP_MASK_PLAIN_SVG" "$TEMP_MASK_NON_BLACK" "$TEMP_MASK_IGNORE_SVG" "cmyk(0%,0%,0%,100%)" "$TEMP_PLAIN_BLACK"
    makeVectorPlate "$TEMP_COLOR" "$TEMP_MASK_RICH_SVG" "$TEMP_MASK_NON_BLACK" "$TEMP_MASK_IGNORE_SVG" "cmyk(40%,0%,0%,100%)" "$TEMP_RICH_BLACK"

    flattenLayers "$TEMP_COLOR" "$TEMP_PLAIN_BLACK" "$TEMP_RICH_BLACK" "$OUTPUT"

    local PAGE_NAME=$(basename "${OUTPUT%.*}")
    for ch in C M Y K; do
      case "$ch" in
        C) name="cyan" ;;
        M) name="magenta" ;;
        Y) name="yellow" ;;
        K) name="black" ;;
      esac

      magick "$OUTPUT" -channel "$ch" -separate \
        \( +clone -fill "$name" -colorize 100% \) \
        +swap -alpha off -compose CopyOpacity -composite \
        "$VERIFY/${PAGE_NAME}_${name}.tif"
    done

    rm -f "$TEMP_COLOR" "$TEMP_MASK_RICH_SVG" "$TEMP_MASK_PLAIN_SVG" "$TEMP_MASK_IGNORE_SVG" "$TEMP_MASK_NON_BLACK" "$TEMP_PLAIN_BLACK" "$TEMP_RICH_BLACK"
}

in_len=$(( ${#IN} + 4 ))

images=($(find "./$IN" -name "*.png"))
for img in "${images[@]}"; do
    relPath=$(echo "$img" | cut -c "${in_len}-")
    relPathNoExt="${relPath%.*}"
    outFile="$OUT/${relPathNoExt}_final.tiff"

    associated_plain_svg="./$BLACK_MASK_IN/${relPathNoExt}_black_full.svg"
    associated_rich_svg="./$BLACK_MASK_IN/${relPathNoExt}_black_rich.svg"
    associated_ignore_svg="./$BLACK_MASK_IN/${relPathNoExt}_ignore_box.svg"

    if [[ -f "$associated_plain_svg" && -f "$associated_rich_svg" ]]; then
        subDir=$(dirname "$OUT/$relPathNoExt")
        mkdir -p "$subDir"
        makeCMYK "$img" "$associated_plain_svg" "$associated_rich_svg" "$outFile" "$associated_ignore_svg"
    fi
done
