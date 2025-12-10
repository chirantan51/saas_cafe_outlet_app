#!/usr/bin/env python3
"""
Add a shop icon badge to the app logo to differentiate outlet app from customer app.
"""

from PIL import Image, ImageDraw, ImageFont
import math

def create_shop_badge(size, bg_color, icon_color):
    """Create a circular shop icon badge."""
    badge = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(badge)

    # Draw circle background
    draw.ellipse([0, 0, size-1, size-1], fill=bg_color)

    # Draw shop/store icon (simplified storefront)
    margin = size * 0.2
    icon_size = size - (2 * margin)

    # Storefront roof (triangle)
    roof_height = icon_size * 0.3
    roof_points = [
        (size/2, margin),  # top center
        (margin, margin + roof_height),  # bottom left
        (size - margin, margin + roof_height)  # bottom right
    ]
    draw.polygon(roof_points, fill=icon_color)

    # Storefront body (rectangle)
    body_top = margin + roof_height
    body_bottom = size - margin
    body_left = margin + (icon_size * 0.15)
    body_right = size - margin - (icon_size * 0.15)
    draw.rectangle([body_left, body_top, body_right, body_bottom], fill=icon_color)

    # Door (small rectangle at bottom center)
    door_width = icon_size * 0.25
    door_height = icon_size * 0.35
    door_left = (size - door_width) / 2
    door_top = body_bottom - door_height
    draw.rectangle([door_left, door_top, door_left + door_width, body_bottom],
                   fill=bg_color)

    # Window (small rectangle at top)
    window_width = icon_size * 0.3
    window_height = icon_size * 0.2
    window_left = (size - window_width) / 2
    window_top = body_top + (icon_size * 0.15)
    draw.rectangle([window_left, window_top, window_left + window_width,
                   window_top + window_height], fill=bg_color)

    return badge

def add_shop_badge_to_logo(input_path, output_path, badge_position='bottom-right',
                           badge_size_ratio=0.35):
    """
    Add a shop icon badge to the logo.

    Args:
        input_path: Path to input logo image
        output_path: Path to save output image
        badge_position: Position of badge ('bottom-right', 'top-right', 'bottom-left', 'top-left')
        badge_size_ratio: Size of badge relative to image size (0.0-1.0)
    """
    # Open the logo
    logo = Image.open(input_path).convert('RGBA')
    width, height = logo.size

    # Calculate badge size
    badge_size = int(min(width, height) * badge_size_ratio)

    # Create shop badge with white background and primary color icon
    # Using a deep orange/brown color for the shop icon
    badge = create_shop_badge(badge_size,
                             bg_color=(255, 255, 255, 255),  # White background
                             icon_color=(84, 160, 121, 255))  # Chaimates green color

    # Add a subtle shadow/border to make badge stand out
    shadow = Image.new('RGBA', (badge_size + 8, badge_size + 8), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse([0, 0, badge_size + 7, badge_size + 7],
                        fill=(0, 0, 0, 80))  # Semi-transparent black shadow

    # Calculate badge position
    margin = int(badge_size * 0.05)  # Small margin from edges

    if badge_position == 'bottom-right':
        x = width - badge_size - margin - 4
        y = height - badge_size - margin - 4
    elif badge_position == 'top-right':
        x = width - badge_size - margin - 4
        y = margin - 4
    elif badge_position == 'bottom-left':
        x = margin - 4
        y = height - badge_size - margin - 4
    else:  # top-left
        x = margin - 4
        y = margin - 4

    # Paste shadow first
    logo.paste(shadow, (x, y), shadow)

    # Paste badge on top
    logo.paste(badge, (x + 4, y + 4), badge)

    # Save the result
    logo.save(output_path, 'PNG')
    print(f"✓ Created logo with shop badge: {output_path}")
    print(f"  Original size: {width}x{height}")
    print(f"  Badge size: {badge_size}x{badge_size}")
    print(f"  Badge position: {badge_position} at ({x}, {y})")

if __name__ == '__main__':
    import sys

    # Add shop badge to the padded logo
    input_logo = 'assets/chaimates/logo.png'
    output_logo = 'assets/chaimates/logo_with_shop_badge.png'

    add_shop_badge_to_logo(
        input_logo,
        output_logo,
        badge_position='bottom-right',
        badge_size_ratio=0.30  # 30% of image size
    )

    print(f"\n✓ Shop badge added successfully!")
    print(f"  Preview the result at: {output_logo}")
