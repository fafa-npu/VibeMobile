#!/usr/bin/env python3
"""
Generate VibeMobile macOS app icons with a modern design.
Design: Phone + Terminal + Signal waves in gradient blue-purple.
"""

from PIL import Image, ImageDraw
import math
import os


def create_gradient(size, start_color, end_color):
    """Create a gradient background."""
    img = Image.new('RGB', (size, size))

    for y in range(size):
        for x in range(size):
            # Calculate position along gradient (diagonal)
            t = (x + y) / (2 * size)
            r = int(start_color[0] + (end_color[0] - start_color[0]) * t)
            g = int(start_color[1] + (end_color[1] - start_color[1]) * t)
            b = int(start_color[2] + (end_color[2] - start_color[2]) * t)
            img.putpixel((x, y), (r, g, b))

    return img


def create_rounded_rect_mask(size, corner_radius):
    """Create a rounded rectangle mask for macOS icon shape."""
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [0, 0, size - 1, size - 1],
        radius=corner_radius,
        fill=255
    )
    return mask


def blend_color(base, overlay, alpha):
    """Blend overlay color onto base with given alpha (0-255)."""
    factor = alpha / 255.0
    return tuple(int(b * (1 - factor) + o * factor) for b, o in zip(base, overlay))


def create_app_icon(size):
    """Create the VibeMobile app icon at specified size."""
    # Colors - Blue to Purple gradient
    start_color = (79, 70, 229)   # Indigo
    end_color = (168, 85, 247)    # Purple

    # Create gradient background
    icon = create_gradient(size, start_color, end_color)
    draw = ImageDraw.Draw(icon)

    # Apply rounded corners (macOS style - about 22% of size)
    corner_radius = int(size * 0.22)

    # Icon elements scale
    padding = size * 0.12

    # Draw phone outline (left side)
    phone_width = size * 0.32
    phone_height = size * 0.58
    phone_x = padding
    phone_y = (size - phone_height) / 2
    phone_corner = size * 0.05

    line_width = max(2, int(size * 0.022))

    # Phone body outline
    draw.rounded_rectangle(
        [phone_x, phone_y, phone_x + phone_width, phone_y + phone_height],
        radius=phone_corner,
        outline='white',
        width=line_width
    )

    # Phone screen area - blend semi-transparent white manually
    screen_margin = size * 0.025
    screen_top_margin = size * 0.05
    screen_bottom_margin = size * 0.05
    screen_left = int(phone_x + screen_margin)
    screen_top = int(phone_y + screen_top_margin)
    screen_right = int(phone_x + phone_width - screen_margin)
    screen_bottom = int(phone_y + phone_height - screen_bottom_margin)

    # Draw semi-transparent screen by blending pixels
    screen_alpha = 50  # Semi-transparent
    for sy in range(screen_top, screen_bottom):
        for sx in range(screen_left, screen_right):
            if 0 <= sx < size and 0 <= sy < size:
                base = icon.getpixel((sx, sy))
                blended = blend_color(base, (255, 255, 255), screen_alpha)
                icon.putpixel((sx, sy), blended)

    # Redraw the draw object after pixel manipulation
    draw = ImageDraw.Draw(icon)

    # Draw terminal prompt (>_) inside phone screen
    prompt_center_x = phone_x + phone_width / 2
    prompt_center_y = phone_y + phone_height / 2
    prompt_size = size * 0.18

    # > symbol (chevron) - thicker lines
    chevron_line_width = max(4, int(size * 0.04))
    chevron_width = prompt_size * 0.65
    chevron_height = prompt_size * 1.1
    cx = prompt_center_x - prompt_size * 0.45
    cy = prompt_center_y

    # Draw chevron >
    draw.line(
        [(cx, cy - chevron_height/2), (cx + chevron_width, cy)],
        fill='white',
        width=chevron_line_width
    )
    draw.line(
        [(cx, cy + chevron_height/2), (cx + chevron_width, cy)],
        fill='white',
        width=chevron_line_width
    )

    # _ cursor (underline)
    cursor_x = cx + chevron_width + size * 0.025
    cursor_width = prompt_size * 0.55
    draw.line(
        [(cursor_x, cy + chevron_height/2), (cursor_x + cursor_width, cy + chevron_height/2)],
        fill='white',
        width=chevron_line_width
    )

    # Draw signal waves (right side, emanating from phone)
    wave_center_x = phone_x + phone_width + size * 0.02
    wave_center_y = size / 2

    # Three concentric arcs representing signal
    arc_width = max(2, int(size * 0.022))
    for i, radius_mult in enumerate([0.15, 0.26, 0.37]):
        radius = size * radius_mult
        # Fade arcs - outer ones are lighter
        gray_val = 255 - (i * 40)

        bbox = [
            wave_center_x - radius,
            wave_center_y - radius,
            wave_center_x + radius,
            wave_center_y + radius
        ]
        draw.arc(bbox, -50, 50, fill=(gray_val, gray_val, gray_val), width=arc_width)

    # Add small dot at wave origin
    dot_radius = size * 0.025
    draw.ellipse([
        wave_center_x - dot_radius, wave_center_y - dot_radius,
        wave_center_x + dot_radius, wave_center_y + dot_radius
    ], fill='white')

    # Convert to RGBA and apply macOS rounded corners mask
    icon_rgba = icon.convert('RGBA')
    mask = create_rounded_rect_mask(size, corner_radius)

    result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    result.paste(icon_rgba, mask=mask)

    return result


def create_simple_icon(size):
    """Create a simpler icon for small sizes."""
    # Colors
    start_color = (79, 70, 229)   # Indigo
    end_color = (168, 85, 247)    # Purple

    # Create gradient background
    icon = create_gradient(size, start_color, end_color)
    draw = ImageDraw.Draw(icon)

    # Apply rounded corners
    corner_radius = int(size * 0.22)

    # For very small sizes, just draw a phone outline with signal indicator
    padding = size * 0.2

    # Phone body
    phone_width = size * 0.35
    phone_height = size * 0.55
    phone_x = padding
    phone_y = (size - phone_height) / 2

    draw.rounded_rectangle(
        [phone_x, phone_y, phone_x + phone_width, phone_y + phone_height],
        radius=max(2, int(size * 0.06)),
        outline='white',
        width=max(1, int(size * 0.03))
    )

    # Signal dot
    dot_x = phone_x + phone_width + size * 0.08
    dot_y = size / 2
    dot_radius = max(2, size * 0.06)
    draw.ellipse([
        dot_x - dot_radius, dot_y - dot_radius,
        dot_x + dot_radius, dot_y + dot_radius
    ], fill='white')

    # One signal arc
    arc_radius = size * 0.22
    draw.arc([
        dot_x - arc_radius, dot_y - arc_radius,
        dot_x + arc_radius, dot_y + arc_radius
    ], -45, 45, fill='white', width=max(1, int(size * 0.025)))

    # Convert to RGBA and apply mask
    icon_rgba = icon.convert('RGBA')
    mask = create_rounded_rect_mask(size, corner_radius)

    result = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    result.paste(icon_rgba, mask=mask)

    return result


def main():
    output_dir = "macos/Runner/Assets.xcassets/AppIcon.appiconset"

    # Icon sizes for macOS
    sizes = [16, 32, 64, 128, 256, 512, 1024]

    for size in sizes:
        print(f"Generating {size}x{size} icon...")

        # Use simpler icon for small sizes
        if size <= 32:
            icon = create_simple_icon(size)
        else:
            icon = create_app_icon(size)

        # Save
        filename = f"{output_dir}/app_icon_{size}.png"
        icon.save(filename, "PNG")
        print(f"  Saved: {filename}")

    print("\nAll icons generated successfully!")
    print("Rebuild the Flutter app to apply the new icons.")


if __name__ == "__main__":
    main()
