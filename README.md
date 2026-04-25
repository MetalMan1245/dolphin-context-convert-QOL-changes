# KDE Plasma FFmpeg Converter

Right-click to convert audio/video/images in KDE Plasma. Uses FFmpeg. Fixed instructions, new features listed at the bottom.

## Requirements
1. ffmpeg
2. zenity
3. imagemagick

## Install

1. Put `ffmpegconvert.sh` in `~/Scripts`
2. Put `.desktop` files in `~/.local/share/kio/servicemenus/`. (Substitute `/usr/share/kio/servicemenus` for non-KDE native distros)
3. `chmod +x ~/Scripts/ffmpegconvert.sh`
4. Edit `.desktop` files if you want the script elsewhere.

## Use

Right-click file in Dolphin -> Choose format. Can converet video to mp3 as a bonus

## Formats

- Audio: MP3, AAC, OGG, WMA, FLAC, ALAC, WAV, AIFF
- Video: MP4, AVI, MOV, MKV, WMV, FLV, MPG, OGV
- Image: JPG, PNG, GIF, BMP, TIFF, WEBP, EPS, RAW, ICO, PSD (only supports converting from)

## New Features

- Added batch conversion support
- Added codec copy support for videos, if the new container supports the old video and audio formats, conversion should be relatively instant
- Sequential processing with updated GUI, working cancel button, and per-conversion progress.
- For a specific Davinci Resolve compatibility converter see my other project `https://github.com/MetalMan1245/DaVinci-Resolve-Video-Converter-for-Dolphin-File-Manager`

## Upcoming Features/Bugfixes

- Cancel button still broken on non-KDE distros
- Multiple audio streams not supported

- Installer script

## Disclaimers

THIS IS VIBE CODED.  I am not a real programmer and as such AI was used to create this, therefore I do not promise quality, repeatability, or robustness.

I am happy with where the script is now and it will probably only be bugfixes from here on out.
