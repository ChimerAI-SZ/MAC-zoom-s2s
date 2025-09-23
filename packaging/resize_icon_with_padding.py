#!/usr/bin/env python3
"""
Resize icon with proper padding for macOS iconset
Keeps icon content intact, just scales down and adds padding
"""

from PIL import Image
import os

def resize_with_padding(source_path, target_size, padding_percent=10):
    """
    Resize image with padding
    padding_percent: percentage of target size to use as padding (10 = 10% padding)
    """
    # Open source image
    img = Image.open(source_path)
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Calculate content size (target size minus padding)
    padding = int(target_size * padding_percent / 100)
    content_size = target_size - (padding * 2)
    
    # Resize image to fit in content area while maintaining aspect ratio
    img.thumbnail((content_size, content_size), Image.Resampling.LANCZOS)
    
    # Create new image with target size and transparent background
    new_img = Image.new('RGBA', (target_size, target_size), (0, 0, 0, 0))
    
    # Calculate position to center the resized image
    x = (target_size - img.width) // 2
    y = (target_size - img.height) // 2
    
    # Paste resized image onto new image
    new_img.paste(img, (x, y), img)
    
    return new_img

def main():
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
    
    print("🎨 Generating iconset with proper padding...")
    
    # Check source exists
    if not os.path.exists(source_icon):
        print(f"❌ Error: {source_icon} not found!")
        return
    
    # Create iconset directory if needed
    os.makedirs(iconset_dir, exist_ok=True)
    
    # Generate all sizes
    for filename, size in icon_sizes:
        output_path = os.path.join(iconset_dir, filename)
        
        # Create resized image with padding
        resized = resize_with_padding(source_icon, size, padding_percent=10)
        
        # Save with PNG optimization
        resized.save(output_path, "PNG", optimize=True)
        print(f"  ✅ {filename} ({size}x{size}) - with 10% padding")
    
    print(f"\n✅ All icons generated with proper padding in {iconset_dir}/")
    print("\nNext step: iconutil -c icns BabelAI.iconset")

if __name__ == "__main__":
    main()