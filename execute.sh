#!/bin/bash

# --- Configuration & Step Mapping ---
START=1
STOP=6

# 1. ADDED TRAP LOGIC: This catches Ctrl+C (SIGINT) and exits the script immediately
trap "echo -e '\nExiting script...'; exit 1" SIGINT

# --- Arguments ---
for i in "$@"; do
  case $i in
    --start=*) START="${i#*=}" ;;
    --stop=*)  STOP="${i#*=}" ;;
    *) ;; 
  esac
done

echo "Executing steps $START to $STOP"

# --- Functions ---
sortFiles() {
    local dirs=("Rulebook" "BoxTop" "BoxBottom" "ActionDeck1Front" "ActionDeck2Front" "TaskFront" "TaskBack" "ActionDeck1Back" "ActionDeck2Back")
	rm -rf "Files/1_Ordered"
    for d in "${dirs[@]}"; do
        mkdir -p "Files/1_Ordered/$d"
    done
    echo -e "\n\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Step 1: Sorting Files"
    
    rename 's/±/plus_minus_/' ./Files/0_Content/ActionDeck1Front/*
    rename 's/plus_minus_10/plus_minus_ten/' ./Files/0_Content/ActionDeck1Front/*

    ./sortFiles.sh -i ./Files/0_Content/ActionDeck1Front -o ./Files/1_Ordered/ActionDeck1Front "break_.*" "plus_minus_[0-9]+.*" "plus_minus_ten.*" "mult-divide.*" "super.*" "negate.*" "rotate.*" || exit 1
    ./sortFiles.sh -i ./Files/0_Content/ActionDeck2Front -o ./Files/1_Ordered/ActionDeck2Front 'Danger Action.*' '.*outage.*' '.*bug.*' 'danger card front .*' || exit 1
    ./sortFiles.sh -i ./Files/0_Content/ActionDeck1Back -o ./Files/1_Ordered/ActionDeck1Back '.*' || exit 1
    ./sortFiles.sh -i ./Files/0_Content/ActionDeck2Back -o ./Files/1_Ordered/ActionDeck2Back 'danger card front .*' 'action.*' 'Danger Action.*' || exit 1
    ./sortFiles.sh -i ./Files/0_Content/TaskFront -o ./Files/1_Ordered/TaskFront -r -n || exit 1
    ./sortFiles.sh -i ./Files/0_Content/TaskBack -o ./Files/1_Ordered/TaskBack '.*' || exit 1
    ./sortFiles.sh -i ./Files/0_Content/BoxTop -o ./Files/1_Ordered/BoxTop || exit 1
    ./sortFiles.sh -i ./Files/0_Content/BoxBottom -o ./Files/1_Ordered/BoxBottom || exit 1
    ./sortFiles.sh -i ./Files/0_Content/Rulebook -o ./Files/1_Ordered/Rulebook -n || exit 1
}

sliceSvg() {
	rm -rf "Files/2_Sliced"
    echo -e "\n\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Step 2: Slicing SVG"
    ./sliceSvg.sh './Files/1_Ordered' '' './Files/2_Sliced' '_green' '#69FF1F' 'none' 0 || exit 1
    ./sliceSvg.sh './Files/1_Ordered' '' './Files/2_Sliced' '_black_full' '#000000' 'none' 0 || exit 1
    ./sliceSvg.sh './Files/2_Sliced' '_black_full' './Files/2_Sliced' '_black_split' '#000000' '#FF0000' 100 || exit 1
    ./sliceSvg.sh './Files/2_Sliced' '_black_split' './Files/2_Sliced' '_black' '#000000' 'none' 0 || exit 1
    # find "Files/2_Sliced" -type f -name "*_black_full.svg" -delete
    # find "Files/2_Sliced" -type f -name "*_black_split.svg" -delete
    ./copyDir.sh Files/1_Ordered Files/2_Sliced || exit 1
}

subtract() {
	rm -rf "Files/3_Subtracted"
    echo -e "\n\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Step 3: Subtracting SVG from PNG"
    ./copyDir.sh Files/1_Ordered Files/3_Subtracted "*.png" || exit 1
    # ./subtractSvgFromPng.sh Files/2_Sliced _green Files/3_Subtracted || exit 1
}

convert() {
	rm -rf "Files/4_Converted"
    echo -e "\n\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Step 4: Converting Image Colors"
    ./ConvertImageColors.sh Files/3_Subtracted Files/4_Converted Files/2_Sliced || exit 1
}

copyFinal() {
	echo -e "\n\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Step 5: Copying final files"
	rm -rf "Files/5_Final"
    ./copyDir.sh Files/4_Converted Files/5_Final "*_final.tiff" || exit 1
    ./copyDir.sh Files/2_Sliced Files/5_Final "*_green.svg" || exit 1
}

createAiPDF() {
    echo -e "\n\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Step 6: Creating AI PDFs"
    local dirs=("ActionDeck1Front" "ActionDeck2Front" "TaskFront" "TaskBack" "ActionDeck1Back" "ActionDeck2Back" "Rulebook" "BoxTop" "BoxBottom") 
    for d in "${dirs[@]}"; do
        rm -rf "Files/6_AI/$d"
        mkdir -p "Files/6_AI/$d"
    done
    local template="Files/BlankTemplate.ai"
    for d in "${dirs[@]}"; do
        if [ -d "Files/5_Final/$d" ]; then
            echo "Processing directory $d"
            ./createAIPDF.sh "Files/5_Final/$d" "Files/6_AI/$d" "$template" || exit 1
        else
            echo "Skipping directory $d"
        fi
    done
}

# --- Execution Logic ---
[[ $START -le 1 && $STOP -ge 1 ]] && sortFiles
[[ $START -le 2 && $STOP -ge 2 ]] && sliceSvg
[[ $START -le 3 && $STOP -ge 3 ]] && subtract
[[ $START -le 4 && $STOP -ge 4 ]] && convert
[[ $START -le 5 && $STOP -ge 5 ]] && copyFinal
[[ $START -le 6 && $STOP -ge 6 ]] && createAiPDF

echo "Done."