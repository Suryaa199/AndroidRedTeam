#!/bin/bash
# Generate synthetic face frames for pipeline verification.
# Draws a simple geometric face that ML Kit may detect.
# No real face images needed -- useful for privacy-conscious testing.
#
# Usage: ./generate-synthetic-face.sh [output_dir] [count]
#   output_dir: directory for PNGs (default: ./synthetic_face)
#   count: number of frames to generate (default: 30)
#
# Requires: Python 3, Pillow (pip install Pillow)

set -euo pipefail

OUTPUT_DIR="${1:-./synthetic_face}"
COUNT="${2:-30}"

python3 -c "import PIL" 2>/dev/null || { echo "ERROR: Pillow not found. Install with: pip install Pillow"; exit 1; }

mkdir -p "$OUTPUT_DIR"

echo "Generating $COUNT synthetic face frames in $OUTPUT_DIR..."

python3 -c "
import random
from PIL import Image, ImageDraw

count = int('$COUNT')
out = '$OUTPUT_DIR'

for i in range(1, count + 1):
    img = Image.new('RGB', (640, 480), (200, 180, 160))
    draw = ImageDraw.Draw(img)

    # Add slight per-frame variation to simulate natural drift
    ox = random.uniform(-3, 3)
    oy = random.uniform(-3, 3)

    # Face oval
    draw.ellipse([200+ox, 60+oy, 440+ox, 400+oy],
                 fill=(220, 195, 170), outline=(180, 160, 140), width=2)

    # Eyes
    draw.ellipse([260+ox, 160+oy, 310+ox, 195+oy], fill=(255, 255, 255))
    draw.ellipse([330+ox, 160+oy, 380+ox, 195+oy], fill=(255, 255, 255))
    draw.ellipse([275+ox, 170+oy, 295+ox, 190+oy], fill=(60, 40, 30))
    draw.ellipse([345+ox, 170+oy, 365+ox, 190+oy], fill=(60, 40, 30))

    # Nose
    draw.polygon([(318+ox, 220+oy), (305+ox, 275+oy), (335+ox, 275+oy)],
                 fill=(200, 175, 155))

    # Mouth
    draw.arc([285+ox, 290+oy, 355+ox, 340+oy],
             start=0, end=180, fill=(180, 100, 100), width=3)

    # Eyebrows
    draw.arc([255+ox, 140+oy, 315+ox, 170+oy],
             start=180, end=360, fill=(120, 90, 70), width=3)
    draw.arc([325+ox, 140+oy, 385+ox, 170+oy],
             start=180, end=360, fill=(120, 90, 70), width=3)

    img.save(f'{out}/{i:03d}.png')

print(f'Generated {count} frames in {out}/')
"

echo "Done. Generated $COUNT synthetic face frames."
echo "Push to device with: adb push $OUTPUT_DIR/ /sdcard/poc_frames/face_neutral/"
