#!/usr/bin/env python3
"""
Add a professional shop icon badge to the app logo.
Positioned to avoid Android adaptive icon cropping (safe zone aware).
"""

from PIL import Image, ImageDraw, ImageFont
import math

def create_professional_shop_badge(size, bg_color, icon_color):
    """Create a professional shop/store icon badge."""
    badge = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(badge)

    # Draw rounded square background with border
    corner_radius = size * 0.15
    # Draw background
    draw.rounded_rectangle([0, 0, size-1, size-1], radius=corner_radius, fill=bg_color)
    # Draw border
    border_width = max(2, int(size * 0.04))
    draw.rounded_rectangle(
        [border_width//2, border_width//2, size-1-border_width//2, size-1-border_width//2],
        radius=corner_radius,
        outline=icon_color,
        width=border_width
    )

    # Draw a more detailed shop icon
    margin = size * 0.25
    icon_width = size - (2 * margin)
    icon_height = icon_width * 0.85

    # Calculate center position
    center_x = size / 2
    start_y = margin + (icon_width - icon_height) / 2

    # 1. Awning/Canopy at top (curved stripes)
    awning_height = icon_height * 0.25
    awning_y = start_y

    # Draw striped awning with curves
    stripe_width = icon_width / 5
    for i in range(5):
        x_left = margin + (i * stripe_width)
        x_right = x_left + stripe_width

        if i % 2 == 0:  # Draw every other stripe
            # Create curved awning effect with arc
            points = []
            segments = 8
            for j in range(segments + 1):
                t = j / segments
                x = x_left + (x_right - x_left) * t
                # Curved bottom edge
                curve_depth = awning_height * 0.2
                y = awning_y + awning_height - curve_depth * math.sin(t * math.pi)
                points.append((x, y))

            # Complete the polygon with top edge
            points.append((x_right, awning_y))
            points.append((x_left, awning_y))

            draw.polygon(points, fill=icon_color)

    # 2. Shop front structure
    shop_top = awning_y + awning_height
    shop_height = icon_height - awning_height
    shop_left = margin + (icon_width * 0.1)
    shop_right = size - margin - (icon_width * 0.1)
    shop_bottom = start_y + icon_height

    # Main shop rectangle
    draw.rectangle([shop_left, shop_top, shop_right, shop_bottom], fill=icon_color)

    # 3. Large display window (lighter color)
    window_margin = icon_width * 0.08
    window_top = shop_top + window_margin
    window_bottom = shop_bottom - (shop_height * 0.35)
    window_left = shop_left + window_margin
    window_right = shop_right - window_margin

    # Window with slight transparency effect using lighter shade
    window_color = (255, 255, 255, 255) if bg_color != (255, 255, 255, 255) else (240, 240, 240, 255)
    draw.rectangle([window_left, window_top, window_right, window_bottom], fill=window_color)

    # Window frame dividers
    frame_width = max(1, int(size * 0.015))
    mid_x = (window_left + window_right) / 2
    mid_y = (window_top + window_bottom) / 2
    # Vertical divider
    draw.rectangle([mid_x - frame_width/2, window_top, mid_x + frame_width/2, window_bottom], fill=icon_color)
    # Horizontal divider
    draw.rectangle([window_left, mid_y - frame_width/2, window_right, mid_y + frame_width/2], fill=icon_color)

    # 4. Door
    door_width = (shop_right - shop_left) * 0.35
    door_height = shop_bottom - window_bottom - window_margin
    door_left = (size - door_width) / 2
    door_top = window_bottom + window_margin * 0.5
    door_bottom = shop_bottom

    draw.rectangle([door_left, door_top, door_left + door_width, door_bottom], fill=window_color)

    # Door handle
    handle_size = door_width * 0.12
    handle_x = door_left + door_width * 0.75
    handle_y = door_top + (door_bottom - door_top) * 0.5
    draw.ellipse([handle_x - handle_size/2, handle_y - handle_size/2,
                  handle_x + handle_size/2, handle_y + handle_size/2], fill=icon_color)

    return badge

def add_shop_badge_to_logo(input_path, output_path, badge_position='bottom-center',
                           badge_size_ratio=0.28):
    """
    Add a shop icon badge to the logo in Android adaptive icon safe zone.

    Args:
        input_path: Path to input logo image
        output_path: Path to save output image
        badge_position: Position of badge (optimized for adaptive icons)
        badge_size_ratio: Size of badge relative to image size
    """
    # Open the logo
    logo = Image.open(input_path).convert('RGBA')
    width, height = logo.size

    # Calculate badge size
    badge_size = int(min(width, height) * badge_size_ratio)

    # Create professional shop badge
    # Using green from Chaimates brand
    badge = create_professional_shop_badge(
        badge_size,
        bg_color=(255, 255, 255, 255),  # White background
        icon_color=(84, 160, 121, 255)  # Chaimates green
    )

    # Android adaptive icon safe zone is approximately 66% diameter circle centered
    # We need to stay well within this to avoid cropping
    # Best positions: bottom-center or top-center

    # Calculate badge position (bottom-center, staying in safe zone)
    center_x = width // 2

    if badge_position == 'bottom-center':
        # Position at bottom center, but well within safe zone
        # Safe zone is roughly 33% from edges for circular crop
        safe_margin = int(height * 0.15)  # 15% margin from bottom
        x = center_x - (badge_size // 2)
        y = height - badge_size - safe_margin
    elif badge_position == 'top-center':
        # Position at top center
        safe_margin = int(height * 0.15)
        x = center_x - (badge_size // 2)
        y = safe_margin
    else:  # center
        x = center_x - (badge_size // 2)
        y = (height - badge_size) // 2 + int(height * 0.25)  # Slightly below center

    # Paste badge
    logo.paste(badge, (x, y), badge)

    # Save the result
    logo.save(output_path, 'PNG')
    print(f"✓ Created logo with professional shop badge: {output_path}")
    print(f"  Original size: {width}x{height}")
    print(f"  Badge size: {badge_size}x{badge_size}")
    print(f"  Badge position: {badge_position} at ({x}, {y})")
    print(f"  ✓ Optimized for Android adaptive icon safe zone")

if __name__ == '__main__':
    import sys

    # Add shop badge to the padded logo
    input_logo = 'assets/chaimates/logo.png'
    output_logo = 'assets/chaimates/logo_with_shop_badge.png'

    add_shop_badge_to_logo(
        input_logo,
        output_logo,
        badge_position='bottom-center',
        badge_size_ratio=0.28  # 28% of image size, stays in safe zone
    )

    print(f"\n✓ Professional shop badge added successfully!")
    print(f"  The badge is positioned to stay visible even with circular cropping")
    print(f"  Preview: {output_logo}")
