#!/usr/bin/env python3
"""
Create transparent BabelAI icon with proper sizing - 60% of canvas
"""

from PIL import Image, ImageDraw
import os

def create_babel_icon(size):
    """Create a BabelAI icon with transparent background"""
    # Create fully transparent image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Scale factor for icon to be 60% of canvas size
    scale = 0.6
    
    # Calculate dimensions with scaling
    effective_size = size * scale
    offset = (size - effective_size) / 2
    
    # Tower dimensions
    tower_width = effective_size * 0.45
    tower_height = effective_size * 0.55
    tower_x = (size - tower_width) / 2
    tower_y = offset + effective_size * 0.2
    
    # Draw tower layers (babel tower inspired) - solid colors, no transparency
    # Base layer (largest)
    base_y = tower_y + tower_height * 0.65
    base_width = tower_width
    base_x = tower_x
    draw.rounded_rectangle(
        [(base_x, base_y), 
         (base_x + base_width, base_y + tower_height * 0.18)],
        radius=max(1, int(size * 0.01)),
        fill=(74, 85, 104, 255)  # #4A5568 fully opaque
    )
    
    # Middle layer
    mid_width = tower_width * 0.75
    mid_x = tower_x + (tower_width - mid_width) / 2
    mid_y = tower_y + tower_height * 0.4
    draw.rounded_rectangle(
        [(mid_x, mid_y),
         (mid_x + mid_width, mid_y + tower_height * 0.18)],
        radius=max(1, int(size * 0.01)),
        fill=(113, 128, 150, 255)  # #718096 fully opaque
    )
    
    # Top layer
    top_width = tower_width * 0.5
    top_x = tower_x + (tower_width - top_width) / 2
    top_y = tower_y + tower_height * 0.15
    draw.rounded_rectangle(
        [(top_x, top_y),
         (top_x + top_width, top_y + tower_height * 0.18)],
        radius=max(1, int(size * 0.01)),
        fill=(156, 163, 175, 255)  # #9CA3AF fully opaque
    )
    
    # Peak triangle (tower top)
    peak_height = tower_height * 0.15
    peak_points = [
        (size/2, tower_y),  # top point
        (top_x - top_width * 0.1, top_y),  # left
        (top_x + top_width + top_width * 0.1, top_y)  # right
    ]
    draw.polygon(peak_points, fill=(203, 213, 225, 255))  # #CBD5E1 fully opaque
    
    # Translation waves - simplified and cleaner
    wave_y = size * 0.5
    
    # Left wave (single clean arc)
    if size >= 32:  # Only draw waves on larger icons
        wave_thickness = max(1, int(size * 0.015))
        # Left side waves
        draw.arc(
            [(size * 0.15, wave_y - size * 0.03),
             (size * 0.3, wave_y + size * 0.03)],
            start=200, end=340,
            fill=(96, 165, 250, 220), width=wave_thickness
        )
        # Right side waves
        draw.arc(
            [(size * 0.7, wave_y - size * 0.03),
             (size * 0.85, wave_y + size * 0.03)],
            start=200, end=340,
            fill=(96, 165, 250, 220), width=wave_thickness
        )
    
    # Central AI dot - positioned on the tower
    center_x, center_y = size/2, tower_y + tower_height * 0.3
    dot_size = max(2, size * 0.025)
    draw.ellipse(
        [(center_x - dot_size, center_y - dot_size),
         (center_x + dot_size, center_y + dot_size)],
        fill=(96, 165, 250, 255)  # #60A5FA fully opaque
    )
    
    # Subtle glow around dot (only on larger icons)
    if size >= 64:
        ring_size = dot_size * 1.5
        draw.ellipse(
            [(center_x - ring_size, center_y - ring_size),
             (center_x + ring_size, center_y + ring_size)],
            outline=(96, 165, 250, 100), width=max(1, int(size * 0.008))
        )
    
    return img


def verify_transparency(img, size):
    """Verify that the image has proper transparency"""
    # Check corners for transparency
    corners = [
        (0, 0),
        (size-1, 0),
        (0, size-1),
        (size-1, size-1)
    ]
    
    for x, y in corners:
        pixel = img.getpixel((x, y))
        if len(pixel) < 4 or pixel[3] != 0:
            print(f"  ⚠️  Warning: Corner at ({x},{y}) is not fully transparent: {pixel}")
            return False
    
    return True


def main():
    # Clean up old files
    print("Cleaning up old icon files...")
    for file in ["icon_128x128.png", "icon_256x256.png", "icon_512x512.png", "icon_1024x1024.png"]:
        if os.path.exists(file):
            os.remove(file)
            print(f"  Removed old {file}")
    
    # Create iconset directory
    iconset_path = "BabelAI.iconset"
    if os.path.exists(iconset_path):
        import shutil
        shutil.rmtree(iconset_path)
    os.makedirs(iconset_path, exist_ok=True)
    
    print("\nGenerating new transparent icons...")
    
    # Define all required sizes for macOS icons
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
    
    for size, filename in icon_specs:
        # Create icon
        img = create_babel_icon(size)
        output_path = os.path.join(iconset_path, filename)
        img.save(output_path, 'PNG', optimize=True)
        
        # Verify transparency
        is_transparent = verify_transparency(img, size)
        status = "✅" if is_transparent else "⚠️"
        print(f"{status} Created {filename} ({size}x{size})")
    
    # Also create standalone icons in specific sizes for verification
    print("\nCreating standalone icons for verification...")
    for size in [128, 256, 512, 1024]:
        img = create_babel_icon(size)
        filename = f"icon_{size}x{size}.png"
        img.save(filename, 'PNG', optimize=True)
        
        # Verify transparency
        is_transparent = verify_transparency(img, size)
        status = "✅" if is_transparent else "⚠️"
        print(f"{status} Created standalone {filename}")
    
    print(f"\n✅ Iconset created in {iconset_path}/")
    print("Next step: Run 'iconutil -c icns BabelAI.iconset' to create .icns file")
    print("\nUse Read tool to verify the generated icons visually before proceeding!")


if __name__ == "__main__":
    main()