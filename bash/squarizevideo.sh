#!/usr/bin/env bash

# Converts a vertical video to a 1:1 aspect ratio by adding a blurred background.
# The background is a zoomed and cropped version of the input video, scaled to a width equal to the input video's height.

# Usage: ./squarizevideo.sh <input_file> [output_file]
# - input_file: Path to the input video file.
# - output_file: Optional output file path (must end in '.mp4'). Defaults to '<input_basename>.squarized.mp4'.

# Output is encoded as H.264 video and AAC audio in an MP4 container.

# Exit if no input file is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a file path as first argument"
    exit 1
fi
INPUT_FILE="$1"

# Set output file path, ensuring it ends with '.mp4'
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

# Process video: split stream, create blurred background by zooming and cropping input to match height as width, overlay original video, encode to H.264/AAC
ffmpeg -i "$INPUT_FILE" -filter_complex "[0:v]split=2[blur][vid];[blur]tblend,fps=60,boxblur=8,scale=in_h:-1,crop=in_w:in_w:0:in_h/3[bg];[vid]tblend,fps=60[ov];[bg][ov]overlay=(W-w)/2,fps=60" -c:v libx264 -c:a aac -b:v 10M -b:a 320k "$OUTPUT_FILE"
