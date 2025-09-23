#!/usr/bin/env python3
"""
Process the original BabelAI logo to create app icons
"""

from PIL import Image
import numpy as np
import os

def remove_white_background(image, threshold=245):
    """Convert white/near-white pixels to transparent"""
    # Convert to RGBA if not already
    if image.mode != 'RGBA':
        image = image.convert('RGBA')
    
    # Get image data as numpy array
    data = np.array(image)
    
    # Find white/near-white pixels (R, G, B all > threshold)
    rgb = data[:, :, :3]
    white_mask = np.all(rgb > threshold, axis=2)
    
    # Set alpha channel - white pixels become transparent
    data[:, :, 3] = np.where(white_mask, 0, 255)
    
    # Create new image
    return Image.fromarray(data, 'RGBA')


def extract_tower_portion(image):
    """Extract just the tower part (without text) from the logo"""
    # Convert to RGBA
    if image.mode != 'RGBA':
        image = image.convert('RGBA')
    
    # Get image dimensions
    width, height = image.size
    
    # The tower is in the upper portion, text is in the bottom
    # Crop to just the tower part (approximately top 70% of image)
    # Adjust these values based on the actual logo layout
    tower_height = int(height * 0.65)  # Take top 65% which should contain the tower
    
    # Crop: (left, top, right, bottom)
    cropped = image.crop((0, 0, width, tower_height))
    
    # Find the actual bounds of the tower (non-transparent pixels)
    data = np.array(cropped)
    alpha = data[:, :, 3]
    
    # Find rows and columns that have non-transparent pixels
    rows = np.any(alpha > 0, axis=1)
    cols = np.any(alpha > 0, axis=0)
    
    # Find the bounding box
    if rows.any() and cols.any():
        rmin, rmax = np.where(rows)[0][[0, -1]]
        cmin, cmax = np.where(cols)[0][[0, -1]]
        
        # Add small padding (5%)
        padding = int(min(rmax - rmin, cmax - cmin) * 0.05)
        rmin = max(0, rmin - padding)
        rmax = min(cropped.height - 1, rmax + padding)
        cmin = max(0, cmin - padding)
        cmax = min(cropped.width - 1, cmax + padding)
        
        # Crop to the tower bounds
        final_crop = cropped.crop((cmin, rmin, cmax + 1, rmax + 1))
        return final_crop
    
    return cropped


def create_square_icon(image, size):
    """Create a square icon with the tower centered"""
    # Create a new transparent square image
    icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Calculate scaling to fit the tower in the icon (using 70% of space)
    scale_factor = (size * 0.7) / max(image.width, image.height)
    
    # Resize the tower
    new_width = int(image.width * scale_factor)
    new_height = int(image.height * scale_factor)
    tower_resized = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Center the tower in the square
    x_offset = (size - new_width) // 2
    y_offset = (size - new_height) // 2
    
    # Paste the tower onto the transparent background
    icon.paste(tower_resized, (x_offset, y_offset), tower_resized)
    
    return icon


def verify_transparency(image, name="image"):
    """Verify that corners are transparent"""
    width, height = image.size
    corners = [
        (0, 0),
        (width-1, 0),
        (0, height-1),
        (width-1, height-1)
    ]
    
    all_transparent = True
    for x, y in corners:
        pixel = image.getpixel((x, y))
        if len(pixel) < 4 or pixel[3] != 0:
            print(f"  ⚠️  {name}: Corner at ({x},{y}) is not transparent: {pixel}")
            all_transparent = False
    
    if all_transparent:
        print(f"  ✅ {name}: All corners are transparent")
    
    return all_transparent


def main():
    # Load the original logo
    print("Loading original BabelAI logo...")
    original_path = "babel_ai_logo.png"
    
    if not os.path.exists(original_path):
        print(f"Error: {original_path} not found!")
        return
    
    original = Image.open(original_path)
    print(f"Original size: {original.size}")
    
    # Step 1: Remove white background
    print("\nRemoving white background...")
    transparent_logo = remove_white_background(original)
    transparent_logo.save("babel_logo_transparent_full.png")
    verify_transparency(transparent_logo, "Full logo with text")
    
    # Step 2: Extract tower portion
    print("\nExtracting tower portion...")
    tower_only = extract_tower_portion(transparent_logo)
    tower_only.save("babel_tower_only.png")
    print(f"Tower size: {tower_only.size}")
    verify_transparency(tower_only, "Tower only")
    
    # Step 3: Create iconset directory
    iconset_path = "BabelAI.iconset"
    if os.path.exists(iconset_path):
        import shutil
        shutil.rmtree(iconset_path)
    os.makedirs(iconset_path)
    
    # Step 4: Generate all icon sizes
    print("\nGenerating icon sizes...")
    
    # Icon specifications for macOS
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
        icon = create_square_icon(tower_only, size)
        output_path = os.path.join(iconset_path, filename)
        icon.save(output_path, 'PNG', optimize=True)
        is_transparent = verify_transparency(icon, f"{filename} ({size}x{size})")
        if is_transparent:
            print(f"  ✅ Created {filename}")
        else:
            print(f"  ⚠️  Created {filename} but transparency issue detected")
    
    # Also create standalone icons for verification
    print("\nCreating standalone icons for verification...")
    for size in [128, 256, 512, 1024]:
        icon = create_square_icon(tower_only, size)
        filename = f"icon_{size}x{size}.png"
        icon.save(filename, 'PNG', optimize=True)
        verify_transparency(icon, filename)
    
    # Create a version for the website (with more padding)
    print("\nCreating website logo...")
    web_icon = create_square_icon(tower_only, 256)
    web_icon.save("website_logo.png", 'PNG', optimize=True)
    verify_transparency(web_icon, "Website logo")
    
    print("\n✅ Icon processing complete!")
    print("Next steps:")
    print("1. Use Read tool to visually verify the icons")
    print("2. Run: iconutil -c icns BabelAI.iconset")
    print("3. Replace all icon files in the project")


if __name__ == "__main__":
    main()