#!/usr/bin/env python3
"""Extract the gold logo from checkerboard background, producing a transparent PNG.

The source image (al_batal_elite_logo_dark_mode.png) is an RGB PNG with a real
checkerboard pattern baked into the background (~RGB(226,226,226) and
RGB(255,255,255) alternating squares). This script:

1. Identifies background pixels via low chroma (neutral gray).
2. Identifies logo pixels via high chroma (warm gold tones).
3. Creates smooth alpha for anti-aliased edges.
4. Crops to the logo bounding box with padding.
5. Saves as RGBA PNG at a splash-appropriate resolution.
"""

from pathlib import Path
from PIL import Image
import numpy as np

SRC = Path(__file__).resolve().parent.parent / "assets" / "images" / "al_batal_elite_logo_dark_mode.png"
DST = Path(__file__).resolve().parent.parent / "assets" / "images" / "al_batal_elite_logo_splash.png"

# Output size: 512px is large enough for high-DPI splash screens without bloat.
# flutter_native_splash will scale it to the configured logical width.
OUTPUT_SIZE = 512

# Padding around the cropped logo (fraction of bounding box dimension).
CROP_PAD = 0.08


def extract():
    img = Image.open(SRC).convert("RGB")
    arr = np.array(img, dtype=np.float32)  # H x W x 3

    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]

    # Chroma: max(R,G,B) - min(R,G,B). Gray ≈ 0, gold ≫ 0.
    channel_max = np.maximum(np.maximum(r, g), b)
    channel_min = np.minimum(np.minimum(r, g), b)
    chroma = channel_max - channel_min

    # Luminance: for edge detection in dark regions.
    lum = 0.299 * r + 0.587 * g + 0.114 * b

    # --- Alpha mask from chroma ---
    # Pure background (gray checkerboard): chroma < 5  → fully transparent.
    # Pure logo (gold):                   chroma > 25 → fully opaque.
    # Edge / anti-aliased pixels:         5 ≤ chroma ≤ 25 → smooth gradient.
    low_thresh = 5.0
    high_thresh = 25.0

    alpha = np.zeros_like(chroma)
    mask_edge = (chroma >= low_thresh) & (chroma <= high_thresh)
    mask_logo = chroma > high_thresh

    alpha[mask_logo] = 1.0
    # Smooth ramp for edge pixels.
    alpha[mask_edge] = (chroma[mask_edge] - low_thresh) / (high_thresh - low_thresh)

    # Additional heuristic: very dark pixels with any warmth are logo strokes.
    # (Some dark gold strokes have low chroma due to darkness.)
    dark_warm = (lum < 80) & (r > g) & (r > b) & (chroma > 2)
    alpha[dark_warm] = np.maximum(alpha[dark_warm], 0.7)

    # Additional heuristic: very bright warm pixels near the gold range.
    bright_warm = (lum > 180) & (r > 180) & (g > 150) & (b < 130) & (chroma > 30)
    alpha[bright_warm] = np.maximum(alpha[bright_warm], 0.85)

    # --- Crop to bounding box ---
    rows = np.any(alpha > 0.01, axis=1)
    cols = np.any(alpha > 0.01, axis=0)
    if not rows.any() or not cols.any():
        raise RuntimeError("No logo content detected — check source image.")

    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]

    # Add padding.
    h_box = rmax - rmin
    w_box = cmax - cmin
    pad_h = int(h_box * CROP_PAD)
    pad_w = int(w_box * CROP_PAD)

    rmin = max(0, rmin - pad_h)
    rmax = min(arr.shape[0] - 1, rmax + pad_h)
    cmin = max(0, cmin - pad_w)
    cmax = min(arr.shape[1] - 1, cmax + pad_w)

    # Crop all channels.
    cropped_rgb = arr[rmin:rmax + 1, cmin:cmax + 1]
    cropped_alpha = alpha[rmin:rmax + 1, cmin:cmax + 1]

    # --- Build RGBA image ---
    rgba = np.zeros((*cropped_rgb.shape[:2], 4), dtype=np.uint8)
    rgba[:, :, :3] = np.clip(cropped_rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(cropped_alpha * 255, 0, 255).astype(np.uint8)

    result = Image.fromarray(rgba, "RGBA")

    # Resize to output size, maintaining aspect ratio within OUTPUT_SIZE x OUTPUT_SIZE.
    # Place centered on a transparent canvas.
    result.thumbnail((OUTPUT_SIZE, OUTPUT_SIZE), Image.LANCZOS)
    canvas = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    offset_x = (OUTPUT_SIZE - result.width) // 2
    offset_y = (OUTPUT_SIZE - result.height) // 2
    canvas.paste(result, (offset_x, offset_y), result)

    # Save with full quality.
    canvas.save(DST, "PNG", optimize=False)

    # --- Verification ---
    verify = Image.open(DST)
    assert verify.mode == "RGBA", f"Expected RGBA, got {verify.mode}"
    assert verify.size == (OUTPUT_SIZE, OUTPUT_SIZE), f"Wrong size: {verify.size}"

    # Count fully transparent pixels in corners (should be the vast majority).
    corner_pixels = [
        verify.getpixel((0, 0)),
        verify.getpixel((OUTPUT_SIZE - 1, 0)),
        verify.getpixel((0, OUTPUT_SIZE - 1)),
        verify.getpixel((OUTPUT_SIZE - 1, OUTPUT_SIZE - 1)),
    ]
    transparent_corners = sum(1 for p in corner_pixels if p[3] == 0)
    print(f"✓ Output: {DST}")
    print(f"  Size: {verify.size}, Mode: {verify.mode}")
    print(f"  Corner transparency: {transparent_corners}/4 corners fully transparent")
    print(f"  File size: {DST.stat().st_size:,} bytes")


if __name__ == "__main__":
    extract()
