#!/bin/sh

# Source and destination
src="leaderboard-simulation.mkv"
dest="../$(basename "$src" .mkv).gif"
tmp="/tmp/$(basename "$src" .mkv)-fast.mkv"

# Extract a part of the video and speed up playback by 10x
ffmpeg -y -ss 00:00:23.000 -i "$src" -to 00:02:50.000 -filter:v "setpts=0.1*PTS" -an "$tmp"

# Convert to a 720p GIF with infinite loop
ffmpeg -y -i "$tmp" -vf "fps=2,scale=-1:720:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "$dest"
