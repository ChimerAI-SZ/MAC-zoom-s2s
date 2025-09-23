#!/usr/bin/env python3
"""
Create proper macOS app icon with rounded rectangle background
"""

from PIL import Image, ImageDraw
import numpy as np
import os

def create_rounded_rectangle(size, radius, bg_color, border_width=0):
    """Create a rounded rectangle background"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Draw the rounded rectangle
    draw.rounded_rectangle(
        [(0, 0), (size-1, size-1)],
        radius=radius,
        fill=bg_color,
        outline=None
    )
    
    return img

def extract_tower_from_logo(image_path):
    """Extract the tower portion from the logo"""
    img = Image.open(image_path)
    
    # Convert to RGBA
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Get dimensions
    width, height = img.size
    
    # The tower is in the upper portion (without "BABEL AI" text)
    # Crop to approximately top 60% to get just the tower
    tower_height = int(height * 0.6)
    
    # Crop to tower portion
    cropped = img.crop((0, 0, width, tower_height))
    
    # Find the actual bounds of the tower (non-transparent/non-white pixels)
    data = np.array(cropped)
    
    # For each pixel, check if it's not white/near-white
    # (considering the logo has black lines on white background)
    gray = np.mean(data[:, :, :3], axis=2)  # Convert to grayscale
    mask = gray < 245  # Non-white pixels
    
    # Find bounds
    rows = np.any(mask, axis=1)
    cols = np.any(mask, axis=0)
    
    if rows.any() and cols.any():
        rmin, rmax = np.where(rows)[0][[0, -1]]
        cmin, cmax = np.where(cols)[0][[0, -1]]
        
        # Add small padding
        padding = 20
        rmin = max(0, rmin - padding)
        rmax = min(cropped.height - 1, rmax + padding)
        cmin = max(0, cmin - padding)
        cmax = min(cropped.width - 1, cmax + padding)
        
        # Crop to bounds
        tower = cropped.crop((cmin, rmin, cmax + 1, rmax + 1))
        
        # Convert white pixels to transparent
        tower_data = np.array(tower)
        white_mask = np.all(tower_data[:, :, :3] > 245, axis=2)
        tower_data[:, :, 3] = np.where(white_mask, 0, 255)
        
        return Image.fromarray(tower_data, 'RGBA')
    
    return cropped

def create_macos_icon(tower_img, size, background_color=(255, 255, 255, 255)):
    """Create a macOS-style icon with rounded rectangle background"""
    # Create rounded rectangle background
    # macOS icons typically use 18% corner radius
    corner_radius = int(size * 0.18)
    
    # Create the background
    icon = create_rounded_rectangle(size, corner_radius, background_color)
    
    # Calculate tower size (use 65% of available space)
    available_size = size * 0.65
    scale = available_size / max(tower_img.width, tower_img.height)
    
    new_width = int(tower_img.width * scale)
    new_height = int(tower_img.height * scale)
    
    # Resize tower with high quality
    tower_resized = tower_img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Center the tower on the background
    x_offset = (size - new_width) // 2
    y_offset = (size - new_height) // 2
    
    # Paste tower onto background
    icon.paste(tower_resized, (x_offset, y_offset), tower_resized)
    
    return icon

def main():
    print("🎨 Creating macOS-style BabelAI icon...")
    
    # Check if original logo exists
    logo_path = "babel_ai_logo.png"
    if not os.path.exists(logo_path):
        print(f"❌ Error: {logo_path} not found!")
        return
    
    # Extract tower from logo
    print("📐 Extracting tower from logo...")
    tower = extract_tower_from_logo(logo_path)
    tower.save("tower_extracted.png")
    print(f"   Tower size: {tower.size}")
    
    # Create iconset directory
    iconset_dir = "BabelAI.iconset"
    if os.path.exists(iconset_dir):
        import shutil
        shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir)
    
    # Define icon sizes for macOS
    icon_specs = [
        (16, 'icon_16x16.png'),
        (32, 'icon_16x16@2x.png'),
        (32, 'icon_32x32.png'),
        (64, 'icon_32x32@2x.png'),
        (128, 'icon_128x128.png'),
        (256, 'icon_128x128@2x.png'),
        (256, 'icon_256x256.png'),
        (512, 'icon_256x256@2x.png'),
        (512, 'icon_512x512.png'),
        (1024, 'icon_512x512@2x.png'),
    ]
    
    # Light background color (very light gray, almost white)
    bg_color = (248, 248, 248, 255)
    
    print(f"🎨 Creating icons with background color: RGB{bg_color[:3]}")
    
    # Generate all icon sizes
    for size, filename in icon_specs:
        icon = create_macos_icon(tower, size, bg_color)
        output_path = os.path.join(iconset_dir, filename)
        icon.save(output_path, 'PNG')
        print(f"   ✅ Created {filename} ({size}x{size})")
    
    # Create preview icons for verification
    print("\n📸 Creating preview icons...")
    for size in [128, 256, 512, 1024]:
        icon = create_macos_icon(tower, size, bg_color)
        preview_name = f"preview_icon_{size}.png"
        icon.save(preview_name, 'PNG')
        print(f"   ✅ Created {preview_name}")
    
    # Create app icon with slightly different styling
    print("\n🎯 Creating final app icon...")
    app_icon = create_macos_icon(tower, 1024, bg_color)
    app_icon.save("BabelAI_AppIcon.png", 'PNG')
    
    print("\n✅ Icon creation complete!")
    print("\n📝 Next steps:")
    print("1. Review preview_icon_512.png to check the design")
    print("2. If approved, run: iconutil -c icns BabelAI.iconset")
    print("3. Replace icons in the project")

if __name__ == "__main__":
    main()