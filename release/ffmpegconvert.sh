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

########################################
# DETERMINE TOTAL OUTPUT FILE COUNT
########################################
#
# Normally one input file produces one output file.
# Audio files with more than 2 channels produce one
# output file per channel.
#
########################################

total_outputs=0

for input_file in "$@"; do

    filename=$(basename -- "$input_file")
    input_extension="$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')"

    # Check whether this file has an audio stream.
    audio_channels=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=channels \
        -of csv=p=0 \
        "$input_file" 2>/dev/null || true)

    if [[ "$audio_channels" =~ ^[0-9]+$ ]] && [ "$audio_channels" -gt 2 ]; then
        total_outputs=$((total_outputs + audio_channels))
    else
        total_outputs=$((total_outputs + 1))
    fi

done

if [ "$total_outputs" -eq 0 ]; then
    zenity --error --text="No output files to process."
    exit 1
fi

########################################
# SETUP FIFO FOR ZENITY
########################################

FIFO=$(mktemp -u)
mkfifo "$FIFO"

zenity --progress \
    --title="ffmpeg Conversion" \
    --percentage=0 \
    --auto-close \
    < "$FIFO" &

ZENITY_PID=$!

exec 3> "$FIFO"
rm "$FIFO"

########################################
# PROGRESS TRACKING
########################################

completed_outputs=0

update_progress() {
    completed_outputs=$((completed_outputs + 1))

    percent=$((completed_outputs * 100 / total_outputs))

    echo "$percent" >&3
}

########################################
# MAIN LOOP
########################################

current=0

for input_file in "$@"; do

    current=$((current + 1))

    filename=$(basename -- "$input_file")
    filename_noext="${filename%.*}"
    input_extension="$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')"
    dir=$(dirname "$input_file")

    ########################################
    # DETECT AUDIO STREAM
    ########################################

    audio_channels=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=channels \
        -of csv=p=0 \
        "$input_file" 2>/dev/null || true)

    audio_layout=$(ffprobe -v error \
        -select_streams a:0 \
        -show_entries stream=channel_layout \
        -of csv=p=0 \
        "$input_file" 2>/dev/null || true)

    ########################################
    # UPDATE UI TEXT
    ########################################

    echo "# Converting ($current/$#)\n$filename" >&3

    ########################################
    # MULTICHANNEL AUDIO
    ########################################
    #
    # Any audio source with more than two
    # channels is split into individual mono
    # files.
    #
    # The channel layout is deliberately NOT
    # assumed. Each channel is selected by
    # numerical channel index using the pan
    # filter.
    #
    ########################################

    if [[ "$audio_channels" =~ ^[0-9]+$ ]] && [ "$audio_channels" -gt 2 ]; then

        echo "# $audio_channels channels detected${audio_layout:+ ($audio_layout)}" >&3

        split_failed=0

        for ((channel=0; channel<audio_channels; channel++)); do

            channel_number=$((channel + 1))

            if [ "$output_extension" == "alac" ]; then
                output_file="$dir/${filename_noext}-chan${channel_number}.m4a"
            else
                output_file="$dir/${filename_noext}-chan${channel_number}.${output_extension}"
            fi

            echo "# Converting ($current/$#) — channel $channel_number/$audio_channels\n$filename" >&3

            ########################################
            # SPLIT ONE CHANNEL TO MONO
            ########################################
            #
            # pan=mono|c0=cN selects channel N
            # without relying on a particular
            # channel layout.
            #
            ########################################

            case "$output_extension" in

                flac)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -map 0:a:0
                        -af "pan=mono|c0=c${channel}"
                        -c:a flac
                        "$output_file"
                    )
                    ;;

                alac)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -map 0:a:0
                        -af "pan=mono|c0=c${channel}"
                        -c:a alac
                        "$output_file"
                    )
                    ;;

                mp3)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -map 0:a:0
                        -af "pan=mono|c0=c${channel}"
                        -c:a libmp3lame
                        "$output_file"
                    )
                    ;;

                ogg)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -map 0:a:0
                        -af "pan=mono|c0=c${channel}"
                        -c:a libvorbis
                        "$output_file"
                    )
                    ;;

                opus)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -map 0:a:0
                        -af "pan=mono|c0=c${channel}"
                        -c:a libopus
                        "$output_file"
                    )
                    ;;

                wav)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -map 0:a:0
                        -af "pan=mono|c0=c${channel}"
                        -c:a pcm_s16le
                        "$output_file"
                    )
                    ;;

                *)
                    # Generic audio fallback.
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -map 0:a:0
                        -af "pan=mono|c0=c${channel}"
                        "$output_file"
                    )
                    ;;

            esac

            ########################################
            # RUN FFMPEG WITH REAL CANCEL
            ########################################

            "${ffmpeg_cmd[@]}" &
            FFMPEG_PID=$!

            while kill -0 $FFMPEG_PID 2>/dev/null; do

                # Instant cancel
                if ! kill -0 $ZENITY_PID 2>/dev/null; then
                    kill -9 $FFMPEG_PID 2>/dev/null
                    rm -f "$output_file"
                    exec 3>&-
                    zenity --warning --text="Conversion cancelled."
                    exit 1
                fi

                sleep 0.2

            done

            wait $FFMPEG_PID
            status=$?

            if [ $status -ne 0 ]; then
                any_failed=1
                split_failed=1
                rm -f "$output_file"
            fi

            update_progress

        done

        continue

    fi

    ########################################
    # NORMAL SINGLE-FILE CONVERSION
    ########################################

    if [ "$output_extension" == "alac" ]; then
        output_file="$dir/${filename_noext}.m4a"
    else
        output_file="$dir/${filename_noext}.${output_extension}"
    fi

    ########################################
    # DETECT CODECS
    ########################################

    video_codec=""
    audio_codec=""

    if [[ " ${video_exts[@]} " =~ " ${input_extension} " ]]; then

        video_codec=$(ffprobe -v error \
            -select_streams v:0 \
            -show_entries stream=codec_name \
            -of csv=p=0 \
            "$input_file" 2>/dev/null || true)

        audio_codec=$(ffprobe -v error \
            -select_streams a:0 \
            -show_entries stream=codec_name \
            -of csv=p=0 \
            "$input_file" 2>/dev/null || true)

    fi

    ########################################
    # BUILD COMMAND
    ########################################

    if [[ " ${video_exts[@]} " =~ " ${input_extension} " ]]; then

        can_copy=0

        case "$output_extension" in

            mp4)
                [[ "$video_codec" =~ ^(h264|hevc|mpeg4)$ &&
                   "$audio_codec" =~ ^(aac|mp3)$ ]] && can_copy=1
                ;;

            mkv)
                can_copy=1
                ;;

            webm)
                [[ "$video_codec" =~ ^(vp8|vp9|av1)$ &&
                   "$audio_codec" =~ ^(opus|vorbis)$ ]] && can_copy=1
                ;;

            avi)
                [[ "$video_codec" =~ ^(mpeg4|h264)$ &&
                   "$audio_codec" =~ ^(mp3)$ ]] && can_copy=1
                ;;

            mpg|mpeg)
                [[ "$video_codec" =~ ^(mpeg1video|mpeg2video)$ ]] && can_copy=1
                ;;

            ogv)
                [[ "$video_codec" == "theora" ]] && can_copy=1
                ;;

        esac

        if [ $can_copy -eq 1 ]; then

            ffmpeg_cmd=(
                ffmpeg
                -y
                -i "$input_file"
                -c copy
                "$output_file"
            )

        else

            case "$output_extension" in

                mp4|mkv|mov)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -c:v libx264
                        -crf 18
                        -preset medium
                        -c:a aac
                        "$output_file"
                    )
                    ;;

                webm)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -c:v libvpx-vp9
                        -c:a libopus
                        "$output_file"
                    )
                    ;;

                avi)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -c:v libx264
                        -c:a mp3
                        "$output_file"
                    )
                    ;;

                mpg|mpeg)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -c:v mpeg2video
                        -c:a mp2
                        "$output_file"
                    )
                    ;;

                ogv)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -c:v libtheora
                        -c:a libvorbis
                        "$output_file"
                    )
                    ;;

                *)
                    ffmpeg_cmd=(
                        ffmpeg
                        -y
                        -i "$input_file"
                        -c:v libx264
                        -c:a aac
                        "$output_file"
                    )
                    ;;

            esac

        fi

    else

        ffmpeg_cmd=(
            ffmpeg
            -y
            -i "$input_file"
            "$output_file"
        )

    fi

    ########################################
    # RUN FFMPEG WITH REAL CANCEL
    ########################################

    "${ffmpeg_cmd[@]}" &
    FFMPEG_PID=$!

    while kill -0 $FFMPEG_PID 2>/dev/null; do

        # Instant cancel
        if ! kill -0 $ZENITY_PID 2>/dev/null; then
            kill -9 $FFMPEG_PID 2>/dev/null
            rm -f "$output_file"
            exec 3>&-
            zenity --warning --text="Conversion cancelled."
            exit 1
        fi

        sleep 0.2

    done

    wait $FFMPEG_PID
    status=$?

    if [ $status -ne 0 ]; then
        any_failed=1
        rm -f "$output_file"
    fi

    update_progress

done

########################################
# CLEANUP
########################################

exec 3>&-

wait $ZENITY_PID 2>/dev/null

if [ $any_failed -eq 1 ]; then
    zenity --warning --text="Some conversions failed."
else
    zenity --info --text="Conversion complete."
fi
