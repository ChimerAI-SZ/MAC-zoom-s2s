#!/usr/bin/env python3
"""
Generate all required icon sizes for macOS iconset from icon-256@2x.png
"""

from PIL import Image
import os

# Source icon
source_icon = "icon-256@2x.png"
iconset_dir = "BabelAI.iconset"

# Icon sizes required for macOS iconset
icon_sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

def main():
    print("🎨 Generating iconset from icon-256@2x.png...")
    
    # Load source image
    if not os.path.exists(source_icon):
        print(f"❌ Error: {source_icon} not found!")
        return
    
    img = Image.open(source_icon)
    print(f"✅ Loaded source icon: {img.size[0]}x{img.size[1]}")
    
    # Create iconset directory if it doesn't exist
    os.makedirs(iconset_dir, exist_ok=True)
    
    # Generate all sizes
    for filename, size in icon_sizes:
        output_path = os.path.join(iconset_dir, filename)
        
        # Resize image with high quality
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Save with PNG optimization
        resized.save(output_path, "PNG", optimize=True)
        print(f"  ✅ {filename} ({size}x{size})")
    
    print(f"\n✅ All icons generated in {iconset_dir}/")
    print("\nNext step: iconutil -c icns BabelAI.iconset")

if __name__ == "__main__":
    main()