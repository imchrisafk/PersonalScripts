#!/usr/bin/env bash

# Converts media files to optimal FOSS formats (JXL for images, Opus for lossy audio,
# FLAC for lossless audio, FFV1+FLAC for lossless video, AV1+Opus for lossy video) with comprehensive
# metadata preservation. Ensures minimal loss, efficient compression, and robust error handling.
# Assumes AV1, H.264, and H.265 are lossy. Skips files already in target formats (JXL, Opus, FLAC,
# MKV with FFV1+FLAC or AV1+Opus).

# Exit on any error
##set -e

# Enable case-insensitive globbing for file matching
shopt -s nocaseglob

# Initialize variables
TRASH_MODE="prompt"                   # Default: prompt for trashing originals
VERBOSE_LEVEL=0                       # Default: no verbosity (0=normal, 1=script verbose, 2=tool verbose)
DIR="."                               # Process current directory
ERROR_LOG="/tmp/convert_media_$$.log" # Unique error log per run
START_TIME=$(date +%s)                # Track script start time for logging
OVERWRITE=0                           # Default: rename files on conflict

# Output directories (created only when needed)
JXL_OUTPUT_DIR="${DIR}/jxl_output"
OPUS_OUTPUT_DIR="${DIR}/opus_output"
FLAC_OUTPUT_DIR="${DIR}/flac_output"
MKV_OUTPUT_DIR="${DIR}/mkv_output"

# Supported file extensions
IMAGE_EXTENSIONS="jpg jpeg png bmp webp ppm pnm pfm pam pgx exr apng gif"
AUDIO_EXTENSIONS="mp3 wav m4a wma"
VIDEO_EXTENSIONS="webm m4s mp4 m4v mkv mov wmv avi mpeg 3gp mpg qt flv"

# Lossless video codecs (always lossless or virtually lossless)
LOSSLESS_VIDEO_CODECS="ffv1 huffyuv utvideo lagarith magicyuv qtrle aasc prores dnxhd dnxhr mjpeg"

# Function to generate unique output filename
get_unique_filename() {
    local base_path="$1"
    local ext="$2"
    local counter=1
    local output_file="${base_path}${ext}"

    if [ $OVERWRITE -eq 1 ] && [ -f "$output_file" ]; then
        log_verbose 1 "Overwriting existing file: $output_file"
        echo "$output_file"
        return 0
    fi

    while [ -f "$output_file" ]; do
        output_file="${base_path}_${counter}${ext}"
        ((counter++))
    done
    echo "$output_file"
}

# Parse command-line options
while [ $# -gt 0 ]; do
    case "$1" in
    --trash)
        [ "$TRASH_MODE" != "prompt" ] && {
            echo "Error: Cannot combine --trash with --no-trash or --trash-if-smaller"
            exit 1
        }
        TRASH_MODE="always"
        shift
        ;;
    --no-trash)
        [ "$TRASH_MODE" != "prompt" ] && {
            echo "Error: Cannot combine --no-trash with --trash or --trash-if-smaller"
            exit 1
        }
        TRASH_MODE="never"
        shift
        ;;
    --trash-if-smaller)
        [ "$TRASH_MODE" != "prompt" ] && {
            echo "Error: Cannot combine --trash-if-smaller with --trash or --no-trash"
            exit 1
        }
        TRASH_MODE="if-smaller"
        shift
        ;;
    --overwrite)
        OVERWRITE=1
        shift
        ;;
    --verbose | -v)
        VERBOSE_LEVEL=$((VERBOSE_LEVEL + 1))
        shift
        ;;
    *)
        echo "Error: Unknown option $1"
        echo "Usage: $0 [--trash | --no-trash | --trash-if-smaller] [--overwrite] [--verbose|-v]"
        exit 1
        ;;
    esac
done

# Function to log messages to stdout and error log
log_message() {
    local level="$1" # info, warning, error
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $level: $message" | tee -a "$ERROR_LOG"
    [ "$level" = "error" ] && exit 1
}

# Function to log verbose messages (only if VERBOSE_LEVEL >= required_level)
log_verbose() {
    local required_level="$1"
    local message="$2"
    if [ "$VERBOSE_LEVEL" -ge "$required_level" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $message"
    fi
}

# Check for required tools
check_tool() {
    local tool="$1"
    local package="$2"
    command -v "$tool" &>/dev/null || {
        log_message "error" "$tool not found. Please install $package (e.g., sudo apt-get install $package)."
    }
}

check_tool "cjxl" "libjxl-tools"
check_tool "ffmpeg" "ffmpeg"
check_tool "ffprobe" "ffmpeg"
check_tool "gio" "libglib2.0-bin"
check_tool "exiftool" "libimage-exiftool-perl"
check_tool "magick" "imagemagick"
check_tool "webp_to_apng" "webp_to_apng"

# Check if ImageMagick supports PGX
magick -list format | grep -qi "PGX" || {
    log_message "warning" "ImageMagick does not support PGX. Skipping PGX files."
}

# Check for exiftool availability for metadata copying
USE_EXIFTOOL=1
command -v exiftool &>/dev/null || {
    log_message "warning" "exiftool not found. Falling back to ffmpeg for metadata copying."
    USE_EXIFTOOL=0
}

# Function to get file size in bytes
get_size_bytes() {
    stat -c %s "$1" 2>/dev/null || echo 0
}

# Function to detect audio codec (lossy or lossless)
get_audio_codec() {
    local file="$1"
    local codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -n 1)
    case "$codec" in
    mp3 | aac | wma | wmav1 | wmav2) echo "lossy" ;;
    pcm_* | alac | flac | wmalossless) echo "lossless" ;;
    *) echo "unknown" ;;
    esac
}

# Function to get number of frames in an image
get_num_frames() {
    local file="$1"
    magick identify -format "%n\n" "$file" 2>/dev/null | head -n 1 || echo 1
}

# Function to detect if an image is animated
is_animated_image() {
    local file="$1"
    [ "$(get_num_frames "$file")" -gt 1 ] && echo "animated" || echo "static"
}

# Function to check if a video has an audio stream
has_audio_stream() {
    local file="$1"
    local audio_streams=$(ffprobe -v error -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | grep -c "audio")
    [ "$audio_streams" -gt 0 ] && echo "yes" || echo "no"
}

# Function to get audio bitrate in kbps
get_audio_bitrate() {
    local file="$1"
    local bitrate=$(ffprobe -v error -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 -select_streams a:0 "$file" 2>/dev/null | head -n 1)
    [ -n "$bitrate" ] && [ "$bitrate" != "N/A" ] && echo $((bitrate / 1000)) || echo 0
}

# Function to determine Opus output bitrate
get_opus_bitrate() {
    local bitrate="$1"
    if [ "$bitrate" -le 96 ]; then
        echo 64
    elif [ "$bitrate" -le 128 ]; then
        echo 96
    elif [ "$bitrate" -le 192 ]; then
        echo 128
    elif [ "$bitrate" -le 256 ]; then
        echo 192
    elif [ "$bitrate" -le 320 ]; then
        echo 256
    elif [ "$bitrate" -le 512 ]; then
        echo 320
    else
        echo 512
    fi
}

# Function to get video stream bitrate in kbps
get_video_bitrate() {
    local file="$1"
    local bitrate=$(ffprobe -v error -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$file" 2>/dev/null | head -n 1)
    [ -n "$bitrate" ] && [ "$bitrate" != "N/A" ] && echo $((bitrate / 1000 > 1000 ? bitrate / 1000 : 1000)) || echo 5000
}

# Function to check if a video codec is lossless
is_lossless_codec() {
    local codec="$1"
    for lossless_codec in $LOSSLESS_VIDEO_CODECS; do
        [ "$codec" = "$lossless_codec" ] && return 0
    done
    return 1
}

# Function to copy all metadata (EXIF, IPTC, XMP, and file system timestamps)
copy_metadata() {
    local input_file="$1"
    local output_file="$2"
    local type="$3"
    local temp_file="/tmp/metadata_temp_$$_${RANDOM}.tmp"

    if [ "$USE_EXIFTOOL" -eq 1 ]; then
        exiftool -TagsFromFile "$input_file" -all:all "$output_file" -overwrite_original 2>>"$ERROR_LOG" || {
            log_message "warning" "Failed to copy metadata to $output_file"
        }
    else
        ffmpeg -i "$input_file" -c copy -map_metadata 0 "$temp_file" -y 2>>"$ERROR_LOG" && mv "$temp_file" "$output_file" || {
            log_message "warning" "Failed to copy metadata to $output_file"
        }
    fi

    # Copy file system timestamps
    touch -r "$input_file" "$output_file" 2>>"$ERROR_LOG" || {
        log_message "warning" "Failed to copy file system timestamps to $output_file"
    }
}

# Function to attempt video encoding with a specific encoder (for lossy videos to AV1)
try_video_encoder() {
    local input_file="$1"
    local output_file="$2"
    local encoder="$3"
    local video_bitrate="$4"
    local has_audio="$5"
    local opus_bitrate="$6"
    local temp_file="/tmp/video_temp_$$_${RANDOM}.mkv"
    local ffmpeg_verbose=""
    [ "$VERBOSE_LEVEL" -ge 2 ] && ffmpeg_verbose="-loglevel verbose"

    if [ "$encoder" = "av1_vaapi" ]; then
        if [ "$has_audio" = "yes" ]; then
            ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -i "$input_file" -vf "format=nv12,hwupload,scale_vaapi" -c:v av1_vaapi -b:v "${video_bitrate}k" -c:a libopus -b:a "${opus_bitrate}k" -vbr on -compression_level 10 -strict -2 -map_metadata 0 $ffmpeg_verbose "$temp_file" -y 2>>"$ERROR_LOG"
        else
            ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -i "$input_file" -vf "format=nv12,hwupload,scale_vaapi" -c:v av1_vaapi -b:v "${video_bitrate}k" -an -map_metadata 0 $ffmpeg_verbose "$temp_file" -y 2>>"$ERROR_LOG"
        fi
    else
        if [ "$has_audio" = "yes" ]; then
            ffmpeg -i "$input_file" -c:v "$encoder" -b:v "${video_bitrate}k" -c:a libopus -b:a "${opus_bitrate}k" -vbr on -compression_level 10 -strict -2 -map_metadata 0 $ffmpeg_verbose "$temp_file" -y 2>>"$ERROR_LOG"
        else
            ffmpeg -i "$input_file" -c:v "$encoder" -b:v "${video_bitrate}k" -an -map_metadata 0 $ffmpeg_verbose "$temp_file" -y 2>>"$ERROR_LOG"
        fi
    fi

    if [ $? -eq 0 ] && [ -s "$temp_file" ]; then
        # Verify output is AV1
        local codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$temp_file" 2>/dev/null | head -n 1)
        if [ "$codec" = "av1" ]; then
            if [ "$has_audio" = "yes" ]; then
                local audio_codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -select_streams a:0 "$temp_file" 2>/dev/null | head -n 1)
                [ "$audio_codec" != "opus" ] && {
                    log_message "error" "$encoder produced non-Opus audio for $input_file"
                    rm -f "$temp_file"
                    return 1
                }
            fi
            mv "$temp_file" "$output_file"
            return 0
        else
            log_message "error" "$encoder produced non-AV1 output for $input_file"
            rm -f "$temp_file"
            return 1
        fi
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Function to encode video to FFV1+FLAC
encode_to_ffv1_flac() {
    local input_file="$1"
    local output_file="$2"
    local has_audio="$3"
    local temp_file="/tmp/video_temp_$$_${RANDOM}.mkv"
    local ffmpeg_verbose=""
    [ "$VERBOSE_LEVEL" -ge 2 ] && ffmpeg_verbose="-loglevel verbose"

    if [ "$has_audio" = "yes" ]; then
        ffmpeg -i "$input_file" -c:v ffv1 -level 3 -coder 1 -threads 4 -c:a flac -compression_level 12 -map_metadata 0 $ffmpeg_verbose "$temp_file" -y 2>>"$ERROR_LOG"
    else
        ffmpeg -i "$input_file" -c:v ffv1 -level 3 -coder 1 -threads 4 -an -map_metadata 0 $ffmpeg_verbose "$temp_file" -y 2>>"$ERROR_LOG"
    fi

    if [ $? -eq 0 ] && [ -s "$temp_file" ]; then
        # Verify output is FFV1
        local codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$temp_file" 2>/dev/null | head -n 1)
        if [ "$codec" = "ffv1" ]; then
            if [ "$has_audio" = "yes" ]; then
                local audio_codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -select_streams a:0 "$temp_file" 2>/dev/null | head -n 1)
                [ "$audio_codec" != "flac" ] && {
                    log_message "error" "FFV1 encoding produced non-FLAC audio for $input_file"
                    rm -f "$temp_file"
                    return 1
                }
            fi
            mv "$temp_file" "$output_file"
            return 0
        else
            log_message "error" "FFV1 encoding produced non-FFV1 output for $input_file"
            rm -f "$temp_file"
            return 1
        fi
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Function to determine video encoder with hardware acceleration and fallback (for lossy videos)
get_video_encoder() {
    local input_file="$1"
    local output_file="$2"
    local video_bitrate="$3"
    local has_audio="$4"
    local opus_bitrate="$5"
    local encoders=("av1_vaapi" "av1_nvenc" "libaom-av1")
    local available_encoders=$(ffmpeg -encoders 2>/dev/null)

    for encoder in "${encoders[@]}"; do
        if echo "$available_encoders" | grep -q "$encoder"; then
            log_verbose 1 "Trying encoder $encoder for $input_file"
            if try_video_encoder "$input_file" "$output_file" "$encoder" "$video_bitrate" "$has_audio" "$opus_bitrate"; then
                echo "$encoder"
                return 0
            fi
            log_message "warning" "$encoder failed for $input_file, trying next encoder"
        fi
    done
    log_message "error" "No suitable AV1 encoder found for $input_file"
    echo "none"
    return 1
}

# Function to trash original file based on TRASH_MODE
trash_file() {
    local file="$1"
    local output_file="$2"
    local original_size=$(get_size_bytes "$file")
    local output_size=$(get_size_bytes "$output_file")

    case "$TRASH_MODE" in
    always)
        gio trash "$file" 2>>"$ERROR_LOG" && log_message "info" "Trashed original: $file"
        ;;
    prompt)
        read -p "Move original file '$file' to trash? [y/N] " response
        [[ "$response" =~ ^[Yy]$ ]] && {
            gio trash "$file" 2>>"$ERROR_LOG" && log_message "info" "Trashed original: $file"
        }
        ;;
    if-smaller)
        if [ "$output_size" -le "$original_size" ] && [ "$output_size" -gt 0 ]; then
            gio trash "$file" 2>>"$ERROR_LOG" && log_message "info" "Trashed original: $file ($output_size bytes <= $original_size bytes)"
        else
            log_verbose 1 "Not trashing $file: Output ($output_size bytes) larger than original ($original_size bytes)"
        fi
        ;;
    esac
}

# Function to convert animated WebP to JPEG-XL via APNG
convert_webp_animated() {
    local file="$1"
    local filename=$(basename "$file" | sed -E "s/\.webp$//i")
    local cjxl_verbose=""
    [ "$VERBOSE_LEVEL" -ge 2 ] && cjxl_verbose="--verbose"

    mkdir -p "$JXL_OUTPUT_DIR"
    local jxl_base="${JXL_OUTPUT_DIR}/${filename}"
    local jxl_file=$(get_unique_filename "$jxl_base" ".jxl")

    # Convert WebP to APNG using webp_to_apng
    local interm_apng="/tmp/${filename}_interim_$$_${RANDOM}.apng"
    log_verbose 1 "Converting animated WebP to intermediate APNG for $file"

    webp_to_apng "$file" "$interm_apng" 2>>"$ERROR_LOG" || {
        log_message "error" "Failed to convert WebP to APNG for $file"
        rm -f "$interm_apng"
        return 1
    }

    # Convert APNG to JXL
    cjxl -d 0 $cjxl_verbose "$interm_apng" "$jxl_file" 2>>"$ERROR_LOG" || {
        log_message "error" "Failed to convert APNG to JXL for $file"
        rm -f "$interm_apng"
        return 1
    }

    rm -f "$interm_apng"
    log_message "info" "Converted (animated WebP): $file -> $jxl_file"
    copy_metadata "$file" "$jxl_file" "image"
    trash_file "$file" "$jxl_file"
    return 0
}

# Trap SIGINT for graceful exit
trap 'log_message "info" "Script interrupted. Cleaning up..."; rm -f /tmp/*_$$_*.tmp; exit 1' SIGINT

# Process images to JPEG-XL
for ext in $IMAGE_EXTENSIONS; do
    for file in "$DIR"/*."$ext"; do
        if [ -f "$file" ] && [[ "$file" != "$JXL_OUTPUT_DIR"/* ]]; then
            filename=$(basename "$file" | sed -E "s/\.${ext}$//i")
            image_type=$(is_animated_image "$file")
            log_verbose 1 "Processing image $file ($image_type)"

            if [ "$ext" = "webp" ] && [ "$image_type" = "animated" ]; then
                convert_webp_animated "$file" || continue
            else
                mkdir -p "$JXL_OUTPUT_DIR"
                jxl_base="${JXL_OUTPUT_DIR}/${filename}"
                jxl_file=$(get_unique_filename "$jxl_base" ".jxl")
                cjxl_verbose=""
                [ "$VERBOSE_LEVEL" -ge 2 ] && cjxl_verbose="--verbose"

                if [ "$image_type" = "animated" ]; then
                    cjxl -d 0 $cjxl_verbose "$file" "$jxl_file" 2>>"$ERROR_LOG" || {
                        log_message "warning" "cjxl failed for animated $file, falling back to ImageMagick"
                        magick "$file" -strip -define jxl:effort=9 "$jxl_file" 2>>"$ERROR_LOG" || {
                            log_message "error" "ImageMagick failed to convert animated $file"
                            continue
                        }
                    }
                    log_message "info" "Converted (animated image): $file -> $jxl_file"
                else
                    cjxl -q 100 --lossless_jpeg=1 --effort=9 --num_threads=4 $cjxl_verbose "$file" "$jxl_file" 2>>"$ERROR_LOG" || {
                        log_message "warning" "cjxl failed for $file, falling back to ImageMagick"
                        magick "$file" -strip -quality 100 -define jxl:effort=9 -define jxl:lossless=true "$jxl_file" 2>>"$ERROR_LOG" || {
                            log_message "error" "ImageMagick failed to convert $file"
                            continue
                        }
                    }
                    log_message "info" "Converted (static image): $file -> $jxl_file"
                fi

                copy_metadata "$file" "$jxl_file" "image"
                trash_file "$file" "$jxl_file"
            fi
        fi
    done
done

# Process audio files
for ext in $AUDIO_EXTENSIONS; do
    for file in "$DIR"/*."$ext"; do
        if [ -f "$file" ] && [[ "$file" != "$OPUS_OUTPUT_DIR"/* ]] && [[ "$file" != "$FLAC_OUTPUT_DIR"/* ]]; then
            filename=$(basename "$file" | sed -E "s/\.${ext}$//i")
            codec_type=$(get_audio_codec "$file")
            log_verbose 1 "Processing audio $file ($codec_type)"

            if [ "$codec_type" = "lossy" ]; then
                mkdir -p "$OPUS_OUTPUT_DIR"
                bitrate=$(get_audio_bitrate "$file")
                opus_bitrate=$([ "$bitrate" -eq 0 ] && echo 192 || get_opus_bitrate "$bitrate")
                opus_base="${OPUS_OUTPUT_DIR}/${filename}"
                opus_file=$(get_unique_filename "$opus_base" ".opus")
                ffmpeg_verbose=""
                [ "$VERBOSE_LEVEL" -ge 2 ] && ffmpeg_verbose="-loglevel verbose"

                ffmpeg -i "$file" -c:a libopus -b:a "${opus_bitrate}k" -vbr on -compression_level 10 -map_metadata 0 $ffmpeg_verbose "$opus_file" -y 2>>"$ERROR_LOG" || {
                    log_message "error" "Failed to convert lossy audio $file"
                    continue
                }

                log_message "info" "Converted (lossy, ${opus_bitrate} kbps): $file -> $opus_file"
                copy_metadata "$file" "$opus_file" "audio"
                trash_file "$file" "$opus_file"
            elif [ "$codec_type" = "lossless" ]; then
                mkdir -p "$FLAC_OUTPUT_DIR"
                flac_base="${FLAC_OUTPUT_DIR}/${filename}"
                flac_file=$(get_unique_filename "$flac_base" ".flac")
                ffmpeg_verbose=""
                [ "$VERBOSE_LEVEL" -ge 2 ] && ffmpeg_verbose="-loglevel verbose"

                ffmpeg -i "$file" -c:a flac -compression_level 12 -map_metadata 0 $ffmpeg_verbose "$flac_file" -y 2>>"$ERROR_LOG" || {
                    log_message "error" "Failed to convert lossless audio $file"
                    continue
                }

                log_message "info" "Converted (lossless): $file -> $flac_file"
                copy_metadata "$file" "$flac_file" "audio"
                trash_file "$file" "$flac_file"
            else
                log_message "warning" "Skipping $file: Unknown or unsupported codec ($codec_type)"
            fi
        fi
    done
done

# Process videos to FFV1+FLAC (lossless) or AV1+Opus (lossy) in MKV
for ext in $VIDEO_EXTENSIONS; do
    for file in "$DIR"/*."$ext"; do
        if [ -f "$file" ] && [[ "$file" != "$MKV_OUTPUT_DIR"/* ]]; then
            # Check if MKV and already in target format (FFV1+FLAC or AV1+Opus)
            if [[ "$file" =~ \.mkv$ ]]; then
                video_codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$file" 2>/dev/null | head -n 1)
                has_audio=$(has_audio_stream "$file")
                audio_codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -select_streams a:0 "$file" 2>/dev/null | head -n 1)
                if [ "$video_codec" = "ffv1" ] && { [ "$has_audio" = "no" ] || [ "$has_audio" = "yes" ] && [ "$audio_codec" = "flac" ]; }; then
                    log_message "info" "Skipping $file: Already encoded with FFV1 video and FLAC audio"
                    continue
                elif [ "$video_codec" = "av1" ] && { [ "$has_audio" = "no" ] || [ "$has_audio" = "yes" ] && [ "$audio_codec" = "opus" ]; }; then
                    log_message "info" "Skipping $file: Already encoded with AV1 video and Opus audio"
                    continue
                fi
            fi

            # Proceed with codec analysis for non-skipped files
            video_codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$file" 2>/dev/null | head -n 1)
            has_audio=$(has_audio_stream "$file")
            audio_codec=$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 -select_streams a:0 "$file" 2>/dev/null | head -n 1)

            filename=$(basename "$file" | sed -E "s/\.${ext}$//i")
            mkdir -p "$MKV_OUTPUT_DIR"
            mkv_base="${MKV_OUTPUT_DIR}/${filename}"
            mkv_file=$(get_unique_filename "$mkv_base" ".mkv")

            # Check if video codec is lossless
            if is_lossless_codec "$video_codec"; then
                log_verbose 1 "Detected lossless video codec ($video_codec) for $file, converting to FFV1+FLAC"
                if encode_to_ffv1_flac "$file" "$mkv_file" "$has_audio"; then
                    log_message "info" "Converted (lossless, FFV1+FLAC): $file -> $mkv_file"
                    copy_metadata "$file" "$mkv_file" "video"
                    trash_file "$file" "$mkv_file"
                else
                    log_message "error" "Failed to convert lossless video $file to FFV1+FLAC"
                    continue
                fi
            else
                # Handle lossy or other codecs with AV1+Opus
                video_bitrate=$(get_video_bitrate "$file")
                opus_bitrate=$([ "$has_audio" = "yes" ] && {
                    ab=$(get_audio_bitrate "$file")
                    [ "$ab" -eq 0 ] && echo 192 || get_opus_bitrate "$ab"
                } || echo 0)

                video_encoder=$(get_video_encoder "$file" "$mkv_file" "$video_bitrate" "$has_audio" "$opus_bitrate")
                [ "$video_encoder" = "none" ] && continue

                log_message "info" "Converted (lossy, AV1 ${video_bitrate} kbps, Opus ${opus_bitrate} kbps, encoder $video_encoder): $file -> $mkv_file"
                copy_metadata "$file" "$mkv_file" "video"
                trash_file "$file" "$mkv_file"
            fi
        fi
    done
done

# Disable case-insensitive matching
shopt -u nocaseglob

# Clean up temporary files
rm -f /tmp/*_$$_*.tmp

# Log completion
log_message "info" "Conversion complete. Output directories: $JXL_OUTPUT_DIR, $OPUS_OUTPUT_DIR, $FLAC_OUTPUT_DIR, $MKV_OUTPUT_DIR"
log_message "info" "Error log saved to: $ERROR_LOG"
log_message "info" "Total runtime: $(($(date +%s) - START_TIME)) seconds"
