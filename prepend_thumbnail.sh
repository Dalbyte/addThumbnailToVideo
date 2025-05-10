#!/bin/bash

# 1. Video abfragen
read -p "Pfad zum Eingabevideo: " INPUT_VIDEO

if [ ! -f "$INPUT_VIDEO" ]; then
  echo "Datei nicht gefunden: $INPUT_VIDEO"
  exit 1
fi

# 2. FPS und Auflösung ermitteln
FPS=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate "$INPUT_VIDEO" | awk -F/ '{printf "%.2f", $1/$2}' | sed 's/,/./')
RESOLUTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
  -of csv=p=0:s=x "$INPUT_VIDEO")

echo "Ermittelte FPS: $FPS"
echo "Videoauflösung: $RESOLUTION"

# 3. Thumbnail-Bild abfragen
read -p "Pfad zum Thumbnail-Bild (PNG oder JPG): " THUMB_IMG

if [ ! -f "$THUMB_IMG" ]; then
  echo "Bild nicht gefunden: $THUMB_IMG"
  exit 1
fi

# Optional: Bild skalieren, falls Auflösung abweicht
SCALED_IMG="scaled_thumb.png"
ACTUAL_RES=$(identify -format "%wx%h" "$THUMB_IMG" 2>/dev/null)

if [ "$ACTUAL_RES" != "$RESOLUTION" ]; then
  echo "Bild wird auf Videoauflösung $RESOLUTION skaliert..."
  convert "$THUMB_IMG" -resize "$RESOLUTION\!" "$SCALED_IMG"
else
  cp "$THUMB_IMG" "$SCALED_IMG"
fi

# 4. Thumbnail-Video mit 3 Frames erzeugen
THUMB_VIDEO="thumb_video.mp4"
ffmpeg -y -loop 1 -i "$SCALED_IMG" -frames:v 3 -r "$FPS" -c:v libx264 -crf 24 -pix_fmt yuv420p "$THUMB_VIDEO"

# 5. Concat

read -p "Output Videonamen (Path/name.mp4): " VIDEO_NAME

ffmpeg -i "$THUMB_VIDEO" -i "$INPUT_VIDEO" \
-filter_complex "[0:v:0][1:v:0]concat=n=2:v=1:a=0[outv]; [1:a:0]anull[aout]" \
-map "[outv]" -map "[aout]" -c:v libx264  -crf 24 -c:a aac "$VIDEO_NAME"

echo "✅ Fertig: output.mp4 wurde erstellt."
