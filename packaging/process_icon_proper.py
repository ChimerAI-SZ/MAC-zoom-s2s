#!/usr/bin/env python3
"""
Properly process BabelAI logo to create macOS app icon
Maintains quality and preserves complete tower
"""

from PIL import Image, ImageDraw
import numpy as np
import os

def analyze_logo(image_path):
    """Analyze the logo to understand its structure"""
    img = Image.open(image_path)
    print(f"Original size: {img.size}")
    print(f"Mode: {img.mode}")
    
    # Convert to RGBA for analysis
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Analyze content distribution
    data = np.array(img)
    
    # Check for non-white content (black lines of the tower)
    gray = np.mean(data[:, :, :3], axis=2)
    content_mask = gray < 250  # Pixels that are not white
    
    # Find vertical distribution
    rows_with_content = np.any(content_mask, axis=1)
    if rows_with_content.any():
        first_row = np.where(rows_with_content)[0][0]
        last_row = np.where(rows_with_content)[0][-1]
        print(f"Content rows: {first_row} to {last_row} (height: {last_row - first_row + 1})")
    
    # Find horizontal distribution
    cols_with_content = np.any(content_mask, axis=0)
    if cols_with_content.any():
        first_col = np.where(cols_with_content)[0][0]
        last_col = np.where(cols_with_content)[0][-1]
        print(f"Content cols: {first_col} to {last_col} (width: {last_col - first_col + 1})")
    
    return img

def extract_tower_carefully(image):
    """Extract tower without text, preserving quality and completeness"""
    # Convert to numpy array for processing
    data = np.array(image)
    
    # Find black content (the tower drawing)
    gray = np.mean(data[:, :, :3], axis=2)
    content_mask = gray < 250
    
    # Analyze row by row to find where text starts
    height = image.height
    width = image.width
    
    # Look for the "BABEL AI" text region
    # Text is typically in the bottom portion with specific characteristics
    tower_bottom = height  # Start with full height
    
    # Scan from bottom up to find where continuous tower ends
    # The text "BABEL AI" is separated from the tower
    for y in range(height - 1, height // 2, -1):
        row_content = content_mask[y, :]
        if not row_content.any():
            # Found empty row, might be separation between tower and text
            # Check if there's significant content below
            below_content = content_mask[y+1:, :].sum()
            if below_content > width * 10:  # Significant content below (likely text)
                tower_bottom = y
                break
    
    # Find actual tower bounds (with some padding)
    tower_mask = content_mask[:tower_bottom, :]
    rows = np.any(tower_mask, axis=1)
    cols = np.any(tower_mask, axis=0)
    
    if rows.any() and cols.any():
        row_indices = np.where(rows)[0]
        col_indices = np.where(cols)[0]
        
        top = row_indices[0]
        bottom = row_indices[-1]
        left = col_indices[0]
        right = col_indices[-1]
        
        # Add padding to ensure we don't cut anything
        padding = 30
        top = max(0, top - padding)
        bottom = min(tower_bottom - 1, bottom + padding)
        left = max(0, left - padding)
        right = min(width - 1, right + padding)
        
        # Crop to tower region
        tower = image.crop((left, top, right + 1, bottom + 1))
        
        print(f"Extracted tower region: ({left}, {top}) to ({right}, {bottom})")
        print(f"Tower size: {tower.size}")
        
        return tower
    
    return image

def create_icon_with_background(tower, size, bg_color=(248, 248, 248, 255)):
    """Create icon with rounded rectangle background like standard macOS apps"""
    # Create new image with transparent background first
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Draw rounded rectangle background (18% corner radius is standard for macOS)
    corner_radius = int(size * 0.18)
    draw.rounded_rectangle(
        [(0, 0), (size-1, size-1)],
        radius=corner_radius,
        fill=bg_color,
        outline=None
    )
    
    # Calculate how to fit the tower
    # Use 60% of available space to leave nice padding
    max_dimension = size * 0.6
    scale = max_dimension / max(tower.width, tower.height)
    
    # Resize tower maintaining aspect ratio
    new_width = int(tower.width * scale)
    new_height = int(tower.height * scale)
    
    # Use high-quality resampling
    tower_resized = tower.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Center the tower
    x_pos = (size - new_width) // 2
    y_pos = (size - new_height) // 2
    
    # Paste tower (handling transparency properly)
    img.paste(tower_resized, (x_pos, y_pos), tower_resized)
    
    return img

def main():
    print("🔍 Processing BabelAI logo for macOS icons...\n")
    
    # Check for original logo
    logo_path = "babel_ai_logo.png"
    if not os.path.exists(logo_path):
        print(f"❌ {logo_path} not found!")
        return
    
    # Analyze the logo first
    print("📊 Analyzing logo structure...")
    original = analyze_logo(logo_path)
    
    # Extract tower portion (without text)
    print("\n✂️ Extracting tower (without text)...")
    tower = extract_tower_carefully(original)
    
    # Save extracted tower for inspection
    tower.save("tower_extracted.png", 'PNG')
    print(f"💾 Saved extracted tower to tower_extracted.png")
    
    # Create preview icons
    print("\n🎨 Creating preview icons...")
    
    # Create iconset directory
    iconset_dir = "BabelAI.iconset"
    if os.path.exists(iconset_dir):
        import shutil
        shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir)
    
    # macOS icon specifications
    specs = [
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
    
    # Use very light gray background (like most macOS apps)
    background = (248, 248, 248, 255)
    
    # Generate all sizes
    for size, filename in specs:
        icon = create_icon_with_background(tower, size, background)
        path = os.path.join(iconset_dir, filename)
        icon.save(path, 'PNG', optimize=True)
        print(f"   ✅ {filename} ({size}x{size})")
    
    # Create standalone preview versions
    print("\n📸 Creating preview versions for verification...")
    for preview_size in [128, 256, 512, 1024]:
        icon = create_icon_with_background(tower, preview_size, background)
        preview_name = f"preview_{preview_size}.png"
        icon.save(preview_name, 'PNG', optimize=True)
        print(f"   ✅ {preview_name}")
    
    print("\n✅ Icon processing complete!")
    print("\n📋 Please verify the following files:")
    print("   • tower_extracted.png - Check if tower is complete")
    print("   • preview_512.png - Check icon appearance")
    print("   • BabelAI.iconset/ - All icon sizes")

if __name__ == "__main__":
    main()