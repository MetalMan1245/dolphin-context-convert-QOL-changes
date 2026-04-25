#!/bin/bash

output_extension="$1"
shift

if [ -z "$output_extension" ]; then
    zenity --error --text="No output format specified."
    exit 1
fi

if [ $# -eq 0 ]; then
    zenity --error --text="No input files provided."
    exit 1
fi

output_extension="$(echo "$output_extension" | tr '[:upper:]' '[:lower:]')"

video_exts=("mp4" "mkv" "mov" "avi" "webm" "flv" "mpg" "mpeg" "ogv")

any_failed=0
total_files=$#
current=0

(
for input_file in "$@"; do
    current=$((current + 1))

    filename=$(basename -- "$input_file")
    filename_noext="${filename%.*}"
    input_extension="$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')"
    dir=$(dirname "$input_file")

    if [ "$output_extension" == "alac" ]; then
        output_file="$dir/${filename_noext}.m4a"
    else
        output_file="$dir/${filename_noext}.${output_extension}"
    fi

    echo "# Converting ($current/$total_files)\n$filename"

    ########################################
    # DETECT CODECS
    ########################################

    video_codec=""
    audio_codec=""

    if [[ " ${video_exts[@]} " =~ " ${input_extension} " ]]; then
        video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$input_file")
        audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$input_file")
    fi

    ########################################
    # BUILD COMMAND
    ########################################

    if [[ " ${video_exts[@]} " =~ " ${input_extension} " ]]; then

        can_copy=0

        case "$output_extension" in
            mp4)
                [[ "$video_codec" =~ ^(h264|hevc|mpeg4)$ && "$audio_codec" =~ ^(aac|mp3)$ ]] && can_copy=1
                ;;
            mkv)
                can_copy=1
                ;;
            webm)
                [[ "$video_codec" =~ ^(vp8|vp9|av1)$ && "$audio_codec" =~ ^(opus|vorbis)$ ]] && can_copy=1
                ;;
            avi)
                [[ "$video_codec" =~ ^(mpeg4|h264)$ && "$audio_codec" =~ ^(mp3)$ ]] && can_copy=1
                ;;
            mpg|mpeg)
                [[ "$video_codec" =~ ^(mpeg1video|mpeg2video)$ ]] && can_copy=1
                ;;
            ogv)
                [[ "$video_codec" == "theora" ]] && can_copy=1
                ;;
        esac

        if [ $can_copy -eq 1 ]; then
            ffmpeg -y -i "$input_file" -c copy "$output_file" > /dev/null 2>&1
        else
            case "$output_extension" in
                mp4|mkv|mov)
                    ffmpeg -y -i "$input_file" -c:v libx264 -crf 18 -preset medium -c:a aac "$output_file"
                    ;;
                webm)
                    ffmpeg -y -i "$input_file" -c:v libvpx-vp9 -c:a libopus "$output_file"
                    ;;
                avi)
                    ffmpeg -y -i "$input_file" -c:v libx264 -c:a mp3 "$output_file"
                    ;;
                mpg|mpeg)
                    ffmpeg -y -i "$input_file" -c:v mpeg2video -c:a mp2 "$output_file"
                    ;;
                ogv)
                    ffmpeg -y -i "$input_file" -c:v libtheora -c:a libvorbis "$output_file"
                    ;;
                *)
                    ffmpeg -y -i "$input_file" -c:v libx264 -c:a aac "$output_file"
                    ;;
            esac
        fi

    else
        ffmpeg -y -i "$input_file" "$output_file"
    fi

    status=$?
    if [ $status -ne 0 ]; then
        any_failed=1
    fi

    echo $((current * 100 / total_files))

done
) | zenity --progress \
    --title="Batch Conversion" \
    --percentage=0 \
    --auto-close

if [ $? -ne 0 ]; then
    zenity --warning --text="Conversion cancelled."
    exit 1
fi

if [ $any_failed -eq 1 ]; then
    zenity --warning --text="Some conversions failed."
else
    zenity --info --text="Conversion complete."
fi
