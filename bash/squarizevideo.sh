#!/usr/bin/env bash

# Usage: ./squarizevideo.sh <input_file> <output_file>

# Takes in a vertical video and converts it to a 1:1 aspect ratio video.
# A zoomed and blurred copy of the original video stream is layered in the background
# to fill the left and right margins. The output is encoded as an h264+aac mp4 file.

# Configuration
INPUT_FILE="$1"
OUTPUT_FILE="$2"

ffmpeg -i "$INPUT_FILE" -filter_complex "[0:v]split=2[blur][vid];[blur]tblend,fps=60,boxblur=8,scale=in_h:-1,crop=in_w:in_w:0:in_h/3[bg];[vid]tblend,fps=60[ov];[bg][ov]overlay=(W-w)/2,fps=60" -c:v libx264 -c:a aac -b:v 10M -b:a 320k "$OUTPUT_FILE"
