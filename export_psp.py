import sys
import json
import base64
import io
import os
from PIL import Image

def export_psp(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    for clip in data.get('Clips', []):
        clip_name = clip.get('Name', 'Unnamed_Clip')
        frames_images = []

        for frame in clip.get('Frames', []):
            layers = frame.get('Layers', [])
            if not layers:
                continue

            first_layer = layers[0]
            history_json_str = first_layer.get('_historyJson', '{}')
            try:
                history_data = json.loads(history_json_str)
            except json.JSONDecodeError:
                continue

            source = history_data.get('_source', '')
            if not source:
                continue

            if ',' in source:
                base64_data = source.split(',', 1)[1]
            else:
                base64_data = source

            image_bytes = base64.b64decode(base64_data)
            img = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
            frames_images.append(img)

        if not frames_images:
            print(f"No frames found for clip '{clip_name}'")
            continue

        total_width = sum(img.width for img in frames_images)
        max_height = max(img.height for img in frames_images)

        spritesheet = Image.new('RGBA', (total_width, max_height), (0, 0, 0, 0))

        current_x = 0
        for img in frames_images:
            spritesheet.paste(img, (current_x, 0))
            current_x += img.width

        # Clean clip name to avoid invalid characters
        safe_clip_name = "".join([c for c in clip_name if c.isalpha() or c.isdigit() or c==' ' or c=='-' or c=='_']).rstrip()
        out_filename = f"{safe_clip_name}.png"
        spritesheet.save(out_filename)
        print(f"Saved {out_filename}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python export_psp.py <file.psp>")
        sys.exit(1)

    export_psp(sys.argv[1])
