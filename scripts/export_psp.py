import sys
import json
import base64
import io
import os
import struct
from PIL import Image, ImageDraw

def apply_actions(img, actions):
    """
    Applies an array of PixelStudio actions to the given PIL Image.
    """
    for action in actions:
        #print(action)
        tool = action.get('Tool')
        
        if tool == 6:
            # Tool 6: Eraser rectangle
            meta_str = action.get('Meta', '{}')
            try:
                meta = json.loads(meta_str)
            except json.JSONDecodeError:
                continue
                
            from_pt = meta.get('From', {})
            to_pt = meta.get('To', {})
            
            x1 = from_pt.get('X', 0)
            y1 = img.height - from_pt.get('Y', 0)
            x2 = to_pt.get('X', 0)
            y2 = img.height - to_pt.get('Y', 0)
            
            min_x, max_x = min(x1, x2), max(x1, x2)
            min_y, max_y = min(y1, y2), max(y1, y2)
            
            for y in range(min_y, max_y + 1):
                for x in range(min_x, max_x + 1):
                    if 0 <= x < img.width and 0 <= y < img.height:
                        img.putpixel((x, y), (0, 0, 0, 0))

        # Tools that may use specific pixel positions and colors
        elif tool in (0, 2, 10, 1, 3):
            pos_str = action.get('Positions', '')
            col_str = action.get('Colors', '')
            
            if not pos_str:
                continue
                
            pos_bytes = base64.b64decode(pos_str)
            positions = []
            for i in range(0, len(pos_bytes), 4):
                if i+4 <= len(pos_bytes):
                    x, y = struct.unpack('<HH', pos_bytes[i:i+4])
                    y = img.height - y
                    positions.append((x, y))
            
            colors = []
            if col_str:
                col_bytes = base64.b64decode(col_str)
                for i in range(0, len(col_bytes), 4):
                    if i+4 <= len(col_bytes):
                        r, g, b, a = struct.unpack('<BBBB', col_bytes[i:i+4])
                        colors.append((r,g,b,a))
            
            if tool == 3 and colors:
                for i, (x, y) in enumerate(positions):
                    color = colors[i] if i < len(colors) else colors[-1]
                    if 0 <= x < img.width and 0 <= y - 1 < img.height:
                        ImageDraw.floodfill(img, (x, y - 1), color)
            elif colors or tool == 2:
                # Use putpixel to apply colors to specified positions
                for i, (x, y) in enumerate(positions):
                    if tool == 2:
                        color = (0, 0, 0, 0)
                    else:
                        color = colors[i] if i < len(colors) else colors[-1]
                        
                    if 0 <= x < img.width and 0 <= y < img.height:
                        img.putpixel((x, y - 1), color)
                        
        elif tool == 20:
            # Selection/Paste
            meta_str = action.get('Meta', '{}')
            try:
                meta = json.loads(meta_str)
            except json.JSONDecodeError:
                continue
                
            #print(action)

            rect = meta.get('RectSource', {})
            from_pt = rect.get('From', {})
            to_pt = rect.get('To', {})
            
            x1 = from_pt.get('X', 0)
            y1 = img.height - from_pt.get('Y', 0)
            x2 = to_pt.get('X', 0)
            y2 = img.height - to_pt.get('Y', 0)
            
            min_x, max_x = min(x1, x2), max(x1, x2)
            min_y, max_y = min(y1, y2), max(y1, y2)
            
            for y in range(min_y, max_y + 1):
                for x in range(min_x, max_x + 1):
                    if 0 <= x < img.width and 0 <= y < img.height:
                        img.putpixel((x, y - 1), (0, 0, 0, 0))

            pixels_str = meta.get('Pixels', '')
            rect = meta.get('Rect', {})
            #rect_from = rect.get('To', {})
            rect_from = rect.get('From', {})
            x = rect_from.get('X', 0)
            y = rect_from.get('Y', 0)
            
            if pixels_str:
                try:
                    pixels_bytes = base64.b64decode(pixels_str)
                    paste_img = Image.open(io.BytesIO(pixels_bytes)).convert("RGBA")
                    # Use alpha_composite to properly blend the pasted image
                    img.alpha_composite(paste_img, (x, img.height - y - paste_img.height))
                except Exception as e:
                    print(f"Error applying Tool 20: {e}")

    return img


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
            
            # Apply any actions from history
            actions = history_data.get('Actions', [])
            if actions:
                img = apply_actions(img, actions)
                
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

