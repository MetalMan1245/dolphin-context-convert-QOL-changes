# KDE Plasma FFmpeg Converter

Right-click to convert audio/video/images in KDE Plasma. Uses FFmpeg. Fixed instructions, new features listed at the bottom.

## Requirements
1. ffmpeg
2. zenity
3. imagemagick

## Install

1. Put `ffmpegconvert.sh` in `~/Scripts`
2. Put `.desktop` files in `~/.local/share/kio/servicemenus/`.
3. `chmod +x ~/Scripts/ffmpegconvert.sh`
4. Edit `.desktop` files if you want the script elsewhere.

## Use

Right-click file in Dolphin -> Choose format. Can converet video to mp3 as a bonus

## Formats

- Audio: MP3, AAC, OGG, WMA, FLAC, ALAC, WAV, AIFF
- Video: MP4, AVI, MOV, MKV, WMV, FLV, MPG, OGV
- Image: JPG, PNG, GIF, BMP, TIFF, WEBP, EPS, RAW, ICO, PSD (only supports converting from)

## New Features

- Better defaults so video looks more visually lossless without tinkering
- Davinci Resolve special convert (converts to MP4 with AV1 and opus, confirmed working with Davinci Resolve)
- Added working cancel button

## Working On It

- Batch conversion
- Progress feedback from this branch 'https://github.com/alpikins/dolphin-context-convert'
