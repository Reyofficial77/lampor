#!/usr/bin/env python3
"""
Procedural Tarot / Occult Fate Card Artwork Generator for LAMPOR: Malam Jahanam.

Generates 21 bespoke 256x360 PNG artworks under assets/textures/cards/:
- 1 card back (card_back.png)
- 10 Kutukan / Curses (curse_*.png)
- 10 Keberuntungan / Blessings (blessing_*.png)

Rendered at 2x supersampled resolution (512x720) with Pillow and downsampled
using LANCZOS for crisp antique Javanese folklore horror aesthetics matching
HorrorTheme.gd / DESIGN.md. Zero baked text.
"""

from __future__ import annotations

import hashlib
import math
import random
from pathlib import Path
from typing import Callable

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

# Target dimensions & 2x supersample canvas
OUT_W, OUT_H = 256, 360
SCALE = 2
W, H = OUT_W * SCALE, OUT_H * SCALE  # 512 x 720
CX, CY = W // 2, int(H * 0.49)

ROOT_DIR = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT_DIR / "assets" / "textures" / "cards"

# Official HorrorTheme.gd / DESIGN.md color anchors (RGB tuples)
PAL = {
    "bg_obsidian": (20, 10, 9),
    "bg_surface": (29, 16, 15),
    "bg_dim": (13, 6, 6),
    "bg_warm": (26, 17, 11),
    "crimson": (212, 67, 60),
    "crimson_deep": (158, 27, 27),
    "crimson_dark": (90, 26, 23),
    "crimson_glow": (255, 130, 120),
    "bone": (247, 221, 218),
    "bone_dim": (185, 158, 152),
    "ash": (141, 112, 109),
    "ash_dark": (74, 52, 49),
    "iron": (96, 98, 106),
    "iron_light": (175, 178, 186),
    "iron_dark": (38, 36, 40),
    "brass": (201, 154, 91),
    "gold": (240, 198, 116),
    "gold_bright": (255, 238, 188),
    "gold_dark": (118, 82, 38),
    "amber": (236, 140, 58),
    "amber_glow": (255, 196, 105),
    "sage": (134, 186, 140),
    "emerald": (64, 166, 110),
    "emerald_bright": (162, 240, 184),
    "keranda": (31, 94, 59),
    "keranda_glow": (96, 224, 136),
    "violet": (156, 62, 138),
    "violet_glow": (222, 134, 212),
    "silver": (214, 218, 232),
    "silver_dim": (122, 128, 146),
    "midnight_sand": (68, 92, 158),
}

_GRAIN_BASE_CACHE: Image.Image | None = None
_VIGNETTE_CACHE: Image.Image | None = None


def rgba(rgb: tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    return (rgb[0], rgb[1], rgb[2], max(0, min(255, alpha)))


def rot_pts(
    pts: list[tuple[float, float]], cx: float, cy: float, angle_deg: float
) -> list[tuple[float, float]]:
    rad = math.radians(angle_deg)
    c, s = math.cos(rad), math.sin(rad)
    return [
        (cx + (px - cx) * c - (py - cy) * s, cy + (px - cx) * s + (py - cy) * c)
        for px, py in pts
    ]


def quad_bezier(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    steps: int = 20,
) -> list[tuple[float, float]]:
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1.0 - t
        x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
        y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        out.append((x, y))
    return out


def cubic_bezier(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    steps: int = 24,
) -> list[tuple[float, float]]:
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1.0 - t
        x = (
            u**3 * p0[0]
            + 3 * u**2 * t * p1[0]
            + 3 * u * t**2 * p2[0]
            + t**3 * p3[0]
        )
        y = (
            u**3 * p0[1]
            + 3 * u**2 * t * p1[1]
            + 3 * u * t**2 * p2[1]
            + t**3 * p3[1]
        )
        out.append((x, y))
    return out


def paste_crescent_moon(
    fg: Image.Image,
    cx: float,
    cy: float,
    r_outer: float,
    inner_dx: float,
    inner_dy: float,
    r_inner: float,
    fill_rgb: tuple[int, int, int],
    outline_rgb: tuple[int, int, int] | None = None,
) -> None:
    """Render a crisp crescent moon onto an RGBA layer via alpha subtraction mask."""
    mask = Image.new("L", fg.size, 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], fill=255)
    ix, iy = cx + inner_dx, cy + inner_dy
    md.ellipse([ix - r_inner, iy - r_inner, ix + r_inner, iy + r_inner], fill=0)

    moon_layer = Image.new("RGBA", fg.size, rgba(fill_rgb, 245))
    moon_layer.putalpha(mask.point(lambda p: int(p * 0.96)))
    fg.alpha_composite(moon_layer)

    if outline_rgb is not None:
        # Subtle outer rim trace from dilated minus inner mask
        rim = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(5)))
        rim_layer = Image.new("RGBA", fg.size, rgba(outline_rgb, 255))
        rim_layer.putalpha(rim)
        fg.alpha_composite(rim_layer)


def make_radial_mask(
    size: tuple[int, int],
    center: tuple[float, float],
    rx: float,
    ry: float,
    power: float = 1.6,
) -> Image.Image:
    """Create a smooth elliptical gradient mask (255 at center -> 0 at edge)."""
    w, h = size
    grad = Image.radial_gradient("L")
    grad = ImageChops.invert(grad)
    lut = [int(255 * ((i / 255.0) ** power)) for i in range(256)]
    grad = grad.point(lut)
    ew, eh = max(2, int(rx * 2)), max(2, int(ry * 2))
    blob = grad.resize((ew, eh), Image.Resampling.BILINEAR)
    canvas = Image.new("L", (w, h), 0)
    canvas.paste(blob, (int(center[0] - rx), int(center[1] - ry)))
    return canvas


def add_glow(
    base: Image.Image,
    center: tuple[float, float],
    rx: float,
    ry: float,
    color: tuple[int, int, int],
    alpha: int,
    power: float = 1.8,
) -> None:
    """Composite a soft radial aura glow onto base RGBA image."""
    mask = make_radial_mask(base.size, center, rx, ry, power=power)
    if alpha < 255:
        scale = alpha / 255.0
        mask = mask.point(lambda p: int(p * scale))
    tint = Image.new("RGBA", base.size, rgba(color, 255))
    tint.putalpha(mask)
    base.alpha_composite(tint)


def add_layer_with_glow(
    base: Image.Image,
    draw_fn: Callable[[ImageDraw.ImageDraw], None],
    glow_color: tuple[int, int, int],
    glow_radius: float = 14.0,
    glow_alpha: int = 180,
    drop_shadow: bool = True,
    layer_post_fn: Callable[[Image.Image], None] | None = None,
) -> None:
    """Render artwork on a temporary layer, apply drop-shadow + outer bloom, then crisp foreground."""
    fg = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(fg, "RGBA")
    draw_fn(d)
    if layer_post_fn is not None:
        layer_post_fn(fg)

    if drop_shadow:
        alpha_ch = fg.getchannel("A")
        shadow = Image.new("RGBA", base.size, (6, 3, 3, 220))
        shadow.putalpha(alpha_ch.point(lambda p: int(p * 0.72)))
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=9))
        shadow_shifted = Image.new("RGBA", base.size, (0, 0, 0, 0))
        shadow_shifted.paste(shadow, (0, 9))
        base.alpha_composite(shadow_shifted)

    if glow_alpha > 0 and glow_radius > 0:
        alpha_ch = fg.getchannel("A")
        glow = Image.new("RGBA", base.size, rgba(glow_color, 255))
        glow.putalpha(alpha_ch.point(lambda p: int(p * (glow_alpha / 255.0))))
        glow = glow.filter(ImageFilter.GaussianBlur(radius=glow_radius))
        base.alpha_composite(glow)

    base.alpha_composite(fg)


def _get_shared_grain_and_vignette() -> tuple[Image.Image, Image.Image]:
    global _GRAIN_BASE_CACHE, _VIGNETTE_CACHE
    if _GRAIN_BASE_CACHE is None:
        noise = Image.effect_noise((W, H), 26.0).filter(ImageFilter.GaussianBlur(radius=1.8))
        blotch = Image.effect_noise((W // 4, H // 4), 52.0).resize((W, H), Image.Resampling.BICUBIC)
        grain = ImageChops.blend(noise, blotch, 0.48)
        _GRAIN_BASE_CACHE = Image.merge(
            "RGBA",
            (
                grain.point(lambda p: int(p * 0.25)),
                grain.point(lambda p: int(p * 0.17)),
                grain.point(lambda p: int(p * 0.14)),
                grain.point(lambda p: max(0, min(62, abs(p - 128) // 2 + 8))),
            ),
        )
    if _VIGNETTE_CACHE is None:
        vig_center = make_radial_mask((W, H), (W / 2, H / 2), W * 0.56, H * 0.54, power=1.08)
        vig_edge = ImageChops.invert(vig_center)
        dark_scrim = Image.new("RGBA", (W, H), (5, 2, 2, 255))
        dark_scrim.putalpha(vig_edge.point(lambda p: int(p * 0.88)))
        _VIGNETTE_CACHE = dark_scrim
    return _GRAIN_BASE_CACHE, _VIGNETTE_CACHE


def build_parchment_background(
    seed: int,
    base_rgb: tuple[int, int, int],
    mid_rgb: tuple[int, int, int],
    aura_rgb: tuple[int, int, int],
    secondary_aura_rgb: tuple[int, int, int] | None = None,
) -> Image.Image:
    """Create dark obsidian aged Javanese parchment with fiber grain, mist clouds, and vignette."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (W, H), rgba(base_rgb, 255))
    add_glow(img, (CX, CY), W * 0.72, H * 0.60, mid_rgb, 235, power=1.25)
    add_glow(img, (CX, CY), W * 0.48, H * 0.40, aura_rgb, 155, power=1.65)
    if secondary_aura_rgb is not None:
        add_glow(
            img,
            (CX + rng.randint(-36, 36), CY + rng.randint(-42, 42)),
            W * 0.36,
            H * 0.30,
            secondary_aura_rgb,
            95,
            power=1.9,
        )

    grain_rgba, dark_scrim = _get_shared_grain_and_vignette()
    img.alpha_composite(grain_rgba)

    # Subtle ambient sparks & parchment fibers + mystical vertical axis ornament
    deco = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco, "RGBA")
    for _ in range(55):
        x0 = rng.randint(28, W - 28)
        y0 = rng.randint(28, H - 28)
        ang = rng.uniform(0, math.tau)
        ln = rng.uniform(16, 56)
        dd.line([(x0, y0), (x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln)], fill=rgba(PAL["bone_dim"], rng.randint(8, 17)), width=1)
    # Subtle atmospheric dust motes inside inner sanctuary
    for _ in range(28):
        mx = rng.randint(82, W - 82)
        my = rng.randint(105, H - 105)
        mr = rng.uniform(1.2, 2.6)
        dd.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=rgba(aura_rgb, rng.randint(45, 95)))
    # Subtle vertical axis line & diamond ticks bridging top/bottom crest toward central emblem
    dd.line([(CX, 84), (CX, 148)], fill=rgba(PAL["brass"], 48), width=2)
    dd.line([(CX, H - 148), (CX, H - 84)], fill=rgba(PAL["brass"], 48), width=2)
    for ty in (118, H - 118):
        dd.polygon([(CX, ty - 6), (CX + 5, ty), (CX, ty + 6), (CX - 5, ty)], fill=rgba(aura_rgb, 115))
    img.alpha_composite(deco)
    img.alpha_composite(dark_scrim)
    return img


def draw_kawung_rosette(
    d: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    radius: float,
    primary_col: tuple[int, int, int, int],
    fill_col: tuple[int, int, int, int],
    accent_col: tuple[int, int, int, int],
) -> None:
    """Draw a traditional 4-petal Javanese Kawung motif at (cx, cy)."""
    for ang in (45, 135, 225, 315):
        rad = math.radians(ang)
        px = cx + math.cos(rad) * radius * 0.52
        py = cy + math.sin(rad) * radius * 0.52
        petal = []
        for i in range(17):
            t = (i / 16.0) * math.tau
            petal.append((math.cos(t) * (radius * 0.44), math.sin(t) * (radius * 0.23)))
        petal_rot = rot_pts([(px + x, py + y) for x, y in petal], px, py, ang)
        d.polygon(petal_rot, fill=fill_col, outline=primary_col, width=2)
        sx = cx + math.cos(rad) * radius * 0.56
        sy = cy + math.sin(rad) * radius * 0.56
        d.ellipse([sx - 2.5, sy - 2.5, sx + 2.5, sy + 2.5], fill=accent_col)

    r = radius * 0.22
    d.polygon(
        [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)],
        fill=accent_col,
        outline=primary_col,
        width=2,
    )


def draw_javanese_crest(
    d: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    mode: str,
    primary: tuple[int, int, int],
    secondary: tuple[int, int, int],
    glow: tuple[int, int, int],
    flip_y: bool = False,
) -> None:
    """Draw upper or lower sacred geometric Javanese glyph (gunungan/solar/eclipse sigil)."""
    s = -1.0 if flip_y else 1.0
    p_col = rgba(primary, 225)
    s_col = rgba(secondary, 180)
    g_col = rgba(glow, 240)

    if mode == "curse":
        d.line([(cx - 88, cy), (cx - 26, cy)], fill=s_col, width=2)
        d.line([(cx + 26, cy), (cx + 88, cy)], fill=s_col, width=2)
        pts_arc_top = quad_bezier((cx - 34, cy - 8 * s), (cx, cy + 16 * s), (cx + 34, cy - 8 * s))
        pts_arc_bot = quad_bezier((cx + 34, cy - 8 * s), (cx, cy + 4 * s), (cx - 34, cy - 8 * s))
        d.polygon(pts_arc_top + pts_arc_bot, fill=rgba(secondary, 175), outline=p_col, width=2)
        spike = [
            (cx, cy - 22 * s),
            (cx + 10, cy + 2 * s),
            (cx, cy + 24 * s),
            (cx - 10, cy + 2 * s),
        ]
        d.polygon(spike, fill=rgba(PAL["bg_obsidian"], 240), outline=g_col, width=2)
        d.ellipse([cx - 3.5, cy - 3.5, cx + 3.5, cy + 3.5], fill=g_col)
    elif mode == "blessing":
        d.line([(cx - 92, cy), (cx - 32, cy)], fill=s_col, width=2)
        d.line([(cx + 32, cy), (cx + 92, cy)], fill=s_col, width=2)
        for ang in (-55, -28, 0, 28, 55):
            rad = math.radians(ang - 90 * s)
            ln = 24 if ang == 0 else 16
            d.line(
                [(cx, cy), (cx + math.cos(rad) * ln, cy + math.sin(rad) * ln)],
                fill=rgba(glow, 185),
                width=2,
            )
        crown = [
            (cx, cy - 20 * s),
            (cx + 14, cy - 2 * s),
            (cx + 24, cy + 8 * s),
            (cx, cy + 16 * s),
            (cx - 24, cy + 8 * s),
            (cx - 14, cy - 2 * s),
        ]
        d.polygon(crown, fill=rgba(PAL["gold_dark"], 170), outline=p_col, width=2)
        d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=g_col)
    else:
        d.line([(cx - 96, cy), (cx - 30, cy)], fill=s_col, width=2)
        d.line([(cx + 30, cy), (cx + 96, cy)], fill=s_col, width=2)
        d.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=rgba(PAL["bg_obsidian"], 230), outline=p_col, width=2)
        d.polygon(
            [(cx, cy - 24), (cx + 11, cy), (cx, cy + 24), (cx - 11, cy)],
            fill=rgba(secondary, 175),
            outline=g_col,
            width=2,
        )
        d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=g_col)

    for ox in (-96, 96):
        d.polygon(
            [(cx + ox, cy - 5), (cx + ox + 5, cy), (cx + ox, cy + 5), (cx + ox - 5, cy)],
            fill=g_col,
        )


def draw_card_frame(
    img: Image.Image,
    mode: str,
    primary: tuple[int, int, int],
    secondary: tuple[int, int, int],
    glow: tuple[int, int, int],
) -> None:
    """Apply ornate double border, inner sacred sanctuary arch, kawung corners, and sacred glyphs."""
    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame, "RGBA")

    m1 = 18
    m2 = 30
    chamfer = 24

    d.rectangle([m1, m1, W - m1, H - m1], outline=rgba(secondary, 220), width=3)
    d.rectangle([m1 + 5, m1 + 5, W - m1 - 5, H - m1 - 5], outline=rgba(primary, 195), width=2)

    inner_poly = [
        (m2 + chamfer, m2),
        (W - m2 - chamfer, m2),
        (W - m2, m2 + chamfer),
        (W - m2, H - m2 - chamfer),
        (W - m2 - chamfer, H - m2),
        (m2 + chamfer, H - m2),
        (m2, H - m2 - chamfer),
        (m2, m2 + chamfer),
    ]
    d.polygon(inner_poly, outline=rgba(primary, 215), width=2)

    arch_m = 48
    d.arc([arch_m, 72, W - arch_m, 72 + (W - 2 * arch_m)], start=180, end=360, fill=rgba(secondary, 125), width=2)
    d.arc([arch_m, H - 72 - (W - 2 * arch_m), W - arch_m, H - 72], start=0, end=180, fill=rgba(secondary, 125), width=2)
    d.line([(arch_m, 72 + (W - 2 * arch_m) / 2), (arch_m, H - 72 - (W - 2 * arch_m) / 2)], fill=rgba(secondary, 105), width=2)
    d.line([(W - arch_m, 72 + (W - 2 * arch_m) / 2), (W - arch_m, H - 72 - (W - 2 * arch_m) / 2)], fill=rgba(secondary, 105), width=2)

    for sy in (H * 0.34, H * 0.50, H * 0.66):
        for sx, dx in ((m1 + 4, 14), (W - m1 - 4, -14)):
            d.polygon([(sx, sy - 6), (sx + dx, sy), (sx, sy + 6)], fill=rgba(primary, 175))

    corner_r = 25
    corners = [
        (m2 + 12, m2 + 12, 1, 1),
        (W - m2 - 12, m2 + 12, -1, 1),
        (m2 + 12, H - m2 - 12, 1, -1),
        (W - m2 - 12, H - m2 - 12, -1, -1),
    ]
    for kx, ky, sx, sy in corners:
        sc_h = quad_bezier((kx + 18 * sx, ky - 4 * sy), (kx + 56 * sx, ky - 10 * sy), (kx + 84 * sx, ky + 4 * sy))
        sc_v = quad_bezier((kx - 4 * sx, ky + 18 * sy), (kx - 10 * sx, ky + 56 * sy), (kx + 4 * sx, ky + 84 * sy))
        d.line(sc_h, fill=rgba(primary, 175), width=2)
        d.line(sc_v, fill=rgba(primary, 175), width=2)
        draw_kawung_rosette(d, kx, ky, corner_r, rgba(primary, 225), rgba(secondary, 130), rgba(glow, 235))

    draw_javanese_crest(d, W / 2, 54, mode, primary, secondary, glow, flip_y=False)
    draw_javanese_crest(d, W / 2, H - 54, mode, primary, secondary, glow, flip_y=True)

    glow_layer = frame.filter(ImageFilter.GaussianBlur(radius=5))
    glow_layer.putalpha(glow_layer.getchannel("A").point(lambda p: int(p * 0.45)))
    img.alpha_composite(glow_layer)
    img.alpha_composite(frame)


# ---------------------------------------------------------------------------
# Shared Folklore Motif Helpers
# ---------------------------------------------------------------------------

def draw_sacred_ring_backdrop(
    img: Image.Image,
    cx: float,
    cy: float,
    radius: float,
    ring_rgb: tuple[int, int, int],
    spokes: int = 16,
    jagged: bool = False,
) -> None:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], outline=rgba(ring_rgb, 100), width=2)
    r2 = radius * 0.82
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], outline=rgba(ring_rgb, 68), width=2)
    for i in range(spokes):
        a = (i / spokes) * math.tau
        in_r = radius * (0.72 if (jagged and i % 2 == 1) else 0.82)
        out_r = radius * (1.14 if (jagged and i % 2 == 0) else 1.04)
        d.line(
            [(cx + math.cos(a) * in_r, cy + math.sin(a) * in_r), (cx + math.cos(a) * out_r, cy + math.sin(a) * out_r)],
            fill=rgba(ring_rgb, 92 if i % 2 == 0 else 58),
            width=2,
        )
    img.alpha_composite(layer)


def draw_footprint_shape(
    d: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    scale: float,
    angle_deg: float,
    fill_col: tuple[int, int, int, int],
    outline_col: tuple[int, int, int, int],
    boot: bool = False,
) -> None:
    if boot:
        sole = [(-26, -54), (0, -64), (24, -54), (30, -24), (22, 6), (-20, 8), (-28, -22)]
        heel = [(-20, 20), (20, 18), (22, 52), (0, 62), (-22, 52)]
        for part in (sole, heel):
            pts = rot_pts([(cx + x * scale, cy + y * scale) for x, y in part], cx, cy, angle_deg)
            d.polygon(pts, fill=fill_col, outline=outline_col, width=3)
        for ty in (-38, -22, -6, 32, 46):
            bar = rot_pts([(cx - 18 * scale, cy + ty * scale), (cx + 18 * scale, cy + ty * scale)], cx, cy, angle_deg)
            d.line(bar, fill=outline_col, width=3)
    else:
        foot = [
            (-18, -42), (4, -46), (22, -32), (24, -8),
            (13, 18), (18, 44), (4, 58), (-14, 52),
            (-19, 26), (-14, 2), (-24, -18),
        ]
        pts = rot_pts([(cx + x * scale, cy + y * scale) for x, y in foot], cx, cy, angle_deg)
        d.polygon(pts, fill=fill_col, outline=outline_col, width=3)
        toes = [(-18, -56, 8), (-6, -62, 6.5), (5, -59, 6), (15, -52, 5.5), (24, -42, 4.8)]
        for tx, ty, tr in toes:
            rx, ry = rot_pts([(cx + tx * scale, cy + ty * scale)], cx, cy, angle_deg)[0]
            rr = tr * scale
            d.ellipse([rx - rr, ry - rr * 1.25, rx + rr, ry + rr * 1.25], fill=fill_col, outline=outline_col, width=2)


def draw_keris_blade(
    d: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    length: float,
    angle_deg: float,
    blade_col: tuple[int, int, int],
    edge_col: tuple[int, int, int],
    hilt_col: tuple[int, int, int],
) -> None:
    left_pts = []
    right_pts = []
    blade_top = -length * 0.56
    blade_bot = length * 0.24
    steps = 28
    for i in range(steps + 1):
        t = i / steps
        y = blade_bot + (blade_top - blade_bot) * t
        width = (1.0 - t**0.85) * 14.0 + 1.5
        wave = math.sin(t * math.pi * 5.0) * (1.0 - t * 0.45) * 9.5
        left_pts.append((cx + wave - width, cy + y))
        right_pts.append((cx + wave + width, cy + y))
    blade_poly = left_pts + list(reversed(right_pts))
    d.polygon(rot_pts(blade_poly, cx, cy, angle_deg), fill=rgba(blade_col, 245), outline=rgba(edge_col, 255), width=2)

    spine = [
        (cx + math.sin((i / 24) * math.pi * 5.0) * (1.0 - (i / 24) * 0.45) * 9.5,
         cy + blade_bot + (blade_top - blade_bot) * (i / 24))
        for i in range(25)
    ]
    d.line(rot_pts(spine, cx, cy, angle_deg), fill=rgba(edge_col, 220), width=2)

    ganja = [
        (cx - 28, cy + blade_bot + 2),
        (cx - 8, cy + blade_bot - 6),
        (cx + 26, cy + blade_bot - 2),
        (cx + 32, cy + blade_bot + 7),
        (cx - 22, cy + blade_bot + 9),
    ]
    d.polygon(rot_pts(ganja, cx, cy, angle_deg), fill=rgba(hilt_col, 250), outline=rgba(edge_col, 255), width=2)

    hilt_top = blade_bot + 9
    hilt_bot = length * 0.46
    hilt = [
        (cx - 7, cy + hilt_top),
        (cx + 7, cy + hilt_top),
        (cx + 10, cy + (hilt_top + hilt_bot) * 0.5),
        (cx + 16, cy + hilt_bot),
        (cx + 2, cy + hilt_bot + 6),
        (cx - 9, cy + (hilt_top + hilt_bot) * 0.55),
    ]
    d.polygon(rot_pts(hilt, cx, cy, angle_deg), fill=rgba(PAL["crimson_dark"], 245), outline=rgba(hilt_col, 255), width=2)


def draw_keranda_silhouette(
    d: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    scale: float,
    angle_deg: float,
    body_col: tuple[int, int, int],
    shroud_col: tuple[int, int, int],
    trim_col: tuple[int, int, int],
) -> None:
    for py in (20, 26):
        pole = rot_pts([(cx - 108 * scale, cy + py * scale), (cx + 108 * scale, cy + py * scale)], cx, cy, angle_deg)
        d.line(pole, fill=rgba(trim_col, 230), width=max(2, int(4 * scale)))

    base = [(-74, 10), (74, 10), (68, 28), (-68, 28)]
    d.polygon(
        rot_pts([(cx + x * scale, cy + y * scale) for x, y in base], cx, cy, angle_deg),
        fill=rgba(body_col, 245),
        outline=rgba(trim_col, 230),
        width=2,
    )

    canopy = [
        (-66, 12), (-54, -26), (-26, -46), (0, -52),
        (26, -46), (54, -26), (66, 12), (48, 24),
        (20, 16), (0, 26), (-20, 16), (-48, 24),
    ]
    d.polygon(
        rot_pts([(cx + x * scale, cy + y * scale) for x, y in canopy], cx, cy, angle_deg),
        fill=rgba(shroud_col, 238),
        outline=rgba(trim_col, 240),
        width=2,
    )
    for rx in (-32, 0, 32):
        rib = rot_pts([(cx + rx * scale, cy - 44 * scale), (cx + rx * scale, cy + 16 * scale)], cx, cy, angle_deg)
        d.line(rib, fill=rgba(trim_col, 150), width=2)


# ---------------------------------------------------------------------------
# 21 Bespoke Card Central Emblem Renderers
# ---------------------------------------------------------------------------

def render_card_back() -> Image.Image:
    img = build_parchment_background(100, PAL["bg_dim"], (36, 15, 14), PAL["crimson_deep"], PAL["gold_dark"])
    draw_sacred_ring_backdrop(img, CX, CY, 168, PAL["brass"], spokes=24, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        star_pts = [
            (CX + math.cos((i / 16.0) * math.tau - math.pi / 2) * (152 if i % 2 == 0 else 108),
             CY + math.sin((i / 16.0) * math.tau - math.pi / 2) * (152 if i % 2 == 0 else 108))
            for i in range(16)
        ]
        d.polygon(star_pts, fill=rgba(PAL["crimson_dark"], 140), outline=rgba(PAL["brass"], 230), width=3)
        d.ellipse([CX - 102, CY - 102, CX + 102, CY + 102], fill=rgba(PAL["bg_obsidian"], 235), outline=rgba(PAL["gold"], 235), width=3)
        d.ellipse([CX - 86, CY - 86, CX + 86, CY + 86], outline=rgba(PAL["crimson"], 190), width=2)

        draw_keris_blade(d, CX, CY + 4, 290, -34, PAL["iron_light"], PAL["gold_bright"], PAL["brass"])
        draw_keris_blade(d, CX, CY + 4, 290, 34, PAL["iron_light"], PAL["gold_bright"], PAL["brass"])

        d.ellipse([CX - 54, CY - 54, CX + 54, CY + 54], fill=rgba(PAL["bg_obsidian"], 250), outline=rgba(PAL["gold"], 255), width=4)
        eye_top = quad_bezier((CX - 42, CY), (CX, CY - 34), (CX + 42, CY))
        eye_bot = quad_bezier((CX + 42, CY), (CX, CY + 34), (CX - 42, CY))
        d.polygon(eye_top + eye_bot, fill=rgba(PAL["crimson_deep"], 240), outline=rgba(PAL["gold_bright"], 255), width=3)
        d.ellipse([CX - 18, CY - 18, CX + 18, CY + 18], fill=rgba(PAL["amber_glow"], 245), outline=rgba(PAL["gold_bright"], 255), width=2)
        d.polygon([(CX, CY - 14), (CX + 5, CY), (CX, CY + 14), (CX - 5, CY)], fill=rgba(PAL["bg_dim"], 255))
        d.ellipse([CX - 6, CY - 8, CX - 1, CY - 3], fill=rgba(PAL["gold_bright"], 230))

    add_layer_with_glow(img, draw_emblem, PAL["crimson"], glow_radius=18, glow_alpha=170)
    draw_card_frame(img, "back", PAL["brass"], PAL["crimson_deep"], PAL["gold"])
    return img


def render_curse_kaki_timah() -> Image.Image:
    img = build_parchment_background(101, PAL["bg_dim"], (36, 17, 17), PAL["crimson_deep"], PAL["iron_dark"])
    draw_sacred_ring_backdrop(img, CX, CY - 12, 154, PAL["ash"], spokes=12, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        draw_footprint_shape(
            d, CX - 16, CY - 64, scale=1.22, angle_deg=-10,
            fill_col=rgba((148, 162, 166), 155),
            outline_col=rgba(PAL["crimson_glow"], 215),
            boot=False,
        )
        for rw, rh, ry, al in ((135, 32, CY + 24, 165), (95, 22, CY + 20, 210)):
            d.arc([CX - rw, ry - rh, CX + rw, ry + rh], 0, 180, fill=rgba(PAL["crimson"], al), width=3)

        d.rounded_rectangle([CX - 56, CY - 46, CX + 28, CY - 8], radius=14, fill=rgba(PAL["iron_dark"], 245), outline=rgba(PAL["iron_light"], 235), width=4)
        for rx in (-42, -14, 14):
            d.ellipse([CX + rx - 4, CY - 31, CX + rx + 4, CY - 23], fill=rgba(PAL["crimson"], 230))

        links = [(CX + 6, CY + 10, 42), (CX + 26, CY + 42, 34), (CX + 42, CY + 76, 26)]
        for lx, ly, ang in links:
            pts = [(lx + math.cos(i / 16.0 * math.tau) * 18, ly + math.sin(i / 16.0 * math.tau) * 10) for i in range(16)]
            d.polygon(rot_pts(pts, lx, ly, ang), outline=rgba(PAL["iron_light"], 245), width=6)
            d.polygon(rot_pts(pts, lx, ly, ang), outline=rgba(PAL["iron_dark"], 245), width=2)

        bx, by, br = CX + 54, CY + 126, 48
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=rgba(PAL["iron_dark"], 255), outline=rgba(PAL["iron_light"], 220), width=4)
        d.arc([bx - br + 10, by - br + 10, bx + br - 10, by + br - 10], 200, 290, fill=rgba(PAL["bone_dim"], 190), width=4)
        d.ellipse([bx - 12, by - br - 8, bx + 12, by - br + 8], fill=rgba(PAL["iron"], 255), outline=rgba(PAL["iron_light"], 230), width=3)

    add_layer_with_glow(img, draw_emblem, PAL["crimson"], glow_radius=15, glow_alpha=155)
    draw_card_frame(img, "curse", PAL["crimson"], PAL["ash_dark"], PAL["crimson_glow"])
    return img


def render_curse_nafas_sesak() -> Image.Image:
    img = build_parchment_background(102, PAL["bg_dim"], (42, 14, 18), PAL["crimson_deep"], (84, 24, 52))
    draw_sacred_ring_backdrop(img, CX, CY, 152, PAL["crimson_deep"], spokes=16, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        # Curved human head/neck/shoulder silhouette tapering smoothly into mist
        head_neck = [
            (CX, CY - 144), (CX + 26, CY - 134), (CX + 30, CY - 104), (CX + 22, CY - 84),
            (CX + 26, CY - 62), (CX + 98, CY - 34), (CX + 110, CY + 26),
            (CX + 86, CY + 108), (CX + 46, CY + 132), (CX - 46, CY + 132),
            (CX - 86, CY + 108), (CX - 110, CY + 26), (CX - 98, CY - 34),
            (CX - 26, CY - 62), (CX - 22, CY - 84), (CX - 30, CY - 104), (CX - 26, CY - 134),
        ]
        d.polygon(head_neck, fill=rgba((22, 10, 12), 245), outline=rgba(PAL["ash"], 195), width=3)

        # Vulnerable ribcage & glowing lung ember
        for sx in (-30, 30):
            d.ellipse([CX + sx - 25, CY - 36, CX + sx + 25, CY + 40], fill=rgba(PAL["crimson_deep"], 150), outline=rgba(PAL["crimson"], 180), width=2)
        for ry in (-20, -2, 16):
            d.arc([CX - 54, CY + ry - 12, CX + 54, CY + ry + 14], 15, 165, fill=rgba(PAL["bone_dim"], 130), width=3)
        d.ellipse([CX - 13, CY - 16, CX + 13, CY + 16], fill=rgba(PAL["crimson_glow"], 220))

        # Sinuous diagonal S-curve suffocating fog tendrils gripping throat & chest
        coils = [
            cubic_bezier((CX - 142, CY + 62), (CX - 54, CY - 12), (CX + 58, CY + 98), (CX + 142, CY + 18), 32),
            cubic_bezier((CX + 142, CY - 44), (CX + 42, CY + 48), (CX - 62, CY - 54), (CX - 140, CY + 14), 32),
            cubic_bezier((CX - 112, CY - 88), (CX - 22, CY - 46), (CX + 26, CY - 88), (CX + 114, CY - 48), 28),
        ]
        for pts in coils:
            d.line(pts, fill=rgba(PAL["crimson_dark"], 225), width=22, joint="curve")
            d.line(pts, fill=rgba(PAL["crimson"], 210), width=9, joint="curve")
            d.line(pts, fill=rgba(PAL["crimson_glow"], 195), width=3, joint="curve")

    add_layer_with_glow(img, draw_emblem, PAL["crimson"], glow_radius=18, glow_alpha=165)
    draw_card_frame(img, "curse", PAL["crimson"], PAL["crimson_dark"], PAL["crimson_glow"])
    return img


def render_curse_senter_redup() -> Image.Image:
    img = build_parchment_background(103, PAL["bg_dim"], (30, 18, 14), PAL["crimson_dark"], (90, 56, 26))
    draw_sacred_ring_backdrop(img, CX, CY, 148, PAL["ash_dark"], spokes=14, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        # Sputtering short amber-crimson cone swallowed by encroaching shadow wisps
        d.polygon([(CX - 14, CY + 6), (CX + 118, CY - 116), (CX + 134, CY - 16)], fill=rgba(PAL["amber"], 52))
        d.polygon([(CX - 10, CY + 4), (CX + 78, CY - 84), (CX + 88, CY - 24)], fill=rgba(PAL["crimson"], 82))

        # Creeping dark shadow claws curling inward over the beam
        for p0, p1, p2 in [
            ((CX + 158, CY - 135), (CX + 104, CY - 92), (CX + 68, CY - 44)),
            ((CX + 158, CY - 74), (CX + 108, CY - 58), (CX + 84, CY - 24)),
            ((CX + 148, CY - 12), (CX + 102, CY - 18), (CX + 72, CY + 4)),
        ]:
            claw = quad_bezier(p0, p1, p2)
            d.line(claw, fill=rgba(PAL["bg_dim"], 245), width=18, joint="curve")
            d.line(claw, fill=rgba(PAL["crimson_deep"], 200), width=4, joint="curve")

        ang = -38.0
        fx, fy = CX - 50, CY + 44
        handle = rot_pts([(fx - 84, fy - 18), (fx + 14, fy - 18), (fx + 14, fy + 18), (fx - 84, fy + 18)], fx, fy, ang)
        head = rot_pts([(fx + 12, fy - 28), (fx + 52, fy - 38), (fx + 52, fy + 38), (fx + 12, fy + 28)], fx, fy, ang)
        d.polygon(handle, fill=rgba(PAL["iron_dark"], 250), outline=rgba(PAL["ash"], 230), width=3)
        d.polygon(head, fill=rgba(PAL["brass"], 220), outline=rgba(PAL["bone_dim"], 230), width=3)
        # Grip bands & switch
        for gx in (-58, -42, -26):
            gb = rot_pts([(fx + gx, fy - 16), (fx + gx, fy + 16)], fx, fy, ang)
            d.line(gb, fill=rgba(PAL["ash"], 160), width=3)

        lens_pts = rot_pts(
            [(fx + 52 + math.cos(i / 16 * math.tau) * 10, fy + math.sin(i / 16 * math.tau) * 34) for i in range(16)],
            fx, fy, ang,
        )
        d.polygon(lens_pts, fill=rgba((86, 52, 34), 240), outline=rgba(PAL["crimson_glow"], 225), width=3)
        lens_c = rot_pts([(fx + 52, fy)], fx, fy, ang)[0]
        for dx, dy in ((-8, -22), (10, -14), (12, 18), (-10, 24)):
            d.line([lens_c, (lens_c[0] + dx, lens_c[1] + dy)], fill=rgba(PAL["bg_dim"], 250), width=3)

        for sx, sy, sr in ((CX + 12, CY - 16, 4.5), (CX + 38, CY - 42, 3.5), (CX + 56, CY - 14, 3.5), (CX + 26, CY - 64, 2.8)):
            d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=rgba(PAL["amber_glow"], 235))

    add_layer_with_glow(img, draw_emblem, PAL["amber"], glow_radius=14, glow_alpha=135)
    draw_card_frame(img, "curse", PAL["crimson"], PAL["ash_dark"], PAL["amber"])
    return img


def render_curse_bisikan_kubur() -> Image.Image:
    img = build_parchment_background(104, PAL["bg_dim"], (36, 13, 30), PAL["violet"], PAL["crimson_deep"])
    draw_sacred_ring_backdrop(img, CX, CY, 152, PAL["violet"], spokes=18, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        for rad, col, w in ((118, PAL["violet"], 4), (146, PAL["crimson"], 3), (172, PAL["violet_glow"], 2)):
            for side in (-1, 1):
                arc_pts = []
                for i in range(17):
                    a = math.radians(-55 + (110 * i / 16.0))
                    jag = (11 if i % 2 == 0 else -7)
                    arc_pts.append((CX + side * math.cos(a) * (rad + jag), CY - 8 + math.sin(a) * (rad + jag)))
                d.line(arc_pts, fill=rgba(col, 215), width=w)

        cranium = [
            (CX, CY - 96), (CX + 48, CY - 84), (CX + 68, CY - 40),
            (CX + 60, CY + 12), (CX + 40, CY + 36), (CX + 34, CY + 78),
            (CX + 18, CY + 92), (CX - 18, CY + 92), (CX - 34, CY + 78),
            (CX - 40, CY + 36), (CX - 60, CY + 12), (CX - 68, CY - 40),
            (CX - 48, CY - 84),
        ]
        d.polygon(cranium, fill=rgba(PAL["bone_dim"], 248), outline=rgba(PAL["violet_glow"], 220), width=3)
        for sx in (-1, 1):
            d.ellipse([CX + sx * 26 - 17, CY - 26, CX + sx * 26 + 17, CY + 12], fill=rgba(PAL["bg_dim"], 255), outline=rgba(PAL["crimson"], 180), width=2)
            d.ellipse([CX + sx * 26 - 4, CY - 11, CX + sx * 26 + 4, CY - 3], fill=rgba(PAL["violet_glow"], 245))
        d.polygon([(CX, CY + 10), (CX + 9, CY + 34), (CX - 9, CY + 34)], fill=rgba(PAL["bg_dim"], 255))
        d.line([(CX - 28, CY + 54), (CX + 28, CY + 54)], fill=rgba(PAL["bg_dim"], 240), width=3)
        for tx in (-18, -6, 6, 18):
            d.line([(CX + tx, CY + 46), (CX + tx, CY + 76)], fill=rgba(PAL["bg_dim"], 240), width=3)

    add_layer_with_glow(img, draw_emblem, PAL["violet"], glow_radius=18, glow_alpha=165)
    draw_card_frame(img, "curse", PAL["crimson"], PAL["violet"], PAL["violet_glow"])
    return img


def render_curse_tatapan_keranda() -> Image.Image:
    img = build_parchment_background(105, PAL["bg_dim"], (13, 34, 22), PAL["keranda"], PAL["crimson_deep"])
    draw_sacred_ring_backdrop(img, CX, CY - 45, 134, PAL["keranda_glow"], spokes=14, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        draw_keranda_silhouette(d, CX, CY + 88, scale=1.18, angle_deg=-4, body_col=(20, 14, 14), shroud_col=PAL["keranda"], trim_col=PAL["keranda_glow"])
        for ox in (-54, 0, 54):
            wisp = quad_bezier((CX + ox, CY + 38), (CX + ox * 0.4, CY + 4), (CX + ox * 0.2, CY - 28))
            d.line(wisp, fill=rgba(PAL["keranda_glow"], 145), width=3)

        ey = CY - 58
        top = quad_bezier((CX - 102, ey), (CX, ey - 68), (CX + 102, ey))
        bot = quad_bezier((CX + 102, ey), (CX, ey + 68), (CX - 102, ey))
        d.polygon(top + bot, fill=rgba((14, 28, 18), 248), outline=rgba(PAL["keranda_glow"], 245), width=4)
        d.ellipse([CX - 42, ey - 42, CX + 42, ey + 42], fill=rgba(PAL["keranda"], 245), outline=rgba(PAL["keranda_glow"], 255), width=3)
        d.ellipse([CX - 28, ey - 28, CX + 28, ey + 28], fill=rgba(PAL["keranda_glow"], 215))
        d.polygon([(CX, ey - 32), (CX + 10, ey), (CX, ey + 32), (CX - 10, ey)], fill=rgba(PAL["bg_dim"], 255))
        for lx, dx, dy in ((-70, -14, -26), (-36, -6, -34), (0, 0, -38), (36, 6, -34), (70, 14, -26)):
            d.line([(CX + lx, ey - 26), (CX + lx + dx, ey - 26 + dy)], fill=rgba(PAL["crimson"], 210), width=3)

    add_layer_with_glow(img, draw_emblem, PAL["keranda_glow"], glow_radius=18, glow_alpha=180)
    draw_card_frame(img, "curse", PAL["keranda_glow"], PAL["crimson_deep"], PAL["keranda_glow"])
    return img


def render_curse_angin_lampor() -> Image.Image:
    img = build_parchment_background(106, PAL["bg_dim"], (16, 36, 22), PAL["keranda"], PAL["crimson_deep"])
    draw_sacred_ring_backdrop(img, CX, CY, 156, PAL["keranda"], spokes=18, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        # Sweeping cyclonic funnel vortex bands (wider top -> tapering bottom)
        for cy_off, rx_base, tilt, col, w in [
            (-112, 148, 14, PAL["keranda"], 16),
            (-64, 128, -10, PAL["crimson"], 11),
            (-12, 108, 10, PAL["keranda_glow"], 8),
            (46, 82, -12, PAL["crimson"], 8),
            (98, 54, 10, PAL["keranda_glow"], 6),
            (138, 28, -6, PAL["crimson_glow"], 4),
        ]:
            pts = [(CX + math.cos(math.radians(-20 + 230 * (i / 27.0))) * rx_base,
                    CY + cy_off + math.sin(math.radians(-20 + 230 * (i / 27.0))) * (rx_base * 0.34))
                   for i in range(28)]
            d.line(rot_pts(pts, CX, CY + cy_off, tilt), fill=rgba(col, 215), width=w, joint="curve")

        for ox, col in ((-40, PAL["keranda_glow"]), (30, PAL["crimson_glow"])):
            s_curve = cubic_bezier(
                (CX + ox - 115, CY - 145), (CX + ox + 125, CY - 45),
                (CX + ox - 110, CY + 55), (CX + ox + 45, CY + 148), 32,
            )
            d.line(s_curve, fill=rgba(col, 200), width=4)

        draw_keranda_silhouette(d, CX + 4, CY - 14, scale=1.08, angle_deg=-20, body_col=PAL["bg_obsidian"], shroud_col=PAL["crimson_deep"], trim_col=PAL["keranda_glow"])

    add_layer_with_glow(img, draw_emblem, PAL["keranda_glow"], glow_radius=17, glow_alpha=175)
    draw_card_frame(img, "curse", PAL["crimson"], PAL["keranda"], PAL["keranda_glow"])
    return img


def render_curse_telinga_setan() -> Image.Image:
    img = build_parchment_background(107, PAL["bg_dim"], (42, 12, 12), PAL["crimson_deep"], (120, 20, 20))
    draw_sacred_ring_backdrop(img, CX, CY, 154, PAL["crimson"], spokes=20, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        for side in (-1, 1):
            for rad, alpha, w in ((88, 235, 5), (120, 205, 4), (154, 175, 3)):
                pts = []
                for i in range(15):
                    a = math.radians(-50 + 100 * (i / 14.0))
                    spike = 14 if i % 2 == 1 else 0
                    pts.append((CX + side * math.cos(a) * (rad + spike), CY + math.sin(a) * (rad + spike)))
                d.line(pts, fill=rgba(PAL["crimson_glow"], alpha), width=w)

        # Ritual ear outer helix & lobe
        ear_outer = cubic_bezier((CX - 42, CY - 84), (CX + 58, CY - 134), (CX + 74, CY - 4), (CX - 14, CY + 104), 28)
        ear_back = cubic_bezier((CX - 14, CY + 104), (CX - 56, CY + 78), (CX - 56, CY - 42), (CX - 42, CY - 84), 22)
        d.polygon(ear_outer + ear_back, fill=rgba((24, 11, 12), 248), outline=rgba(PAL["crimson_glow"], 235), width=4)
        ear_inner = cubic_bezier((CX - 18, CY - 58), (CX + 32, CY - 72), (CX + 34, CY + 4), (CX - 12, CY + 54), 20)
        d.line(ear_inner, fill=rgba(PAL["crimson"], 215), width=4)

        # Occult warning bell sigil suspended inside ear
        bx, by = CX - 2, CY + 10
        bell = [(bx - 12, by - 26), (bx + 12, by - 26), (bx + 26, by + 18), (bx + 34, by + 28), (bx - 34, by + 28), (bx - 26, by + 18)]
        d.polygon(bell, fill=rgba(PAL["crimson_dark"], 245), outline=rgba(PAL["bone"], 230), width=3)
        d.ellipse([bx - 8, by + 26, bx + 8, by + 42], fill=rgba(PAL["crimson_glow"], 255))
        d.ellipse([bx - 6, by - 6, bx + 6, by + 6], fill=rgba(PAL["crimson_glow"], 230))

    add_layer_with_glow(img, draw_emblem, PAL["crimson"], glow_radius=17, glow_alpha=180)
    draw_card_frame(img, "curse", PAL["crimson"], PAL["crimson_dark"], PAL["crimson_glow"])
    return img


def render_curse_waktu_terkutuk() -> Image.Image:
    img = build_parchment_background(108, PAL["bg_dim"], (36, 15, 16), PAL["crimson_deep"], PAL["brass"])
    draw_sacred_ring_backdrop(img, CX, CY, 162, PAL["crimson_dark"], spokes=24, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        r = 128
        d.ellipse([CX - r - 12, CY - r - 12, CX + r + 12, CY + r + 12], fill=rgba(PAL["brass"], 195), outline=rgba(PAL["crimson_glow"], 220), width=4)
        d.ellipse([CX - r, CY - r, CX + r, CY + r], fill=rgba(PAL["bg_obsidian"], 250), outline=rgba(PAL["brass"], 235), width=3)
        d.ellipse([CX - 22, CY - r - 38, CX + 22, CY - r + 4], outline=rgba(PAL["brass"], 235), width=6)

        d.pieslice([CX - r + 12, CY - r + 12, CX + r - 12, CY + r - 12], start=40, end=78, fill=rgba(PAL["crimson_deep"], 150))

        for i in range(12):
            a = math.radians(i * 30 - 90)
            in_r = r * (0.72 if i % 3 == 0 else 0.80)
            out_r = r * 0.92
            col = PAL["crimson_glow"] if i == 5 else PAL["brass"]
            d.line(
                [(CX + math.cos(a) * in_r, CY + math.sin(a) * in_r), (CX + math.cos(a) * out_r, CY + math.sin(a) * out_r)],
                fill=rgba(col, 235),
                width=5 if i in (0, 3, 5, 6, 9) else 3,
            )

        for crack in [
            [(CX - 88, CY - 74), (CX - 26, CY - 24), (CX + 8, CY + 4), (CX + 96, CY + 54)],
            [(CX - 26, CY - 24), (CX - 18, CY - 98)],
            [(CX + 8, CY + 4), (CX - 54, CY + 92)],
        ]:
            d.line(crack, fill=rgba(PAL["crimson_glow"], 220), width=3)

        d.arc([CX - 82, CY - 82, CX + 82, CY + 82], start=-115, end=-55, fill=rgba(PAL["crimson"], 180), width=4)
        d.arc([CX - 58, CY - 58, CX + 58, CY + 58], start=15, end=62, fill=rgba(PAL["crimson_glow"], 195), width=4)

        h_ang = math.radians(60)
        m_ang = math.radians(-84)
        d.polygon([(CX - 8, CY), (CX + math.cos(h_ang) * 76, CY + math.sin(h_ang) * 76), (CX + 8, CY)], fill=rgba(PAL["crimson_glow"], 250))
        d.polygon([(CX - 5, CY), (CX + math.cos(m_ang) * 106, CY + math.sin(m_ang) * 106), (CX + 5, CY)], fill=rgba(PAL["bone"], 250))
        d.ellipse([CX - 11, CY - 11, CX + 11, CY + 11], fill=rgba(PAL["brass"], 255), outline=rgba(PAL["crimson_glow"], 255), width=2)

    add_layer_with_glow(img, draw_emblem, PAL["crimson"], glow_radius=16, glow_alpha=155)
    draw_card_frame(img, "curse", PAL["crimson"], PAL["brass"], PAL["crimson_glow"])
    return img


def render_curse_tungku_dingin() -> Image.Image:
    img = build_parchment_background(109, PAL["bg_dim"], (28, 22, 22), PAL["ash_dark"], PAL["crimson_deep"])
    draw_sacred_ring_backdrop(img, CX, CY, 152, PAL["ash_dark"], spokes=12, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        furnace = [
            (CX - 114, CY + 124), (CX - 102, CY - 24), (CX - 72, CY - 98),
            (CX - 34, CY - 134), (CX + 34, CY - 134), (CX + 72, CY - 98),
            (CX + 102, CY - 24), (CX + 114, CY + 124),
        ]
        d.polygon(furnace, fill=rgba((38, 33, 33), 250), outline=rgba(PAL["ash"], 225), width=4)
        for by in (-66, -24, 18, 62, 100):
            d.line([(CX - 94, CY + by), (CX + 94, CY + by)], fill=rgba(PAL["bg_dim"], 185), width=3)

        d.chord([CX - 66, CY - 58, CX + 66, CY + 96], 180, 360, fill=rgba(PAL["bg_dim"], 255), outline=rgba(PAL["ash"], 200), width=3)
        d.rectangle([CX - 66, CY + 18, CX + 66, CY + 96], fill=rgba(PAL["bg_dim"], 255), outline=rgba(PAL["ash"], 200), width=3)

        d.polygon([(CX - 60, CY + 92), (CX - 22, CY + 56), (CX + 16, CY + 62), (CX + 60, CY + 92)], fill=rgba(PAL["ash_dark"], 240))
        d.ellipse([CX - 24, CY + 42, CX + 24, CY + 80], fill=rgba(PAL["crimson_deep"], 230), outline=rgba(PAL["amber"], 210), width=2)
        d.ellipse([CX - 10, CY + 52, CX + 10, CY + 70], fill=rgba(PAL["crimson_glow"], 245))

        for ox in (-36, 0, 36):
            smk = cubic_bezier((CX + ox, CY + 44), (CX + ox - 28, CY - 18), (CX + ox + 32, CY - 66), (CX + ox * 1.4, CY - 122), 24)
            d.line(smk, fill=rgba(PAL["silver_dim"], 175), width=12, joint="curve")
            d.line(smk, fill=rgba(PAL["ash"], 165), width=4, joint="curve")

    add_layer_with_glow(img, draw_emblem, PAL["ash"], glow_radius=14, glow_alpha=125)
    draw_card_frame(img, "curse", PAL["ash"], PAL["crimson_dark"], PAL["crimson"])
    return img


def render_curse_langkah_berisik() -> Image.Image:
    img = build_parchment_background(110, PAL["bg_dim"], (40, 14, 14), PAL["crimson_deep"])
    draw_sacred_ring_backdrop(img, CX, CY, 156, PAL["crimson_dark"], spokes=16, jagged=True)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        for rx, ry, col, w in ((92, 62, PAL["crimson"], 4), (134, 92, PAL["crimson_glow"], 3), (174, 122, PAL["crimson_deep"], 3)):
            ring = []
            n = 36
            for i in range(n + 1):
                a = (i / n) * math.tau
                spike = 16 if i % 3 == 0 else -4
                ring.append((CX + math.cos(a) * (rx + spike), CY + 10 + math.sin(a) * (ry + spike * 0.7)))
            d.line(ring, fill=rgba(col, 220), width=w)

        for ty, tx_off in ((-18, -14), (24, 12)):
            d.line([(CX - 118, CY + ty + 24), (CX - 16 + tx_off, CY + ty - 6)], fill=rgba(PAL["brass"], 235), width=9)
            d.line([(CX + 16 + tx_off, CY + ty - 6), (CX + 118, CY + ty + 26)], fill=rgba(PAL["brass"], 235), width=9)
            for sa in (-60, -25, 25, 60):
                rad = math.radians(sa - 90)
                d.line(
                    [(CX + tx_off, CY + ty - 8), (CX + tx_off + math.cos(rad) * 26, CY + ty - 8 + math.sin(rad) * 26)],
                    fill=rgba(PAL["crimson_glow"], 250),
                    width=3,
                )

        draw_footprint_shape(
            d, CX, CY - 4, scale=1.35, angle_deg=-12,
            fill_col=rgba(PAL["crimson_dark"], 240),
            outline_col=rgba(PAL["crimson_glow"], 245),
            boot=True,
        )

    add_layer_with_glow(img, draw_emblem, PAL["crimson"], glow_radius=16, glow_alpha=170)
    draw_card_frame(img, "curse", PAL["crimson"], PAL["crimson_dark"], PAL["crimson_glow"])
    return img


# ---------------------------------------------------------------------------
# 10 Keberuntungan / Blessings
# ---------------------------------------------------------------------------

def render_blessing_langkah_angin() -> Image.Image:
    img = build_parchment_background(201, PAL["bg_warm"], (42, 30, 14), PAL["gold_dark"], PAL["emerald"])
    draw_sacred_ring_backdrop(img, CX, CY, 154, PAL["gold"], spokes=16, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        # Sweeping curved Garuda/angel spirit wings built with bezier arcs
        for side in (-1, 1):
            for idx, (tip_x, tip_y, base_y, col) in enumerate([
                (156, -124, 6, PAL["gold"]),
                (140, -68, 22, PAL["amber_glow"]),
                (112, -16, 36, PAL["gold_bright"]),
            ]):
                top_edge = quad_bezier((CX + side * 22, CY + base_y - 24), (CX + side * tip_x * 0.52, CY + tip_y - 18), (CX + side * tip_x, CY + tip_y))
                bot_edge = quad_bezier((CX + side * tip_x, CY + tip_y), (CX + side * tip_x * 0.65, CY + base_y + 10), (CX + side * 20, CY + base_y + 14))
                d.polygon(top_edge + bot_edge, fill=rgba(col, 215), outline=rgba(PAL["gold_bright"], 245), width=2)

        for dy, col in ((70, PAL["sage"]), (98, PAL["gold_bright"])):
            gust = cubic_bezier((CX - 128, CY + dy + 18), (CX - 36, CY + dy - 26), (CX + 38, CY + dy + 22), (CX + 132, CY + dy - 22), 28)
            d.line(gust, fill=rgba(col, 225), width=5)

        draw_footprint_shape(
            d, CX, CY - 4, scale=1.22, angle_deg=8,
            fill_col=rgba(PAL["gold"], 238),
            outline_col=rgba(PAL["gold_bright"], 255),
            boot=False,
        )

    add_layer_with_glow(img, draw_emblem, PAL["gold"], glow_radius=18, glow_alpha=175)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["brass"], PAL["gold_bright"])
    return img


def render_blessing_nafas_pendekar() -> Image.Image:
    img = build_parchment_background(202, PAL["bg_warm"], (46, 28, 13), PAL["amber"], PAL["gold_dark"])
    draw_sacred_ring_backdrop(img, CX, CY, 152, PAL["amber_glow"], spokes=12, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        shield = [
            (CX, CY - 134), (CX + 104, CY - 92), (CX + 92, CY + 34),
            (CX + 52, CY + 104), (CX, CY + 138), (CX - 52, CY + 104),
            (CX - 92, CY + 34), (CX - 104, CY - 92),
        ]
        d.polygon(shield, fill=rgba((58, 32, 14), 215), outline=rgba(PAL["gold_bright"], 250), width=4)

        for r, col, w in ((80, PAL["amber"], 4), (56, PAL["amber_glow"], 4), (32, PAL["gold_bright"], 3)):
            d.ellipse([CX - r, CY - r, CX + r, CY + r], outline=rgba(col, 230), width=w)

        # Warrior lungs & lotus breath diamond inside shield
        for sx in (-22, 22):
            lung = quad_bezier((CX + sx * 0.25, CY - 24), (CX + sx * 2.2, CY - 22), (CX + sx * 1.4, CY + 24))
            lung += quad_bezier((CX + sx * 1.4, CY + 24), (CX + sx * 0.4, CY + 18), (CX + sx * 0.25, CY - 24))
            d.polygon(lung, fill=rgba(PAL["amber"], 210), outline=rgba(PAL["gold_bright"], 240), width=2)
        d.polygon([(CX, CY - 18), (CX + 16, CY), (CX, CY + 18), (CX - 16, CY)], fill=rgba(PAL["gold_bright"], 250))

        for sx in (-1, 1):
            breath = cubic_bezier((CX + sx * 12, CY - 28), (CX + sx * 48, CY - 62), (CX + sx * 18, CY - 94), (CX + sx * 42, CY - 118), 20)
            d.line(breath, fill=rgba(PAL["gold_bright"], 220), width=4)

    add_layer_with_glow(img, draw_emblem, PAL["amber_glow"], glow_radius=18, glow_alpha=180)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["amber"], PAL["gold_bright"])
    return img


def render_blessing_cahaya_pusaka() -> Image.Image:
    img = build_parchment_background(203, PAL["bg_warm"], (44, 34, 15), PAL["gold"], PAL["amber"])
    draw_sacred_ring_backdrop(img, CX, CY, 154, PAL["brass"], spokes=16, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        # Soft radial rays & layered translucent beam (no sharp cropped triangle edge)
        for ray_w, al in ((72, 48), (48, 82), (26, 130)):
            d.polygon([(CX - 18, CY + 16), (CX + 132, CY - 154), (CX + 164, CY - 16)], fill=rgba(PAL["gold_bright"], al))
            # Fan rays inside beam
            for ang in (-58, -44, -30, -16):
                rad = math.radians(ang)
                ln = 205 if ang in (-44, -30) else 170
                d.line([(CX - 12, CY + 14), (CX - 12 + math.cos(rad) * ln, CY + 14 + math.sin(rad) * ln)], fill=rgba(PAL["gold_bright"], al + 30), width=ray_w // 10)

        for sx, sy in ((CX - 46, CY - 92), (CX + 78, CY + 78)):
            mist = quad_bezier((sx - 50, sy), (sx, sy - 24), (sx + 52, sy + 12))
            d.line(mist, fill=rgba(PAL["ash"], 120), width=9)

        ang = -40.0
        fx, fy = CX - 56, CY + 48
        body = rot_pts([(fx - 78, fy - 18), (fx + 14, fy - 18), (fx + 14, fy + 18), (fx - 78, fy + 18)], fx, fy, ang)
        head = rot_pts([(fx + 12, fy - 28), (fx + 52, fy - 40), (fx + 52, fy + 40), (fx + 12, fy + 28)], fx, fy, ang)
        d.polygon(body, fill=rgba(PAL["gold_dark"], 250), outline=rgba(PAL["gold_bright"], 245), width=3)
        d.polygon(head, fill=rgba(PAL["brass"], 250), outline=rgba(PAL["gold_bright"], 255), width=3)
        lens_pts = rot_pts(
            [(fx + 52 + math.cos(i / 16 * math.tau) * 10, fy + math.sin(i / 16 * math.tau) * 34) for i in range(16)],
            fx, fy, ang,
        )
        d.polygon(lens_pts, fill=rgba(PAL["gold_bright"], 255), outline=rgba(PAL["amber_glow"], 255), width=3)

        for mx, my, mr in ((CX + 46, CY - 44, 5), (CX + 92, CY - 88, 4), (CX + 112, CY - 34, 4.5), (CX + 62, CY - 98, 3)):
            d.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=rgba(PAL["gold_bright"], 245))

    add_layer_with_glow(img, draw_emblem, PAL["gold_bright"], glow_radius=20, glow_alpha=185)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["brass"], PAL["gold_bright"])
    return img


def render_blessing_jiwa_tenang() -> Image.Image:
    img = build_parchment_background(204, PAL["bg_warm"], (20, 36, 26), PAL["emerald"], PAL["gold"])
    draw_sacred_ring_backdrop(img, CX, CY, 154, PAL["sage"], spokes=16, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        # Celestial star cradled inside the crescent opening
        d.polygon([(CX + 22, CY - 102), (CX + 26, CY - 90), (CX + 38, CY - 86), (CX + 26, CY - 82), (CX + 22, CY - 70), (CX + 18, CY - 82), (CX + 6, CY - 86), (CX + 18, CY - 90)], fill=rgba(PAL["gold_bright"], 240))

        for ry, rw, al in ((CY + 94, 118, 175), (CY + 112, 86, 130)):
            d.arc([CX - rw, ry - 18, CX + rw, ry + 18], 0, 180, fill=rgba(PAL["sage"], al), width=3)

        ly = CY + 42
        petals = [
            (0, -82, 24, PAL["gold_bright"]),
            (-36, -68, 22, PAL["gold"]),
            (36, -68, 22, PAL["gold"]),
            (-68, -40, 20, PAL["sage"]),
            (68, -40, 20, PAL["sage"]),
            (-86, -10, 18, PAL["emerald"]),
            (86, -10, 18, PAL["emerald"]),
        ]
        for px_off, py_off, w_half, col in reversed(petals):
            tip_x, tip_y = CX + px_off, ly + py_off
            p_poly = [
                (CX + px_off * 0.18, ly + 30),
                (CX + px_off * 0.65 - w_half, ly + py_off * 0.45),
                (tip_x, tip_y),
                (CX + px_off * 0.65 + w_half, ly + py_off * 0.45),
            ]
            d.polygon(p_poly, fill=rgba(col, 228), outline=rgba(PAL["gold_bright"], 245), width=2)
        d.ellipse([CX - 14, ly - 10, CX + 14, ly + 18], fill=rgba(PAL["emerald_bright"], 245), outline=rgba(PAL["gold_bright"], 255), width=3)

    def post_moon(fg: Image.Image) -> None:
        paste_crescent_moon(fg, CX, CY - 84, r_outer=52, inner_dx=22, inner_dy=-14, r_inner=44, fill_rgb=PAL["gold_bright"], outline_rgb=PAL["gold"])

    add_layer_with_glow(img, draw_emblem, PAL["gold"], glow_radius=18, glow_alpha=175, layer_post_fn=post_moon)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["emerald"], PAL["emerald_bright"])
    return img


def render_blessing_api_keramat() -> Image.Image:
    img = build_parchment_background(205, PAL["bg_warm"], (48, 24, 12), PAL["amber"], PAL["gold"])
    draw_sacred_ring_backdrop(img, CX, CY - 8, 154, PAL["amber"], spokes=16, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        # Organic curved soaring sacred flame tongues (cubic beziers)
        outer_r = cubic_bezier((CX, CY - 156), (CX + 32, CY - 96), (CX + 102, CY - 32), (CX + 68, CY + 62), 24)
        outer_l = cubic_bezier((CX - 68, CY + 62), (CX - 102, CY - 32), (CX - 32, CY - 96), (CX, CY - 156), 24)
        d.polygon(outer_r + outer_l, fill=rgba(PAL["amber"], 235), outline=rgba(PAL["gold_bright"], 245), width=2)

        # Side flickering flame licks
        for sx in (-1, 1):
            lick = quad_bezier((CX + sx * 48, CY + 42), (CX + sx * 96, CY - 24), (CX + sx * 76, CY - 94))
            lick += quad_bezier((CX + sx * 76, CY - 94), (CX + sx * 66, CY - 28), (CX + sx * 36, CY + 24))
            d.polygon(lick, fill=rgba(PAL["amber_glow"], 220))

        mid_r = cubic_bezier((CX - 4, CY - 118), (CX + 26, CY - 62), (CX + 62, CY - 12), (CX + 42, CY + 62), 20)
        mid_l = cubic_bezier((CX - 42, CY + 62), (CX - 62, CY - 12), (CX - 26, CY - 62), (CX - 4, CY - 118), 20)
        d.polygon(mid_r + mid_l, fill=rgba(PAL["gold"], 245))

        core_r = cubic_bezier((CX, CY - 68), (CX + 22, CY - 18), (CX + 34, CY + 24), (CX + 18, CY + 60), 16)
        core_l = cubic_bezier((CX - 18, CY + 60), (CX - 34, CY + 24), (CX - 22, CY - 18), (CX, CY - 68), 16)
        d.polygon(core_r + core_l, fill=rgba(PAL["gold_bright"], 255))

        bowl = [
            (CX - 94, CY + 56), (CX + 94, CY + 56),
            (CX + 74, CY + 106), (CX + 88, CY + 128),
            (CX - 88, CY + 128), (CX - 74, CY + 106),
        ]
        d.polygon(bowl, fill=rgba((52, 36, 28), 255), outline=rgba(PAL["brass"], 245), width=3)
        d.line([(CX - 74, CY + 78), (CX + 74, CY + 78)], fill=rgba(PAL["amber_glow"], 195), width=3)

        for sx, sy, sr in ((CX - 54, CY - 112, 4), (CX + 58, CY - 118, 4.5), (CX - 22, CY - 144, 3), (CX + 26, CY - 150, 3.5)):
            d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=rgba(PAL["gold_bright"], 245))

    add_layer_with_glow(img, draw_emblem, PAL["amber_glow"], glow_radius=20, glow_alpha=185)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["amber"], PAL["gold_bright"])
    return img


def render_blessing_bekal_jamu() -> Image.Image:
    img = build_parchment_background(206, PAL["bg_warm"], (18, 42, 26), PAL["emerald"], PAL["gold"])
    draw_sacred_ring_backdrop(img, CX, CY, 148, PAL["sage"], spokes=12, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        # Organic curved golden-emerald herbal leaves wrapping gracefully around bottle
        for side in (-1, 1):
            for base_y, tip_x, tip_y in ((CY + 44, 128, CY - 46), (CY + 78, 134, CY + 4), (CY + 102, 110, CY + 56)):
                bx = CX + side * 52
                tx = CX + side * tip_x
                upper = quad_bezier((bx, base_y), (CX + side * 96, base_y - 46), (tx, tip_y))
                lower = quad_bezier((tx, tip_y), (CX + side * 108, base_y + 6), (bx, base_y))
                d.polygon(upper + lower, fill=rgba(PAL["emerald"], 228), outline=rgba(PAL["gold"], 240), width=2)
                midrib = quad_bezier((bx, base_y), (CX + side * 98, (base_y + tip_y) * 0.5 - 8), (tx, tip_y))
                d.line(midrib, fill=rgba(PAL["gold_bright"], 220), width=2)

        bottle = [
            (CX - 22, CY - 84), (CX + 22, CY - 84),
            (CX + 22, CY - 46), (CX + 62, CY - 12),
            (CX + 66, CY + 92), (CX + 46, CY + 114),
            (CX - 46, CY + 114), (CX - 66, CY + 92),
            (CX - 62, CY - 12), (CX - 22, CY - 46),
        ]
        d.polygon(bottle, fill=rgba((24, 52, 36), 210), outline=rgba(PAL["gold_bright"], 245), width=4)

        elixir = [
            (CX - 56, CY + 8), (CX + 56, CY + 8),
            (CX + 60, CY + 88), (CX + 42, CY + 108),
            (CX - 42, CY + 108), (CX - 60, CY + 88),
        ]
        d.polygon(elixir, fill=rgba(PAL["emerald"], 230), outline=rgba(PAL["emerald_bright"], 235), width=2)
        d.ellipse([CX - 54, CY - 2, CX + 54, CY + 20], fill=rgba(PAL["gold"], 215))

        d.polygon([(CX - 18, CY - 118), (CX + 18, CY - 118), (CX + 14, CY - 84), (CX - 14, CY - 84)], fill=rgba(PAL["brass"], 250), outline=rgba(PAL["gold_bright"], 255), width=3)
        d.rounded_rectangle([CX - 28, CY - 88, CX + 28, CY - 74], radius=6, fill=rgba(PAL["gold"], 250), outline=rgba(PAL["gold_bright"], 255), width=2)
        d.line([(CX - 44, CY + 4), (CX - 44, CY + 82)], fill=rgba(PAL["gold_bright"], 215), width=5)

    add_layer_with_glow(img, draw_emblem, PAL["emerald_bright"], glow_radius=18, glow_alpha=180)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["emerald"], PAL["emerald_bright"])
    return img


def render_blessing_gema_kentongan() -> Image.Image:
    img = build_parchment_background(207, PAL["bg_warm"], (44, 30, 14), PAL["amber"], PAL["gold"])
    draw_sacred_ring_backdrop(img, CX, CY, 156, PAL["brass"], spokes=16, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        for side in (-1, 1):
            for rad, col, w in ((74, PAL["gold_bright"], 5), (110, PAL["gold"], 4), (146, PAL["amber_glow"], 3)):
                d.arc(
                    [CX - rad, CY - rad * 0.85, CX + rad, CY + rad * 0.85],
                    start=(-48 if side == 1 else 132),
                    end=(48 if side == 1 else 228),
                    fill=rgba(col, 230),
                    width=w,
                )

        d.ellipse([CX - 16, CY - 148, CX + 16, CY - 102], outline=rgba(PAL["brass"], 240), width=5)
        body = [(CX - 34, CY - 106), (CX + 34, CY - 106), (CX + 38, CY + 104), (CX - 38, CY + 104)]
        d.polygon(body, fill=rgba((96, 66, 30), 255), outline=rgba(PAL["gold_bright"], 245), width=4)
        for ny in (CY - 52, CY + 54):
            d.line([(CX - 38, ny), (CX + 38, ny)], fill=rgba(PAL["gold"], 235), width=5)

        d.rounded_rectangle([CX - 9, CY - 40, CX + 9, CY + 44], radius=6, fill=rgba(PAL["bg_dim"], 255), outline=rgba(PAL["amber_glow"], 235), width=3)
        baton = rot_pts([(CX + 46, CY - 6), (CX + 106, CY - 6), (CX + 106, CY + 10), (CX + 46, CY + 10)], CX + 54, CY, 34)
        d.polygon(baton, fill=rgba(PAL["brass"], 250), outline=rgba(PAL["gold_bright"], 245), width=3)

    add_layer_with_glow(img, draw_emblem, PAL["gold"], glow_radius=18, glow_alpha=175)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["amber"], PAL["gold_bright"])
    return img


def render_blessing_langkah_bayangan() -> Image.Image:
    img = build_parchment_background(208, (18, 17, 22), (32, 32, 42), PAL["silver_dim"], PAL["gold_dark"])
    draw_sacred_ring_backdrop(img, CX, CY, 152, PAL["silver"], spokes=16, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        draw_footprint_shape(
            d, CX - 6, CY - 4, scale=1.28, angle_deg=-8,
            fill_col=rgba(PAL["silver"], 178),
            outline_col=rgba(PAL["gold_bright"], 242),
            boot=False,
        )

        for dy, col, w in ((24, PAL["silver"], 14), (56, PAL["gold"], 9), (86, PAL["silver"], 12)):
            mist = cubic_bezier((CX - 134, CY + dy + 12), (CX - 44, CY + dy - 28), (CX + 46, CY + dy + 22), (CX + 134, CY + dy - 14), 28)
            d.line(mist, fill=rgba(col, 175), width=w, joint="curve")
            d.line(mist, fill=rgba(PAL["gold_bright"], 190), width=2)

    def post_moon(fg: Image.Image) -> None:
        paste_crescent_moon(fg, CX + 72, CY - 114, r_outer=28, inner_dx=13, inner_dy=-9, r_inner=24, fill_rgb=PAL["gold_bright"], outline_rgb=PAL["gold"])

    add_layer_with_glow(img, draw_emblem, PAL["silver"], glow_radius=17, glow_alpha=155, layer_post_fn=post_moon)
    draw_card_frame(img, "blessing", PAL["silver"], PAL["brass"], PAL["gold_bright"])
    return img


def render_blessing_waktu_melambat() -> Image.Image:
    img = build_parchment_background(209, PAL["bg_warm"], (26, 26, 40), PAL["midnight_sand"], PAL["gold_dark"])
    draw_sacred_ring_backdrop(img, CX, CY, 152, PAL["gold"], spokes=12, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        d.rounded_rectangle([CX - 76, CY - 134, CX + 76, CY - 114], radius=6, fill=rgba(PAL["brass"], 255), outline=rgba(PAL["gold_bright"], 255), width=3)
        d.rounded_rectangle([CX - 76, CY + 114, CX + 76, CY + 134], radius=6, fill=rgba(PAL["brass"], 255), outline=rgba(PAL["gold_bright"], 255), width=3)
        for px in (-62, 62):
            d.line([(CX + px, CY - 114), (CX + px, CY + 114)], fill=rgba(PAL["gold"], 235), width=6)

        top_glass = cubic_bezier((CX - 54, CY - 114), (CX - 54, CY - 28), (CX - 14, CY - 18), (CX - 8, CY), 20)
        top_glass += list(reversed(cubic_bezier((CX + 54, CY - 114), (CX + 54, CY - 28), (CX + 14, CY - 18), (CX + 8, CY), 20)))
        bot_glass = cubic_bezier((CX - 8, CY), (CX - 14, CY + 18), (CX - 54, CY + 28), (CX - 54, CY + 114), 20)
        bot_glass += list(reversed(cubic_bezier((CX + 8, CY), (CX + 14, CY + 18), (CX + 54, CY + 28), (CX + 54, CY + 114), 20)))
        d.polygon(top_glass, fill=rgba((24, 30, 52), 200), outline=rgba(PAL["gold_bright"], 240), width=3)
        d.polygon(bot_glass, fill=rgba((24, 30, 52), 200), outline=rgba(PAL["gold_bright"], 240), width=3)

        upper_sand = [(CX - 46, CY - 78), (CX + 46, CY - 78), (CX + 26, CY - 22), (CX + 6, CY - 2), (CX - 6, CY - 2), (CX - 26, CY - 22)]
        d.polygon(upper_sand, fill=rgba(PAL["midnight_sand"], 240), outline=rgba(PAL["gold_bright"], 220), width=2)
        d.line([(CX, CY), (CX, CY + 96)], fill=rgba(PAL["gold_bright"], 220), width=3)
        d.polygon([(CX - 48, CY + 112), (CX, CY + 82), (CX + 48, CY + 112)], fill=rgba(PAL["midnight_sand"], 240), outline=rgba(PAL["gold"], 210), width=2)
        d.ellipse([CX - 36, CY - 12, CX + 36, CY + 12], outline=rgba(PAL["gold_bright"], 235), width=3)

    add_layer_with_glow(img, draw_emblem, PAL["gold"], glow_radius=17, glow_alpha=170)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["brass"], PAL["gold_bright"])
    return img


def render_blessing_jimat_pelindung() -> Image.Image:
    img = build_parchment_background(210, PAL["bg_warm"], (44, 30, 14), PAL["gold"], PAL["emerald"])
    draw_sacred_ring_backdrop(img, CX, CY - 8, 158, PAL["gold"], spokes=24, jagged=False)

    def draw_emblem(d: ImageDraw.ImageDraw) -> None:
        my = CY - 14
        d.ellipse([CX - 108, my - 108, CX + 108, my + 108], fill=rgba((38, 22, 14), 245), outline=rgba(PAL["gold_bright"], 250), width=5)
        d.ellipse([CX - 90, my - 90, CX + 90, my + 90], outline=rgba(PAL["brass"], 225), width=3)

        draw_kawung_rosette(d, CX, my, 82, rgba(PAL["gold"], 160), rgba(PAL["gold_dark"], 130), rgba(PAL["gold_bright"], 200))
        draw_keris_blade(d, CX, my - 4, 215, 0, PAL["gold"], PAL["gold_bright"], PAL["brass"])

        for cx_off, cy_off, cr in ((-48, CY + 96, 28), (48, CY + 96, 28), (0, CY + 110, 32)):
            d.ellipse([CX + cx_off - cr, cy_off - cr, CX + cx_off + cr, cy_off + cr], fill=rgba(PAL["gold"], 255), outline=rgba(PAL["gold_bright"], 255), width=3)
            d.ellipse([CX + cx_off - cr + 7, cy_off - cr + 7, CX + cx_off + cr - 7, cy_off + cr - 7], outline=rgba(PAL["gold_dark"], 220), width=2)
            hr = cr * 0.28
            d.rectangle([CX + cx_off - hr, cy_off - hr, CX + cx_off + hr, cy_off + hr], fill=rgba(PAL["bg_obsidian"], 245), outline=rgba(PAL["gold_bright"], 230), width=2)

    add_layer_with_glow(img, draw_emblem, PAL["gold_bright"], glow_radius=19, glow_alpha=185)
    draw_card_frame(img, "blessing", PAL["gold"], PAL["brass"], PAL["gold_bright"])
    return img


CARD_RENDERERS: dict[str, Callable[[], Image.Image]] = {
    "card_back": render_card_back,
    # 10 Kutukan
    "curse_kaki_timah": render_curse_kaki_timah,
    "curse_nafas_sesak": render_curse_nafas_sesak,
    "curse_senter_redup": render_curse_senter_redup,
    "curse_bisikan_kubur": render_curse_bisikan_kubur,
    "curse_tatapan_keranda": render_curse_tatapan_keranda,
    "curse_angin_lampor": render_curse_angin_lampor,
    "curse_telinga_setan": render_curse_telinga_setan,
    "curse_waktu_terkutuk": render_curse_waktu_terkutuk,
    "curse_tungku_dingin": render_curse_tungku_dingin,
    "curse_langkah_berisik": render_curse_langkah_berisik,
    # 10 Keberuntungan
    "blessing_langkah_angin": render_blessing_langkah_angin,
    "blessing_nafas_pendekar": render_blessing_nafas_pendekar,
    "blessing_cahaya_pusaka": render_blessing_cahaya_pusaka,
    "blessing_jiwa_tenang": render_blessing_jiwa_tenang,
    "blessing_api_keramat": render_blessing_api_keramat,
    "blessing_bekal_jamu": render_blessing_bekal_jamu,
    "blessing_gema_kentongan": render_blessing_gema_kentongan,
    "blessing_langkah_bayangan": render_blessing_langkah_bayangan,
    "blessing_waktu_melambat": render_blessing_waktu_melambat,
    "blessing_jimat_pelindung": render_blessing_jimat_pelindung,
}


def compute_image_stats(img: Image.Image) -> tuple[float, float]:
    """Return (mean_luma, std_dev_luma) across pixels without numpy."""
    gray = img.convert("L")
    hist = gray.histogram()
    total = sum(hist)
    mean = sum(i * c for i, c in enumerate(hist)) / total
    var = sum(((i - mean) ** 2) * c for i, c in enumerate(hist)) / total
    return mean, math.sqrt(var)


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    hashes: dict[str, str] = {}

    for card_id, render_fn in CARD_RENDERERS.items():
        hi_res = render_fn()
        final_img = hi_res.resize((OUT_W, OUT_H), Image.Resampling.LANCZOS)
        final_img = ImageEnhance.Contrast(final_img).enhance(1.04)

        out_path = OUT_DIR / f"{card_id}.png"
        final_img.save(out_path, format="PNG")

        with Image.open(out_path) as check:
            check.load()
            assert check.size == (OUT_W, OUT_H), f"{card_id}: unexpected size {check.size}"
            assert check.format == "PNG", f"{card_id}: unexpected format {check.format}"
            mean_luma, std_luma = compute_image_stats(check)
            assert std_luma > 10.0, f"{card_id}: low pixel variance ({std_luma:.2f})"
            digest = hashlib.sha256(check.tobytes()).hexdigest()[:12]
            assert digest not in hashes.values(), f"{card_id}: duplicate pixel hash {digest}"
            hashes[card_id] = digest
            print(f"[OK] {out_path.name:30s} {check.size[0]}x{check.size[1]} luma={mean_luma:5.1f} std={std_luma:5.1f} sha={digest}", flush=True)

    assert len(hashes) == 21, f"Expected 21 cards, generated {len(hashes)}"
    print(f"\nGenerated and verified all {len(hashes)} Fate Card artworks in {OUT_DIR}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
