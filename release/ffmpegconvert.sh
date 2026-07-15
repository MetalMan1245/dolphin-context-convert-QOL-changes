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

########################################
# SETUP FIFO FOR ZENITY
########################################

FIFO=$(mktemp -u)
mkfifo "$FIFO"

# start zenity reading from FIFO
zenity --progress \
  --title="ffmpeg Conversion" \
  --percentage=0 \
  --auto-close <"$FIFO" &
ZENITY_PID=$!

exec 3>"$FIFO" # open write channel
rm "$FIFO"     # cleanup name (pipe stays open)

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

  if [ "$output_extension" == "alac" ]; then
    output_file="$dir/${filename_noext}.m4a"
  else
    output_file="$dir/${filename_noext}.${output_extension}"
  fi

  ########################################
  # UPDATE UI TEXT
  ########################################

  echo "# Converting ($current/$total_files)\n$filename" >&3

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
  # BUILD COMMAND (unchanged)
  ########################################

  if [[ " ${video_exts[@]} " =~ " ${input_extension} " ]]; then
    can_copy=0

    case "$output_extension" in
    mp4)
      [[ "$video_codec" =~ ^(h264|hevc|mpeg4)$ && "$audio_codec" =~ ^(aac|mp3)$ ]] && can_copy=1
      ;;
    mkv) can_copy=1 ;;
    webm)
      [[ "$video_codec" =~ ^(vp8|vp9|av1)$ && "$audio_codec" =~ ^(opus|vorbis)$ ]] && can_copy=1
      ;;
    avi)
      [[ "$video_codec" =~ ^(mpeg4|h264)$ && "$audio_codec" =~ ^(mp3)$ ]] && can_copy=1
      ;;
    mpg | mpeg)
      [[ "$video_codec" =~ ^(mpeg1video|mpeg2video)$ ]] && can_copy=1
      ;;
    ogv)
      [[ "$video_codec" == "theora" ]] && can_copy=1
      ;;
    esac

    if [ $can_copy -eq 1 ]; then
      ffmpeg_cmd=(ffmpeg -y -i "$input_file" -c copy "$output_file")
    else
      case "$output_extension" in
      mp4 | mkv | mov)
        ffmpeg_cmd=(ffmpeg -y -i "$input_file" -c:v libx264 -crf 18 -preset medium -c:a aac "$output_file")
        ;;
      webm)
        ffmpeg_cmd=(ffmpeg -y -i "$input_file" -c:v libvpx-vp9 -c:a libopus "$output_file")
        ;;
      avi)
        ffmpeg_cmd=(ffmpeg -y -i "$input_file" -c:v libx264 -c:a mp3 "$output_file")
        ;;
      mpg | mpeg)
        ffmpeg_cmd=(ffmpeg -y -i "$input_file" -c:v mpeg2video -c:a mp2 "$output_file")
        ;;
      ogv)
        ffmpeg_cmd=(ffmpeg -y -i "$input_file" -c:v libtheora -c:a libvorbis "$output_file")
        ;;
      *)
        ffmpeg_cmd=(ffmpeg -y -i "$input_file" -c:v libx264 -c:a aac "$output_file")
        ;;
      esac
    fi
  else
    ffmpeg_cmd=(ffmpeg -y -i "$input_file" "$output_file")
  fi

  ########################################
  # RUN FFMPEG WITH REAL CANCEL
  ########################################

  "${ffmpeg_cmd[@]}" &
  FFMPEG_PID=$!

  while kill -0 $FFMPEG_PID 2>/dev/null; do

    # 🔥 instant cancel
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
  fi

  ########################################
  # UPDATE PROGRESS BAR
  ########################################

  percent=$((current * 100 / total_files))
  echo "$percent" >&3
done

########################################
# CLEANUP
########################################

exec 3>&- # close FIFO

wait $ZENITY_PID 2>/dev/null

if [ $any_failed -eq 1 ]; then
  zenity --warning --text="Some conversions failed."
else
  zenity --info --text="Conversion complete."
fi
