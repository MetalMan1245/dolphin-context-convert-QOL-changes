#!/bin/bash

input_file="$1"
output_extension="$2"
input_format="$3"
resolve_flag="$4"   # new argument to detect Resolve conversion
filename=$(basename -- "$input_file")
filename_noext="${filename%.*}"

# Set output file path
if [ "$output_extension" == "alac" ]; then
    output_file="${filename_noext}.m4a"
else
    output_file="${filename_noext}.${output_extension}"
fi

alossy=("mp3" "aac" "ogg" "wma" "m4a")
alossless=("flac" "alac" "wav" "aiff")
ilossy=("jpg" "gif" "webp")
ilossless=("png" "bmp" "tiff" "eps" "raw" "ico" "tga")
superlossless=("psd")
alllossy=( "${alossy[@]}" "${ilossy[@]}" )
alllossless=( "${alossless[@]}" )



# warnings for lossy <-> lossless conversions
input_extension="${filename##*.}"
if [[ " ${alllossy[@]} " =~ " ${input_extension} " ]] && [[ " ${alllossless[@]} " =~ " ${output_extension} " ]]; then
    zenity --question --text="WARNING: Converting from lossy to lossless.\nQuality will NOT improve.\nContinue?" \
        --ok-label="Continue" --cancel-label="Cancel" --default-cancel --icon-name="warning"
    if [ $? -ne 0 ]; then exit 1; fi
fi

if [[ " ${alllossless[@]} " =~ " ${input_extension} " ]] && [[ " ${alllossy[@]} " =~ " ${output_extension} " ]]; then
    zenity --question --text="WARNING: Converting from lossless to lossy.\nQuality will NOT be preserved.\nContinue?" \
        --ok-label="Continue" --cancel-label="Cancel" --default-cancel --icon-name="warning"
    if [ $? -ne 0 ]; then exit 1; fi
fi

if [[ " ${superlossless[@]} " =~ " ${input_extension} " ]]; then
    zenity --question --text="WARNING: This file contains extra data (layers, etc.) that will be lost.\nContinue?" \
        --ok-label="Continue" --cancel-label="Cancel" --default-cancel --icon-name="warning"
    if [ $? -ne 0 ]; then exit 1; fi
fi

# --- RESOLVE SPECIAL CASE ---
if [[ "$resolve_flag" == "resolve" ]]; then
    output_file="${filename_noext}_resolve.mp4"

    ffmpeg_cmd=(
        ffmpeg -i "$input_file"
        -map 0
        -map_metadata 0
        -c:v av1_qsv -crf 30 -preset 6
        -c:a libopus -b:a 192k
        "$output_file"
    )
else
    # normal conversion based on extension
    if [[ " ${alossy[@]} " =~ " ${output_extension} " ]] || [[ " ${alossless[@]} " =~ " ${output_extension} " ]]; then
        case "$output_extension" in
            mp3)
                # High quality MP3 (CBR 320kbps)
                ffmpeg_cmd=(ffmpeg -i "$input_file" -codec:a libmp3lame -b:a 320k "$output_file")
                ;;
            aac|m4a)
                # High quality AAC (VBR 0 = best)
                ffmpeg_cmd=(ffmpeg -i "$input_file" -codec:a aac -q:a 0 "$output_file")
                ;;
            ogg)
                # High quality OGG Vorbis (VBR 10 = best)
                ffmpeg_cmd=(ffmpeg -i "$input_file" -codec:a libvorbis -q:a 10 "$output_file")
                ;;
            wma)
                # High quality WMA (variable bitrate max)
                ffmpeg_cmd=(ffmpeg -i "$input_file" -codec:a wmav2 -b:a 192k "$output_file")
                ;;
            flac|alac|wav|aiff)
                # Lossless: just copy to preserve quality
                if [ "$output_extension" == "alac" ]; then
                    ffmpeg_cmd=(ffmpeg -i "$input_file" -acodec alac "$output_file")
                else
                    ffmpeg_cmd=(ffmpeg -i "$input_file" -c:a copy "$output_file")
                fi
                ;;
            *)
                ffmpeg_cmd=(ffmpeg -i "$input_file" -q:a 0 "$output_file")
                ;;
        esac
    else
        # images
        ffmpeg_cmd=(ffmpeg -i "$input_file" -q:v 1 "$output_file")
    fi
fi

# don't overwrite a file
if [ -e "$output_file" ]; then
    zenity --error --text="The target file already exists."
    exit 1
fi

# run the command in background
setsid "${ffmpeg_cmd[@]}" &
CONVERT_PID=$!

# progress dialog
# start progress dialog in background
(
    while true; do
        if ! kill -0 $CONVERT_PID 2>/dev/null; then
            break
        fi
        echo "# Converting\n$filename\nto\n$output_file"
        sleep 1
    done
) | zenity --progress \
    --title="Converting Media" \
    --text="Initializing..." \
    --auto-close &

ZENITY_PID=$!

# monitor both processes
while true; do
    # ffmpeg finished
    if ! kill -0 $CONVERT_PID 2>/dev/null; then
        break
    fi

    # user closed/cancelled zenity
    if ! kill -0 $ZENITY_PID 2>/dev/null; then
        kill -9 -$CONVERT_PID 2>/dev/null
        rm -f "$output_file"
        zenity --error --text="Conversion canceled. Target file deleted."
        exit 1
    fi

    sleep 0.5
done

wait $CONVERT_PID

# check exit status
wait $CONVERT_PID
if [ $? -ne 0 ]; then
    zenity --error --text="An error occurred during conversion."
    exit 1
fi
