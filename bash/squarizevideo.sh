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

# Get video dimensions
WIDTH=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width -of csv=p=0 "$INPUT_FILE")
HEIGHT=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=height -of csv=p=0 "$INPUT_FILE")

if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ]; then
    echo "Error: Could not determine video dimensions"
    exit 1
fi

echo "Input dimensions: ${WIDTH}x${HEIGHT}"

# Get frame rate
FPS_RAW=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=r_frame_rate -of csv=p=0 "$INPUT_FILE")
FPS_DECIMAL=$(awk -F'/' '{
    if (NF == 2 && $2 != 0) printf "%.4f", $1 / $2
    else printf "%s", $1
}' <<<"$FPS_RAW")

# Define interpolation filter when FPS < 60
if awk "BEGIN { exit ($FPS_DECIMAL >= 60) }"; then
    echo "Input FPS: ${FPS_DECIMAL} — interpolating to 60fps (this may take a while)"
    # mci = motion-compensated interpolation; aobmc + bidir improve accuracy
    FPS_FILTER="minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,"
else
    echo "Input FPS: ${FPS_DECIMAL} — already ≥ 60fps, skipping interpolation"
    FPS_FILTER=""
fi

# Compute output video size, background scale and overlay offset
if [ "$WIDTH" -gt "$HEIGHT" ]; then
    ORIENTATION="horizontal"
    S=$WIDTH
    # Scale height → S (width will overshoot); crop S×S from center
    BG_SCALE="-1:${S}"
    OV_X=0
    OV_Y=$(((S - HEIGHT) / 2))
elif [ "$HEIGHT" -gt "$WIDTH" ]; then
    ORIENTATION="vertical"
    S=$HEIGHT
    # Scale width → S (height will overshoot); crop S×S from center
    BG_SCALE="${S}:-1"
    OV_X=$(((S - WIDTH) / 2))
    OV_Y=0
else
    ORIENTATION="square"
    S=$WIDTH
    BG_SCALE="${S}:-1"
    OV_X=0
    OV_Y=0
fi

echo "Orientation: ${ORIENTATION} → output: ${S}×${S}, overlay offset: (${OV_X}, ${OV_Y})"

# Build filth graph
FILTER="\
[0:v]${FPS_FILTER}split=2[bg_in][fg];\
[bg_in]scale=${BG_SCALE},\
crop=${S}:${S}:(iw-${S})/2:(ih-${S})/2,\
boxblur=luma_radius=20:luma_power=2[bg];\
[bg][fg]overlay=${OV_X}:${OV_Y}\
"

# Process video: split stream, create blurred background by zooming and cropping input to match height as width, overlay original video, encode to H.264/AAC
ffmpeg -i "$INPUT_FILE" -filter_complex "[0:v]split=2[blur][vid];[blur]tblend,fps=60,boxblur=8,scale=in_h:-1,crop=in_w:in_w:0:in_h/3[bg];[vid]tblend,fps=60[ov];[bg][ov]overlay=(W-w)/2,fps=60" -c:v libx264 -c:a aac -b:v 10M -b:a 320k "$OUTPUT_FILE"
