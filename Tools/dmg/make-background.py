from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, subprocess
W, H = 660, 440

def make(scale, icon_path):
    w, h = W * scale, H * scale
    top, bot = (104, 160, 122), (52, 100, 74)
    base = Image.new("RGB", (w, h))
    px = base.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    im = base.convert("RGBA")

    cx, cy = w / 2, 74 * scale

    icon = Image.open(icon_path).convert("RGBA")
    size = 92 * scale
    icon = icon.resize((size, size), Image.LANCZOS)
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (int(cx - size / 2), int(cy - size / 2 + 6 * scale)), icon.split()[3])
    im = Image.alpha_composite(im, shadow.filter(ImageFilter.GaussianBlur(7 * scale)))
    im.alpha_composite(icon, (int(cx - size / 2), int(cy - size / 2)))

    d = ImageDraw.Draw(im, "RGBA")

    def font(size, italic=False):
        name = "Georgia Italic.ttf" if italic else "Georgia.ttf"
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/" + name, size * scale)

    def centered(text, y, f, fill, tracking=0.0):
        widths = [d.textlength(ch, font=f) for ch in text]
        total = sum(widths) + tracking * scale * (len(text) - 1)
        x = (w - total) / 2
        for ch, cw in zip(text, widths):
            d.text((x, y * scale), ch, font=f, fill=fill)
            x += cw + tracking * scale

    centered("Keeps your Mac awake while exports, renders and builds run.", 132, font(15), (240, 248, 238, 235), tracking=0.2)
    centered("Double click Matcha, then choose Move to Applications", 186, font(21), (255, 255, 255, 245), tracking=0.5)
    centered("Or drag Matcha onto Applications yourself.", 224, font(14, italic=True), (240, 248, 238, 220), tracking=0.2)

    y = 312 * scale
    x0, x1 = 268 * scale, 392 * scale
    arrow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arrow)
    ad.line([(x0, y), (x1, y)], fill=(255, 255, 255, 170), width=2 * scale)
    ad.line([(x1 - 11 * scale, y - 9 * scale), (x1, y), (x1 - 11 * scale, y + 9 * scale)], fill=(255, 255, 255, 170), width=2 * scale, joint="curve")
    im = Image.alpha_composite(im, arrow)
    return im.convert("RGB")

here = os.path.dirname(os.path.abspath(__file__))
iconset = os.path.join(here, "..", "..", "Resources", "AppIcon.iconset")
make(1, os.path.join(iconset, "icon_256x256.png")).save(f"{here}/background.png")
make(2, os.path.join(iconset, "icon_512x512.png")).save(f"{here}/background@2x.png")
subprocess.check_call(["tiffutil", "-cathidpicheck", f"{here}/background.png", f"{here}/background@2x.png", "-out", f"{here}/background.tiff"])
