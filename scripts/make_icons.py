"""Generate the 1024px app icon (opaque RGB, as App Store / Xcode require). Plain mark, no font dependency."""
from PIL import Image, ImageDraw

BG, FG = (47, 74, 58), (246, 243, 236)


def icon(size: int, path: str) -> None:
    img = Image.new("RGB", (size, size), BG)
    d = ImageDraw.Draw(img)
    s = size
    w = max(2, int(s * 0.06))
    # Stylised pencil-on-line mark: a writing line and a stroke above it.
    m = int(s * 0.24)
    d.line([(m, int(s * 0.70)), (s - m, int(s * 0.70))], fill=FG, width=w)
    d.line([(int(s * 0.34), int(s * 0.58)), (int(s * 0.66), int(s * 0.30))], fill=FG, width=int(w * 1.6))
    d.ellipse([int(s * 0.62), int(s * 0.26), int(s * 0.70), int(s * 0.34)], fill=FG)
    img.save(path)


icon(1024, "Tingxie/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
