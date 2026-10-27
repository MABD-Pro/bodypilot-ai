"""Génère l'icône de l'app et le logo de l'écran de lancement (PNG).

Usage : python3 scripts/generate_brand_assets.py
Le motif : une trajectoire qui monte (le cap tenu par le coach) au-dessus de quelques
pesées dispersées, sur le dégradé de marque corail → rose → indigo.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent / "App" / "Resources" / "Assets.xcassets"
SS = 4  # suréchantillonnage pour des bords lisses

CORAL = np.array([255, 138, 91])
PINK = np.array([255, 79, 123])
INDIGO = np.array([88, 86, 255])


def gradient(size: int) -> Image.Image:
    y, x = np.mgrid[0:size, 0:size] / (size - 1)
    t = np.clip(x * 0.45 + y * 0.55, 0, 1)[..., None]
    first = CORAL + (PINK - CORAL) * np.clip(t / 0.5, 0, 1)
    rgb = np.where(t < 0.5, first, PINK + (INDIGO - PINK) * np.clip((t - 0.5) / 0.5, 0, 1))
    # Halo clair en haut à gauche pour la profondeur.
    d = np.sqrt((x - 0.2) ** 2 + (y - 0.15) ** 2)
    glow = np.clip(1 - d / 0.75, 0, 1)[..., None] ** 2 * 60
    rgb = np.clip(rgb + glow, 0, 255).astype(np.uint8)
    return Image.fromarray(rgb, "RGB").convert("RGBA")


def bezier(p0, p1, p2, p3, steps=200):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t ** 2
        d = t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def mark(size: int) -> Image.Image:
    """Le motif blanc seul, sur fond transparent."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    s = size
    # Pesées dispersées sous la courbe.
    for (cx, cy, r, alpha) in [(0.27, 0.62, 0.028, 120), (0.40, 0.66, 0.024, 105), (0.52, 0.50, 0.026, 115), (0.63, 0.47, 0.022, 100)]:
        draw.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=(255, 255, 255, alpha))
    # Trajectoire.
    # Tracé par tampons circulaires serrés : trait épais sans artefacts de jointure.
    path = bezier((0.20, 0.74), (0.42, 0.76), (0.50, 0.36), (0.74, 0.30), steps=1500)
    half = 0.0425 * s
    pts = [(x * s, y * s) for x, y in path]
    for x, y in pts:
        draw.ellipse([x - half, y - half, x + half, y + half], fill=(255, 255, 255, 255))
    # Point d'arrivée avec halo.
    end = pts[-1]
    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    r = 0.13 * s
    hd.ellipse([end[0] - r, end[1] - r, end[0] + r, end[1] + r], fill=(255, 255, 255, 110))
    halo = halo.filter(ImageFilter.GaussianBlur(0.04 * s))
    layer = Image.alpha_composite(halo, layer)
    draw = ImageDraw.Draw(layer)
    r = 0.072 * s
    draw.ellipse([end[0] - r, end[1] - r, end[0] + r, end[1] + r], fill=(255, 255, 255, 255))
    return layer


def icon(size: int) -> Image.Image:
    big = size * SS
    img = Image.alpha_composite(gradient(big), mark(big))
    return img.resize((size, size), Image.LANCZOS).convert("RGB")


def rounded_logo(size: int) -> Image.Image:
    """Icône arrondie pour l'écran de lancement."""
    big = size * SS
    img = Image.alpha_composite(gradient(big), mark(big))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.2237), fill=255)
    img.putalpha(mask)
    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    icon(1024).save(ROOT / "AppIcon.appiconset" / "AppIcon.png")
    logo_dir = ROOT / "LaunchLogo.imageset"
    logo_dir.mkdir(exist_ok=True)
    for scale in (1, 2, 3):
        rounded_logo(112 * scale).save(logo_dir / f"LaunchLogo@{scale}x.png")
    print("Icône et logo générés.")
