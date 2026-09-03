#!/bin/bash

# Check for 7 arguments
if [ "$#" -ne 7 ]; then
    echo "Usage: $0 <input_root> <input_suffix> <output_root> <output_suffix> <hex_target> <colorMode: hex|none|empty> <complexityThreshold: int>"
    exit 1
fi

INPUT_ROOT="$1"
INPUT_SUFFIX="$2"
OUTPUT_ROOT="$3"
OUTPUT_SUFFIX="$4"

# Export for Perl %ENV access
export HEX_COLOR="$5"
export COLOR_MODE="$6"
export PATH_COMPLEXITY_THRESHOLD="$7"

if [ ! -d "$INPUT_ROOT" ]; then
    echo "Error: Input directory '$INPUT_ROOT' does not exist."
    exit 1
fi

find "$INPUT_ROOT" -type f -iname "*${INPUT_SUFFIX}.svg" | while read -r src_file; do
    echo -n "Processing $src_file..."

    rel_path="${src_file#$INPUT_ROOT/}"
    path_no_ext="${rel_path%.svg}"
    base_clean="${path_no_ext%$INPUT_SUFFIX}"
    target_file="$OUTPUT_ROOT/${base_clean}${OUTPUT_SUFFIX}.svg"
    temp_file="${target_file%.svg}_tmp.svg"
    
    mkdir -p "$(dirname "$target_file")"
    cp "$src_file" "$temp_file"

    # Normalize 'black' keywords
    if [[ "$HEX_COLOR" == "#000000" ]]; then
        sed -i '' 's/"black"/"#000000"/g; s/:black/:#000000/g' "$temp_file"
    fi

    perl -0777 -pe '
        my $h  = $ENV{HEX_COLOR};
        my $m  = $ENV{COLOR_MODE};
        my $t  = int($ENV{PATH_COMPLEXITY_THRESHOLD});

        # 1. Cleanup (Now stripping out embedded raster images to prevent mask corruption)
        s{<g[^>]*\bopacity=[^>]*>.*?<\/g>}{}gs;
        s{<[^>]*\bopacity=[^>]*\/>}{}gs;
        s{<filter[^>]*>.*?<\/filter>}{}gs;
        s{\s?\bfilter="[^"]*"}{}g;
        s{<image[^>]*?>.*?<\/image>}{}gs;
        s{<image[^>]*?\/>}{}gs;

        # 2. Color Logic
        my @chunks = split(/(<mask[^>]*>.*?<\/mask>)/s, $_);
        foreach my $chunk (@chunks) {
            if ($chunk =~ /^<mask/) {
                $chunk =~ s/\b(fill|stroke)="(?!none)[^"]*"/$1="white"/g;
            } else {
                if ($m eq "none") {
                    # SLICE MODE
                    $chunk =~ s/\b(fill|stroke)="(?!(?:$h\b|none))[^"]*"/$1="none"/g;
                } elsif ($m ne "") {
                    # SWAP MODE
                    if ($t > 0) {
                        # Targeted path swap based on complexity threshold
                        $chunk =~ s{(<path[^>]*?>)}{
                            my $tag = $1;
                            if ($tag =~ m/\bd="([^"]*)"/) {
                                my $d = $1;
                                # Count commands and coordinates
                                my @el = split(/[\s,]+|(?=[a-zA-Z])|(?<=[a-zA-Z])/, $d);
                                if (scalar(@el) >= $t) {
                                    $tag =~ s/\b(fill|stroke)="\Q$h\E"/$1="$m"/g;
                                }
                            }
                            $tag;
                        }geis;
                    } else {
                        # Standard swap (All elements)
                        $chunk =~ s/\b(fill|stroke)="\Q$h\E"/$1="$m"/g;
                    }
                } else {
                    # GLOBAL MODE
                    $chunk =~ s/\b(fill|stroke)="(?!none)[^\"]*"/$1="$h"/g;
                }
            }
        }
        $_ = join("", @chunks);

        # 3. Mask to ClipPath
        s/<mask/<clipPath/g;
        s/<\/mask>/<\/clipPath>/g;
        s/\bmask="url\(#[^"]*\)"/clip-path=$&/g;
        s/clip-path=mask/clip-path/g;
    ' "$temp_file" > "$target_file"

    echo " Done."
    rm "$temp_file"
done