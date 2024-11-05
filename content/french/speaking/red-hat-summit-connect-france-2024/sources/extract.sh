#!/bin/sh

# Source and destination
src="Platform-Day-2024.mp4"
dest="../mission-impossible-demo.mp4"

# Extract a part of the video
ffmpeg -y -ss 00:00:37.000 -i "$src" -to 00:00:09.500 -an "$dest"
