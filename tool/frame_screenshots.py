#!/usr/bin/env python3
"""Store marketing screenshots: mounts a raw app screenshot in a clean, real-
looking device frame over a nice background, with a big headline + subtitle.

Frames (iPhone / Android / iPad / MacBook / desktop) and layout are DRAWN by
code with Pillow — no paid mockups/APIs. Fonts: system Helvetica Neue (full
Unicode → accents work).

Manifest mode (recommended, this is what `vgv screenshots` runs):
  python3 frame_screenshots.py manifest <manifest.json>

Each manifest entry:
  {"device":"iphone","type":"poster","src":"raw/01.png","out":"store/01.png",
   "headline":"Catch **stick drift** in real time",
   "subtitle":"Live per-stick offset and max deflection.",
   "accent":"#39D6E0","bg":"#0E0F11"}

- type: poster (frame + text) | hero (app icon + tagline) | frame (frame only)
- device: iphone | android | ipad | macbook | desktop
- Wrap words in **double asterisks** to paint them with the accent color.
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

_HN = "/System/Library/Fonts/HelveticaNeue.ttc"          # 0=Regular, 1=Bold
_ARIAL = "/System/Library/Fonts/Supplemental/Arial.ttf"
_ARIAL_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

WHITE = (0xF4, 0xF6, 0xF8)
MUTED = (0x9A, 0xA2, 0xAC)
ACCENT = (0x39, 0xD6, 0xE0)

# Store canvas (WxH) + screen aspect (w/h) per device.
DEVICES = {
    "iphone":  {"canvas": (1290, 2796), "aspect": 1179 / 2556, "notch": "island"},
    "android": {"canvas": (1080, 1920), "aspect": 1080 / 2340, "notch": "punch"},
    "ipad":    {"canvas": (2048, 2732), "aspect": 1640 / 2360, "notch": None},
    "macbook": {"canvas": (2560, 1600), "aspect": 16 / 10,     "notch": "laptop"},
    "desktop": {"canvas": (2560, 1600), "aspect": 16 / 10,     "notch": "window"},
}


def _hex(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def _font(bold, size):
    try:
        return ImageFont.truetype(_HN, size, index=1 if bold else 0)
    except Exception:
        return ImageFont.truetype(_ARIAL_BOLD if bold else _ARIAL, size)


def _vgrad(size, top, bottom):
    w, h = size
    strip = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        strip.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return strip.resize((w, h))


def _bg_stops(accent, bg):
    if bg:
        return tuple(min(255, c + 10) for c in bg), tuple(max(0, c - 6) for c in bg)
    base = (12, 13, 16)
    top = tuple(round(base[i] + (accent[i] - base[i]) * 0.17) for i in range(3))
    return top, (7, 8, 10)


def _background(cw, ch, accent, bg, glow_y):
    top, bottom = _bg_stops(accent, bg)
    canvas = _vgrad((cw, ch), top, bottom).convert("RGBA")
    glow = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    rx, ry = int(cw * 0.66), int(ch * 0.22)
    gd.ellipse([cw // 2 - rx, glow_y - ry, cw // 2 + rx, glow_y + ry], fill=accent + (78,))
    gd.ellipse([cw // 2 - int(cw * 0.4), -int(ch * 0.1), cw // 2 + int(cw * 0.4), int(ch * 0.12)],
               fill=accent + (36,))
    return Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(int(cw * 0.09))))


def _mount(shot_path, disp_w, disp_h, corner):
    """Cover-fit the screenshot to disp_w x disp_h with rounded corners."""
    shot = Image.open(shot_path).convert("RGBA")
    target = disp_w / disp_h
    sw, sh = shot.size
    if abs(sw / sh - target) > 0.01:
        if sw / sh > target:
            nw = int(sh * target); shot = shot.crop(((sw - nw) // 2, 0, (sw - nw) // 2 + nw, sh))
        else:
            nh = int(sw / target); shot = shot.crop((0, (sh - nh) // 2, sw, (sh - nh) // 2 + nh))
    shot = shot.resize((disp_w, disp_h), Image.LANCZOS)
    mask = Image.new("L", (disp_w, disp_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, disp_w - 1, disp_h - 1], radius=corner, fill=255)
    out = Image.new("RGBA", (disp_w, disp_h), (0, 0, 0, 0))
    out.paste(shot, (0, 0), mask)
    return out


def _phone(shot_path, screen_w, notch):
    """Clean modern phone: thin uniform bezel, big corner radius, subtle edge
    highlight for depth, Dynamic Island or hole-punch."""
    aspect = 1179 / 2556 if notch == "island" else 1080 / 2340
    bezel = max(8, round(screen_w * 0.030))
    disp_w = screen_w - bezel * 2
    disp_h = round(disp_w / aspect)
    screen_h = disp_h + bezel * 2
    radius = round(screen_w * 0.16)
    frame = Image.new("RGBA", (screen_w, screen_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    # subtle outer edge (metal rim) then the black body
    d.rounded_rectangle([0, 0, screen_w - 1, screen_h - 1], radius=radius, fill=(0x2A, 0x2C, 0x30, 255))
    d.rounded_rectangle([1, 1, screen_w - 2, screen_h - 2], radius=radius - 1, fill=(0x0A, 0x0B, 0x0D, 255))
    frame.alpha_composite(_mount(shot_path, disp_w, disp_h, max(6, radius - bezel)), (bezel, bezel))
    if notch == "island":
        pw, ph = round(disp_w * 0.30), max(16, round(bezel * 1.5))
        d.rounded_rectangle([screen_w // 2 - pw // 2, bezel + round(disp_h * 0.012),
                             screen_w // 2 + pw // 2, bezel + round(disp_h * 0.012) + ph],
                            radius=ph // 2, fill=(0, 0, 0, 255))
    elif notch == "punch":
        r = max(9, round(disp_w * 0.018))
        cx, cy = screen_w // 2, bezel + round(disp_h * 0.02) + r
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, 255))
    return frame


def _laptop(shot_path, screen_w):
    bezel = max(10, screen_w // 105)
    disp_w = screen_w - bezel * 2
    disp_h = round(disp_w * 10 / 16)
    screen_h = disp_h + bezel * 2
    base_w, base_h = screen_w + round(screen_w * 0.09), max(16, screen_w // 56)
    hinge = max(3, base_h // 6)
    frame = Image.new("RGBA", (base_w, screen_h + hinge + base_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    sx = (base_w - screen_w) // 2
    d.rounded_rectangle([sx, 0, sx + screen_w, screen_h], radius=max(14, bezel + 8), fill=(0x0B, 0x0C, 0x0E, 255))
    frame.alpha_composite(_mount(shot_path, disp_w, disp_h, max(6, bezel // 2)), (sx + bezel, bezel))
    nb = disp_w // 13
    d.rounded_rectangle([base_w // 2 - nb, bezel - 1, base_w // 2 + nb, bezel + max(10, bezel)],
                        radius=8, fill=(0x0B, 0x0C, 0x0E, 255))
    base_y = screen_h + hinge
    deck = _vgrad((base_w, base_h), (0xC8, 0xCC, 0xD2), (0x86, 0x8B, 0x93)).convert("RGBA")
    dm = Image.new("L", (base_w, base_h), 0)
    ImageDraw.Draw(dm).rounded_rectangle([0, 0, base_w - 1, base_h - 1], radius=base_h // 3, fill=255)
    frame.paste(deck, (0, base_y), dm)
    nw = base_w // 12
    d.rounded_rectangle([base_w // 2 - nw, base_y - 1, base_w // 2 + nw, base_y + base_h // 2],
                        radius=base_h // 3, fill=(0x2A, 0x2D, 0x31, 255))
    return frame


def _window(shot_path, win_w):
    """Desktop app window: title bar + traffic lights."""
    aspect = 16 / 10
    bar = max(28, round(win_w * 0.045))
    disp_w = win_w
    disp_h = round(disp_w / aspect)
    radius = max(12, round(win_w * 0.018))
    frame = Image.new("RGBA", (win_w, disp_h + bar), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, win_w - 1, disp_h + bar - 1], radius=radius, fill=(0x1B, 0x1D, 0x22, 255))
    for i, col in enumerate([(0xFF, 0x5F, 0x57), (0xFE, 0xBC, 0x2E), (0x28, 0xC8, 0x40)]):
        cx = round(bar * 0.7) + i * round(bar * 0.6)
        r = max(5, bar // 6)
        d.ellipse([cx - r, bar // 2 - r, cx + r, bar // 2 + r], fill=col + (255,))
    frame.alpha_composite(_mount(shot_path, disp_w - 2, disp_h, 0), (1, bar))
    return frame


def build_device(device, shot_path, canvas_w):
    spec = DEVICES[device]
    n = spec["notch"]
    if n == "laptop":
        return _laptop(shot_path, round(canvas_w * 0.66))
    if n == "window":
        return _window(shot_path, round(canvas_w * 0.72))
    return _phone(shot_path, round(canvas_w * 0.62), n)


def _draw_headline(canvas, text, top_y, accent, max_w, size):
    font = _font(True, size)
    draw = ImageDraw.Draw(canvas)
    tokens, acc = [], False
    for chunk in text.split("**"):
        for w in chunk.split(" "):
            if w:
                tokens.append((w, acc))
        acc = not acc
    space_w = draw.textlength(" ", font=font)
    lines, cur, cur_w = [], [], 0
    for w, is_acc in tokens:
        ww = draw.textlength(w, font=font)
        if cur and cur_w + space_w + ww > max_w:
            lines.append(cur); cur, cur_w = [], 0
        cur.append((w, is_acc, ww)); cur_w += (space_w if len(cur) > 1 else 0) + ww
    if cur:
        lines.append(cur)
    line_h = int(size * 1.16)
    y = top_y
    cw = canvas.width
    for line in lines:
        total = sum(ww for _, _, ww in line) + space_w * (len(line) - 1)
        x = (cw - total) // 2
        for w, is_acc, ww in line:
            draw.text((x, y), w, font=font, fill=(accent if is_acc else WHITE) + (255,))
            x += ww + space_w
        y += line_h
    return y


def _draw_subtitle(canvas, text, top_y, size, max_w):
    font = _font(False, size)
    d = ImageDraw.Draw(canvas)
    words, lines, cur = text.split(" "), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font) > max_w and cur:
            lines.append(cur); cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    y = top_y
    for ln in lines:
        tw = d.textlength(ln, font=font)
        d.text(((canvas.width - tw) // 2, y), ln, font=font, fill=MUTED + (255,))
        y += int(size * 1.3)
    return y


def _shadow(canvas, x, y, w, h, radius, blur, alpha=150):
    sh = Image.new("RGBA", (canvas.width, canvas.height), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x + 30, y + 60, x + w - 30, y + h + 20],
                                         radius=radius, fill=(0, 0, 0, alpha))
    return Image.alpha_composite(canvas, sh.filter(ImageFilter.GaussianBlur(blur)))


def make_poster(device, src, out, headline, subtitle="", accent=ACCENT, bg=None):
    cw, ch = DEVICES[device]["canvas"]
    dev = build_device(device, src, cw)
    dx = (cw - dev.width) // 2
    dy = ch - dev.height + round(ch * 0.02)
    canvas = _background(cw, ch, accent, bg, glow_y=dy + dev.height // 3)
    end_y = _draw_headline(canvas, headline, round(ch * 0.055), accent,
                           max_w=int(cw * 0.86), size=int(cw * 0.075))
    if subtitle:
        _draw_subtitle(canvas, subtitle, end_y + round(ch * 0.012), int(cw * 0.038), int(cw * 0.8))
    canvas = _shadow(canvas, dx, dy, dev.width, dev.height, 60, int(cw * 0.03))
    canvas.alpha_composite(dev, (dx, dy))
    canvas.convert("RGB").save(out)


def make_hero(device, icon_src, out, headline, subtitle="", accent=ACCENT, bg=None):
    cw, ch = DEVICES[device]["canvas"]
    canvas = _background(cw, ch, accent, bg, glow_y=round(ch * 0.32))
    icon = Image.open(icon_src).convert("RGBA")
    size = round(cw * 0.36)
    icon = icon.resize((size, size), Image.LANCZOS)
    ix, iy = (cw - size) // 2, round(ch * 0.16)
    halo = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([ix - 80, iy - 40, ix + size + 80, iy + size + 80], fill=accent + (70,))
    canvas = Image.alpha_composite(canvas, halo.filter(ImageFilter.GaussianBlur(90)))
    canvas = _shadow(canvas, ix, iy, size, size, round(size * 0.22), 55, 130)
    # round the icon a touch
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=round(size * 0.22), fill=255)
    canvas.paste(icon, (ix, iy), m)
    end_y = _draw_headline(canvas, headline, iy + size + round(ch * 0.04), accent,
                           max_w=int(cw * 0.82), size=int(cw * 0.085))
    if subtitle:
        _draw_subtitle(canvas, subtitle, end_y + round(ch * 0.012), int(cw * 0.042), int(cw * 0.8))
    canvas.convert("RGB").save(out)


def make_frame(device, src, out, accent=ACCENT, bg=None):
    cw, ch = DEVICES[device]["canvas"]
    dev = build_device(device, src, cw if DEVICES[device]["notch"] in ("laptop", "window") else int(cw * 1.35))
    dx, dy = (cw - dev.width) // 2, (ch - dev.height) // 2
    canvas = _background(cw, ch, accent, bg, glow_y=ch // 2)
    canvas = _shadow(canvas, dx, dy, dev.width, dev.height, 60, int(cw * 0.03))
    canvas.alpha_composite(dev, (dx, dy))
    canvas.convert("RGB").save(out)


def make_feature_graphic(out, headline, subtitle="", icon_src=None, accent=ACCENT, bg=None):
    # Google Play feature graphic is a fixed 1024x500 landscape banner.
    cw, ch = 1024, 500
    canvas = _background(cw, ch, accent, bg, glow_y=round(ch * 0.5))
    title_top = round(ch * 0.30)
    if icon_src:
        size = round(ch * 0.30)
        icon = Image.open(icon_src).convert("RGBA").resize((size, size), Image.LANCZOS)
        ix, iy = (cw - size) // 2, round(ch * 0.10)
        halo = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([ix - 60, iy - 30, ix + size + 60, iy + size + 60], fill=accent + (70,))
        canvas = Image.alpha_composite(canvas, halo.filter(ImageFilter.GaussianBlur(70)))
        canvas = _shadow(canvas, ix, iy, size, size, round(size * 0.22), 45, 130)
        m = Image.new("L", (size, size), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=round(size * 0.22), fill=255)
        canvas.paste(icon, (ix, iy), m)
        title_top = iy + size + round(ch * 0.06)
    end_y = _draw_headline(canvas, headline, title_top, accent,
                           max_w=int(cw * 0.86), size=int(ch * 0.11))
    if subtitle:
        _draw_subtitle(canvas, subtitle, end_y + round(ch * 0.02), int(ch * 0.052), int(cw * 0.8))
    canvas.convert("RGB").save(out)


def main(argv):
    if not argv or argv[0] != "manifest":
        sys.exit(__doc__)
    entries = json.load(open(argv[1]))
    base = os.path.dirname(os.path.abspath(argv[1]))
    for e in entries:
        device = (e.get("device") or "iphone").lower()
        src = e.get("src")
        src = src if not src or os.path.isabs(src) else os.path.join(base, src)
        out = e["out"] if os.path.isabs(e["out"]) else os.path.join(base, e["out"])
        os.makedirs(os.path.dirname(out), exist_ok=True)
        accent = _hex(e["accent"]) if e.get("accent") else ACCENT
        bg = _hex(e["bg"]) if e.get("bg") else None
        t = (e.get("type") or "poster").lower()
        if t == "hero":
            make_hero(device, src, out, e["headline"], e.get("subtitle", ""), accent, bg)
        elif t == "frame":
            make_frame(device, src, out, accent, bg)
        elif t in ("feature_graphic", "feature"):
            make_feature_graphic(out, e["headline"], e.get("subtitle", ""), src, accent, bg)
        else:
            make_poster(device, src, out, e["headline"], e.get("subtitle", ""), accent, bg)
        print(f"{t}/{device} -> {out}")


if __name__ == "__main__":
    main(sys.argv[1:])
