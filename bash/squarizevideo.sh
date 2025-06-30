#!/usr/bin/env bash

# Usage: ./squarizevideo.sh <input_file> [output_file]

# Takes in a vertical video and converts it to a 1:1 aspect ratio video.
# A zoomed and blurred copy of the original video stream is layered in the background
# to fill the left and right margins. The output is encoded as an h264+aac mp4 file.
# An output filename may or may not be include. But it must end in '.mp4'.

# Configuration
if [ -z "$1" ]; then
    echo "Error: Please provide a file path as first argument"
    exit 1
fi
INPUT_FILE="$1"

if [ -n "$2" ]; then
    if [[ "$2" == *.mp4 ]]; then
        OUTPUT_FILE="$2"
    else
        echo "Error: Second argument must have .mp4 extension"
        exit 1
    fi
else
    OUTPUT_FILE="$(dirname "$INPUT_FILE")/$(basename "$INPUT_FILE" | cut -f 1 -d '.').squarized.mp4"
fi

ffmpeg -i "$INPUT_FILE" -filter_complex "[0:v]split=2[blur][vid];[blur]tblend,fps=60,boxblur=8,scale=in_h:-1,crop=in_w:in_w:0:in_h/3[bg];[vid]tblend,fps=60[ov];[bg][ov]overlay=(W-w)/2,fps=60" -c:v libx264 -c:a aac -b:v 10M -b:a 320k "$OUTPUT_FILE"
