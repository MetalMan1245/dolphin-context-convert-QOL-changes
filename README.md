# KDE Plasma FFmpeg Converter

Right-click to convert audio/video/images in KDE Plasma. Uses FFmpeg. Fixed instructions, new features listed at the bottom.

## Requirements
1. ffmpeg
2. zenity

## Install

Run `ffmpegconvert-installer.desktop` (if this fails run `ffmpeg-install_remote.sh` in Terminal)

WARNING: The uninstall portion of the installer should be fine now, but I did completely break a KDE Neon install by running an earlier version of it, so use at your own risk.  I would recommend deleting .desktop entries and the script manually if you really want this gone, or just disable them in Dolphin since the files are extremely small (this entire repo is well under 1 MB as of writing this).

For a manual install:
1. Put `ffmpegconvert.sh` in `~/.local/bin`
2. Put `.desktop` files in `~/.local/share/kio/servicemenus/`. (Substitute `/usr/share/kio/servicemenus` for a global install)
3. `chmod +x ~/Scripts/ffmpegconvert.sh`
4. Edit `.desktop` files if you want the script elsewhere.

## Use

Right-click file in Dolphin -> Choose format. Can converet video to mp3 as a bonus

## Formats

- Audio: MP3, AAC, OGG, WMA, FLAC, ALAC, WAV, AIFF
- Video: MP4, AVI, MOV, MKV, WMV, FLV, MPG, OGV
- Image: JPG, PNG, GIF, BMP, TIFF, WEBP, EPS, RAW, ICO, PSD (only supports converting from)

## New Features

- Easy installer
- Added batch conversion support
- Added codec copy support for videos, if the new container supports the old video and audio formats, conversion should be relatively instant
- Sequential processing with updated GUI, working cancel button, and per-conversion progress.
- For a specific Davinci Resolve compatibility converter see my other project `https://github.com/MetalMan1245/DaVinci-Resolve-Video-Converter-for-Dolphin-File-Manager`

## Upcoming Features/Bugfixes

- Cancel button still broken on other systems (works fine on my test system but no others I've tried)
- Multiple audio streams not supported

## Disclaimers

THIS IS VIBE CODED.  I am not a real programmer and as such AI was used to create this, therefore I do not promise quality, repeatability, or robustness.

I am happy with where the script is now and it will probably only be bugfixes from here on out.
