#!/usr/bin/env python3
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "graphics" / "ui" / "minigames"
FONT_TITLE = str(ROOT / "assets" / "fonts" / "ArialBold.ttf")
FONT_HAND = FONT_TITLE


def ensure_dirs() -> None:
    for sub in ["common", "puzzle", "memory", "sequencing", "drawing", "digits", "menu", "worldmap", "world"]:
        (OUT / sub).mkdir(parents=True, exist_ok=True)


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def make_canvas(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", size, (0, 0, 0, 0))


def rounded_panel(
    size: tuple[int, int],
    fill_top: tuple[int, int, int, int],
    fill_bottom: tuple[int, int, int, int],
    outline: tuple[int, int, int, int],
    radius: int,
    shadow_alpha: int = 100,
) -> Image.Image:
    w, h = size
    img = make_canvas(size)
    shadow = make_canvas(size)
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((14, 18, w - 14, h - 8), radius=radius, fill=(0, 0, 0, shadow_alpha))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(shadow)

    panel = make_canvas(size)
    mask = make_canvas(size)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle((8, 8, w - 8, h - 18), radius=radius, fill=(255, 255, 255, 255))

    for y in range(h):
        t = y / max(1, h - 1)
        col = tuple(int(fill_top[i] * (1 - t) + fill_bottom[i] * t) for i in range(4))
        ImageDraw.Draw(panel).line((0, y, w, y), fill=col)
    panel.putalpha(mask.split()[-1])
    img.alpha_composite(panel)

    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((8, 8, w - 8, h - 18), radius=radius, outline=outline, width=4)
    return img


def _line_size(draw: ImageDraw.ImageDraw, text: str, fnt, stroke_width: int) -> tuple[int, int, tuple[int, int, int, int]]:
    bbox = draw.textbbox((0, 0), text, font=fnt, stroke_width=stroke_width)
    return bbox[2] - bbox[0], bbox[3] - bbox[1], bbox


def _wrap_lines(draw: ImageDraw.ImageDraw, text: str, fnt, max_width: int, stroke_width: int) -> list[str]:
    words = text.split()
    if len(words) <= 1:
        return [text]
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        candidate = current + " " + word
        width, _, _ = _line_size(draw, candidate, fnt, stroke_width)
        if width <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def _fit_text(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], text: str, base_font, stroke_width: int, multiline: bool) -> tuple[ImageFont.FreeTypeFont, list[str], int]:
    max_width = box[2] - box[0]
    max_height = box[3] - box[1]
    font_path = getattr(base_font, "path", FONT_TITLE)
    start_size = int(getattr(base_font, "size", 28))
    for size in range(start_size, 11, -1):
        fnt = font(font_path, size)
        lines = _wrap_lines(draw, text, fnt, max_width, stroke_width) if multiline else [text]
        line_spacing = max(2, int(size * 0.14))
        widths = []
        heights = []
        for line in lines:
            width, height, _ = _line_size(draw, line, fnt, stroke_width)
            widths.append(width)
            heights.append(height)
        total_height = sum(heights) + line_spacing * max(0, len(lines) - 1)
        if widths and max(widths) <= max_width and total_height <= max_height:
            return fnt, lines, line_spacing
    return font(font_path, 12), _wrap_lines(draw, text, font(font_path, 12), max_width, stroke_width) if multiline else [text], 2


def center_text(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    text: str,
    fnt,
    fill,
    stroke_fill,
    stroke_width=3,
    multiline: bool = False,
):
    fitted_font, lines, line_spacing = _fit_text(draw, box, text, fnt, stroke_width, multiline)
    line_metrics = [_line_size(draw, line, fitted_font, stroke_width) for line in lines]
    total_height = sum(metric[1] for metric in line_metrics) + line_spacing * max(0, len(lines) - 1)
    y = box[1] + (box[3] - box[1] - total_height) / 2
    for idx, line in enumerate(lines):
        width, height, bbox = line_metrics[idx]
        x = box[0] + (box[2] - box[0] - width) / 2 - bbox[0]
        draw_y = y - bbox[1]
        draw.text((x, draw_y), line, font=fitted_font, fill=fill, stroke_fill=stroke_fill, stroke_width=stroke_width)
        y += height + line_spacing


def save_title(text: str, out_path: Path, theme: tuple[tuple[int, int, int, int], tuple[int, int, int, int]]):
    img = rounded_panel((980, 140), theme[0], theme[1], (255, 255, 255, 210), 54)
    draw = ImageDraw.Draw(img)
    center_text(draw, (24, 18, 956, 116), text, font(FONT_TITLE, 54), (255, 248, 214, 255), (61, 31, 88, 255), 4)
    img.save(out_path)


def save_menu_logo(out_path: Path):
    size = (980, 250)
    img = rounded_panel(size, (255, 222, 136, 255), (126, 170, 255, 255), (255, 255, 255, 225), 72, 135)

    glow = make_canvas(size)
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse((36, 42, 300, 218), fill=(255, 244, 192, 92))
    gdraw.ellipse((70, 64, 266, 196), fill=(173, 232, 255, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(glow)

    crystal_shadow = make_canvas(size)
    csdraw = ImageDraw.Draw(crystal_shadow)
    crystal = [(168, 34), (234, 96), (212, 202), (124, 202), (102, 96)]
    csdraw.polygon([(x + 6, y + 8) for x, y in crystal], fill=(0, 0, 0, 72))
    crystal_shadow = crystal_shadow.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(crystal_shadow)

    draw = ImageDraw.Draw(img)
    draw.polygon(crystal, fill=(112, 220, 255, 255), outline=(255, 255, 255, 240))
    draw.polygon([(168, 34), (199, 96), (168, 152), (136, 96)], fill=(194, 245, 255, 255), outline=(255, 255, 255, 220))
    draw.polygon([(168, 34), (234, 96), (199, 96)], fill=(166, 238, 255, 255))
    draw.polygon([(136, 96), (199, 96), (124, 202)], fill=(128, 206, 255, 255))
    draw.polygon([(199, 96), (234, 96), (212, 202)], fill=(96, 180, 250, 255))
    draw.line((168, 34, 199, 96), fill=(255, 255, 255, 225), width=4)
    draw.line((168, 34, 136, 96), fill=(255, 255, 255, 225), width=4)
    draw.line((168, 34, 234, 96), fill=(220, 248, 255, 210), width=3)
    draw.line((136, 96, 199, 96), fill=(255, 255, 255, 190), width=3)
    draw.line((199, 96, 124, 202), fill=(214, 246, 255, 160), width=3)
    draw.line((199, 96, 212, 202), fill=(214, 246, 255, 160), width=3)

    for cx, cy, outer, inner, fill in [
        (84, 62, 18, 8, (255, 244, 168, 255)),
        (258, 62, 16, 7, (255, 233, 140, 255)),
        (96, 190, 14, 6, (255, 225, 132, 235)),
    ]:
        draw.polygon(star_points(cx, cy, outer, inner), fill=fill, outline=(255, 255, 255, 210))

    center_text(draw, (294, 30, 942, 126), "Искорка", font(FONT_TITLE, 78), (255, 250, 227, 255), (86, 46, 112, 255), 5)
    center_text(draw, (296, 120, 944, 218), "и Кристалл Дружбы", font(FONT_TITLE, 54), (238, 247, 255, 255), (54, 72, 134, 255), 4)
    img.save(out_path)


def save_banner(text: str, out_path: Path, size=(920, 150), fill=((255, 219, 92, 255), (255, 157, 77, 255))):
    img = rounded_panel(size, fill[0], fill[1], (255, 255, 255, 220), 56, 120)
    draw = ImageDraw.Draw(img)
    center_text(draw, (20, 14, size[0] - 20, size[1] - 26), text, font(FONT_TITLE, 48), (255, 255, 255, 255), (110, 54, 20, 255), 4)
    img.save(out_path)


def save_small_label(text: str, out_path: Path, size=(340, 78), fill=((129, 203, 255, 255), (76, 120, 255, 255))):
    img = rounded_panel(size, fill[0], fill[1], (255, 255, 255, 190), 32, 85)
    draw = ImageDraw.Draw(img)
    center_text(draw, (14, 8, size[0] - 14, size[1] - 18), text, font(FONT_TITLE, 28), (255, 250, 235, 255), (37, 40, 113, 255), 3)
    img.save(out_path)


def save_digit(char: str, out_path: Path):
    img = make_canvas((58, 74))
    shadow = make_canvas((58, 74))
    sdraw = ImageDraw.Draw(shadow)
    fnt = font(FONT_TITLE, 44)
    bbox = sdraw.textbbox((0, 0), char, font=fnt, stroke_width=4)
    x = (58 - (bbox[2] - bbox[0])) / 2 + 1
    y = (74 - (bbox[3] - bbox[1])) / 2 + 6
    sdraw.text((x + 2, y + 3), char, font=fnt, fill=(0, 0, 0, 90), stroke_fill=(0, 0, 0, 90), stroke_width=4)
    shadow = shadow.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(shadow)
    draw = ImageDraw.Draw(img)
    draw.text((x, y), char, font=fnt, fill=(255, 245, 185, 255), stroke_fill=(66, 37, 103, 255), stroke_width=4)
    img.save(out_path)


def star_points(cx, cy, r_outer, r_inner, points=5):
    out = []
    for i in range(points * 2):
        ang = -math.pi / 2 + i * math.pi / points
        r = r_outer if i % 2 == 0 else r_inner
        out.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    return out


def diamond_points(cx, cy, rx, ry):
    return [(cx, cy - ry), (cx + rx, cy), (cx, cy + ry), (cx - rx, cy)]


def save_back_button(out_path: Path):
    img = make_canvas((120, 120))
    draw = ImageDraw.Draw(img)
    draw.ellipse((18, 18, 102, 102), fill=(20, 24, 48, 115), outline=(255, 255, 255, 180), width=4)
    pts = [(76, 30), (40, 60), (76, 90), (84, 78), (62, 60), (84, 42)]
    draw.polygon(pts, fill=(255, 255, 255, 255), outline=(52, 42, 94, 230))
    img.save(out_path)


def save_action_button(text: str, out_path: Path, color_top, color_bottom, icon: str):
    img = rounded_panel((260, 96), color_top, color_bottom, (255, 255, 255, 210), 28, 100)
    draw = ImageDraw.Draw(img)
    if icon == "check":
        draw.line((42, 50, 62, 68), fill=(255, 255, 255, 255), width=8)
        draw.line((62, 68, 90, 34), fill=(255, 255, 255, 255), width=8)
    elif icon == "clear":
        draw.line((42, 34, 86, 78), fill=(255, 255, 255, 255), width=8)
        draw.line((86, 34, 42, 78), fill=(255, 255, 255, 255), width=8)
    center_text(draw, (88, 8, 244, 76), text, font(FONT_TITLE, 28), (255, 255, 255, 255), (62, 42, 77, 255), 3)
    img.save(out_path)


def save_puzzle_item(idx: int, out_path: Path, color):
    img = rounded_panel((120, 120), tuple(min(255, c + 40) for c in color) + (255,), color + (255,), (255, 255, 255, 200), 28, 80)
    draw = ImageDraw.Draw(img)
    if idx == 0:  # apple
        draw.ellipse((28, 30, 92, 96), fill=(255, 91, 91, 255), outline=(180, 24, 24, 255), width=3)
        draw.polygon([(60, 22), (66, 38), (54, 38)], fill=(118, 72, 34, 255))
        draw.ellipse((64, 22, 84, 40), fill=(100, 200, 96, 255), outline=(54, 128, 52, 255), width=2)
    elif idx == 1:  # fish
        draw.ellipse((24, 38, 88, 84), fill=(108, 210, 255, 255), outline=(24, 96, 160, 255), width=3)
        draw.polygon([(88, 61), (104, 44), (104, 78)], fill=(89, 191, 250, 255), outline=(24, 96, 160, 255))
        draw.ellipse((40, 54, 48, 62), fill=(255, 255, 255, 255))
        draw.ellipse((43, 56, 47, 60), fill=(26, 38, 63, 255))
    elif idx == 2:  # leaf
        draw.polygon([(62, 22), (94, 58), (62, 96), (30, 58)], fill=(95, 210, 104, 255), outline=(43, 132, 56, 255))
        draw.line((62, 24, 62, 92), fill=(43, 132, 56, 255), width=3)
        draw.line((62, 52, 84, 38), fill=(43, 132, 56, 255), width=2)
        draw.line((62, 66, 42, 80), fill=(43, 132, 56, 255), width=2)
    else:  # star
        draw.polygon(star_points(60, 60, 36, 16), fill=(255, 225, 102, 255), outline=(210, 140, 32, 255))
        draw.ellipse((52, 50, 56, 54), fill=(180, 120, 40, 255))
        draw.ellipse((64, 50, 68, 54), fill=(180, 120, 40, 255))
    img.save(out_path)


def save_puzzle_bin(idx: int, out_path: Path, label: str, color):
    img = rounded_panel((240, 360), (34, 35, 62, 235), (21, 22, 46, 245), color + (255,), 34, 120)
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((34, 80, 206, 292), radius=24, fill=(94, 65, 41, 240), outline=(220, 170, 120, 255), width=4)
    draw.arc((44, 42, 196, 160), start=190, end=350, fill=(236, 201, 148, 255), width=8)
    draw.line((46, 178, 194, 178), fill=(235, 202, 162, 255), width=4)
    center_text(draw, (24, 288, 216, 346), label, font(FONT_TITLE, 28), tuple(min(255, c + 70) for c in color) + (255,), (17, 20, 42, 255), 3)
    if idx == 0:
        draw.ellipse((96, 138, 144, 188), fill=(255, 99, 99, 255))
    elif idx == 1:
        draw.ellipse((88, 144, 146, 184), fill=(96, 208, 255, 255))
        draw.polygon([(146, 164), (168, 146), (168, 182)], fill=(96, 208, 255, 255))
    elif idx == 2:
        draw.polygon([(120, 122), (152, 164), (120, 208), (88, 164)], fill=(113, 219, 120, 255))
    else:
        draw.polygon(star_points(120, 164, 28, 12), fill=(255, 227, 120, 255))
    img.save(out_path)


def save_memory_front(idx: int, out_path: Path, color):
    img = rounded_panel((210, 250), tuple(min(255, c + 40) for c in color) + (255,), color + (255,), (255, 255, 255, 210), 30, 110)
    draw = ImageDraw.Draw(img)
    cx, cy = 105, 126
    if idx == 0:
        draw.polygon(star_points(cx, cy, 44, 20), fill=(255, 238, 150, 255), outline=(200, 134, 34, 255))
    elif idx == 1:
        draw.polygon([(cx, cy + 36), (cx + 44, cy - 8), (cx, cy - 48), (cx - 44, cy - 8)], fill=(118, 240, 255, 255), outline=(37, 119, 175, 255))
        draw.polygon([(cx - 24, cy - 8), (cx + 24, cy - 8), (cx + 14, cy + 44), (cx - 14, cy + 44)], fill=(184, 255, 255, 180))
    elif idx == 2:
        draw.pieslice((56, 74, 154, 172), 40, 320, fill=(255, 244, 171, 255), outline=(170, 126, 49, 255), width=4)
        draw.ellipse((86, 76, 146, 136), fill=(255, 255, 255, 0))
    elif idx == 3:
        draw.ellipse((58, 106, 104, 152), fill=(255, 150, 176, 255), outline=(181, 64, 95, 255))
        draw.ellipse((106, 106, 152, 152), fill=(255, 150, 176, 255), outline=(181, 64, 95, 255))
        draw.polygon([(76, 132), (134, 132), (105, 182)], fill=(255, 150, 176, 255), outline=(181, 64, 95, 255))
    elif idx == 4:
        for ang in range(0, 360, 45):
            x = cx + math.cos(math.radians(ang)) * 42
            y = cy + math.sin(math.radians(ang)) * 42
            draw.ellipse((x - 18, y - 18, x + 18, y + 18), fill=(255, 227, 148, 255), outline=(191, 121, 42, 255))
        draw.ellipse((82, 103, 128, 149), fill=(255, 132, 94, 255), outline=(171, 78, 49, 255))
    elif idx == 5:
        draw.polygon([(cx, 68), (150, 120), (cx, 184), (60, 120)], fill=(107, 220, 125, 255), outline=(47, 132, 68, 255))
        draw.line((cx, 74, cx, 178), fill=(47, 132, 68, 255), width=4)
    elif idx == 6:
        draw.ellipse((50, 110, 136, 168), fill=(105, 210, 255, 255), outline=(30, 98, 170, 255), width=4)
        draw.polygon([(136, 138), (170, 110), (170, 166)], fill=(105, 210, 255, 255), outline=(30, 98, 170, 255))
        draw.ellipse((72, 130, 82, 140), fill=(255, 255, 255, 255))
    else:
        for i in range(4):
            draw.arc((54 + i * 10, 70 + i * 12, 160 - i * 10, 180 - i * 4), start=200, end=335, fill=(255, 240, 190 - i * 20, 255), width=5)
    img.save(out_path)


def save_seq_button(idx: int, out_path: Path, color, active=False):
    base_top = tuple(min(255, c + (55 if active else 15)) for c in color) + (255,)
    base_bottom = tuple(max(0, c - (0 if active else 25)) for c in color) + (255,)
    img = rounded_panel((180, 180), base_top, base_bottom, (255, 255, 255, 220), 90, 130 if active else 95)
    draw = ImageDraw.Draw(img)
    draw.polygon(diamond_points(90, 90, 44, 56), fill=(255, 255, 255, 110 if active else 80), outline=(255, 255, 255, 180), width=3)
    draw.polygon(diamond_points(90, 90, 26, 34), fill=(255, 255, 255, 140 if active else 90))
    img.save(out_path)


def save_palette_swatch(out_path: Path, color):
    img = rounded_panel((92, 92), tuple(min(255, c + 30) for c in color) + (255,), color + (255,), (255, 255, 255, 210), 46, 85)
    draw = ImageDraw.Draw(img)
    draw.ellipse((24, 20, 68, 64), fill=(255, 255, 255, 70))
    draw.polygon([(46, 18), (66, 52), (46, 74), (26, 52)], fill=color + (255,), outline=(255, 255, 255, 140))
    img.save(out_path)


def save_selected_ring(out_path: Path):
    img = make_canvas((108, 108))
    draw = ImageDraw.Draw(img)
    draw.ellipse((8, 8, 100, 100), outline=(255, 255, 255, 235), width=8)
    draw.ellipse((18, 18, 90, 90), outline=(126, 224, 255, 190), width=4)
    img = img.filter(ImageFilter.GaussianBlur(0.2))
    img.save(out_path)


def save_icon_badge(out_path: Path, glyph: str, fill=((150, 210, 255, 255), (91, 134, 242, 255)), size=(110, 110), font_size=54):
    img = rounded_panel(size, fill[0], fill[1], (255, 255, 255, 220), 30, 100)
    draw = ImageDraw.Draw(img)
    center_text(draw, (0, 0, size[0], size[1] - 10), glyph, font(FONT_TITLE, font_size), (255, 255, 255, 255), (49, 44, 112, 255), 4)
    img.save(out_path)


def save_capsule(out_path: Path, text: str, size=(240, 96), fill=((145, 214, 255, 255), (91, 134, 242, 255)), font_size=28):
    img = rounded_panel(size, fill[0], fill[1], (255, 255, 255, 220), 28, 100)
    draw = ImageDraw.Draw(img)
    center_text(draw, (18, 8, size[0] - 18, size[1] - 18), text, font(FONT_TITLE, font_size), (255, 251, 232, 255), (50, 47, 116, 255), 3, multiline=True)
    img.save(out_path)


def save_world_badge(out_path: Path, text: str, fill=((141, 224, 169, 255), (73, 185, 132, 255)), size=(170, 70), font_size=26):
    img = rounded_panel(size, fill[0], fill[1], (255, 255, 255, 220), 26, 90)
    draw = ImageDraw.Draw(img)
    center_text(draw, (12, 4, size[0] - 12, size[1] - 14), text, font(FONT_TITLE, font_size), (255, 251, 235, 255), (36, 72, 78, 255), 3)
    img.save(out_path)


def save_mg_button(out_path: Path, title: str, glyph: str, fill=((255, 214, 132, 255), (245, 140, 88, 255)), size=(220, 170)):
    img = rounded_panel(size, fill[0], fill[1], (255, 255, 255, 220), 28, 110)
    draw = ImageDraw.Draw(img)
    center_text(draw, (0, 18, size[0], 94), glyph, font(FONT_TITLE, 44), (255, 255, 255, 255), (105, 60, 34, 255), 4)
    center_text(draw, (10, 98, size[0] - 10, 154), title, font(FONT_TITLE, 24), (255, 251, 232, 255), (105, 60, 34, 255), 3)
    img.save(out_path)


def main() -> None:
    ensure_dirs()

    save_back_button(OUT / "common" / "back_button.png")
    save_action_button("Очистить", OUT / "common" / "clear_button.png", (255, 133, 153, 255), (227, 82, 108, 255), "clear")
    save_action_button("Готово", OUT / "common" / "done_button.png", (113, 230, 164, 255), (55, 182, 116, 255), "check")

    save_title("Рассортируй по цветам!", OUT / "common" / "title_puzzle.png", ((157, 120, 255, 255), (86, 84, 220, 255)))
    save_title("Найди пару!", OUT / "common" / "title_memory.png", ((109, 199, 255, 255), (74, 117, 245, 255)))
    save_title("Повтори последовательность!", OUT / "common" / "title_sequencing.png", ((255, 171, 127, 255), (222, 97, 140, 255)))
    save_title("Рисуй и раскрашивай!", OUT / "common" / "title_drawing.png", ((113, 230, 164, 255), (56, 179, 205, 255)))

    save_banner("Ура! Всё рассортировано!", OUT / "common" / "complete_puzzle.png")
    save_banner("Отлично! Все пары найдены!", OUT / "common" / "complete_memory.png")
    save_banner("Ты супер! Все уровни пройдены!", OUT / "common" / "complete_sequencing.png")
    save_banner("Красивый рисунок!", OUT / "common" / "complete_drawing.png")

    save_banner("Смотри внимательно...", OUT / "common" / "status_watch.png", size=(700, 110), fill=((135, 198, 255, 255), (100, 125, 255, 255)))
    save_banner("Теперь повтори!", OUT / "common" / "status_repeat.png", size=(560, 110), fill=((148, 233, 173, 255), (69, 196, 138, 255)))
    save_banner("Правильно!", OUT / "common" / "status_success.png", size=(460, 110), fill=((164, 245, 165, 255), (74, 201, 113, 255)))
    save_banner("Ошибка! Попробуй ещё раз!", OUT / "common" / "status_fail.png", size=(720, 110), fill=((255, 173, 168, 255), (237, 90, 109, 255)))

    save_small_label("Попыток", OUT / "common" / "attempts_label.png")
    save_small_label("Уровень", OUT / "common" / "level_label.png")
    save_small_label("из", OUT / "common" / "of_label.png", size=(120, 78), fill=((251, 206, 140, 255), (255, 148, 84, 255)))

    for ch in "0123456789":
        save_digit(ch, OUT / "digits" / f"{ch}.png")
    save_digit("/", OUT / "digits" / "slash.png")

    puzzle_colors = [(225, 91, 91), (89, 186, 245), (86, 200, 103), (240, 198, 70)]
    puzzle_labels = ["Красный", "Синий", "Зелёный", "Жёлтый"]
    for idx, col in enumerate(puzzle_colors):
        save_puzzle_item(idx, OUT / "puzzle" / f"item_{idx}.png", col)
        save_puzzle_bin(idx, OUT / "puzzle" / f"bin_{idx}.png", puzzle_labels[idx], col)

    memory_colors = [
        (255, 163, 94), (99, 215, 255), (177, 153, 255), (255, 141, 180),
        (255, 194, 94), (112, 216, 116), (86, 172, 255), (255, 173, 116),
    ]
    for idx, col in enumerate(memory_colors):
        save_memory_front(idx, OUT / "memory" / f"front_{idx}.png", col)

    seq_colors = [(230, 92, 92), (84, 162, 242), (88, 211, 112), (244, 206, 83), (171, 114, 225)]
    for idx, col in enumerate(seq_colors):
        save_seq_button(idx, OUT / "sequencing" / f"button_{idx}.png", col, False)
        save_seq_button(idx, OUT / "sequencing" / f"button_{idx}_active.png", col, True)

    draw_colors = [(231, 76, 60), (230, 126, 34), (241, 196, 15), (46, 204, 113), (52, 152, 219), (155, 89, 182), (255, 107, 129), (52, 73, 94)]
    for idx, col in enumerate(draw_colors):
        save_palette_swatch(OUT / "drawing" / f"swatch_{idx}.png", col)
    save_selected_ring(OUT / "drawing" / "selected_ring.png")

    save_menu_logo(OUT / "menu" / "main_title.png")
    save_capsule(
        OUT / "menu" / "main_description.png",
        "Помоги Искорке собрать осколки дружбы: играй, запоминай, сортируй и рисуй!",
        size=(840, 132),
        fill=((186, 235, 255, 255), (108, 151, 255, 255)),
        font_size=26,
    )
    save_capsule(OUT / "menu" / "play_label.png", "Играть", size=(360, 108), fill=((145, 241, 154, 255), (68, 188, 99, 255)), font_size=34)
    save_icon_badge(OUT / "menu" / "settings_icon.png", "⚙", fill=((175, 192, 255, 255), (103, 112, 216, 255)))
    save_icon_badge(OUT / "menu" / "parent_icon.png", "🔒", fill=((255, 203, 153, 255), (222, 134, 91, 255)))
    save_icon_badge(OUT / "menu" / "album_icon.png", "📔", fill=((255, 218, 153, 255), (236, 159, 74, 255)))

    save_capsule(OUT / "worldmap" / "map_title.png", "Карта миров", size=(620, 112), fill=((255, 223, 134, 255), (255, 156, 94, 255)), font_size=34)
    save_capsule(OUT / "worldmap" / "hint_default.png", "Нажми на зелёный остров", size=(760, 104), fill=((153, 228, 180, 255), (74, 192, 126, 255)), font_size=28)
    save_capsule(OUT / "worldmap" / "hint_opening.png", "Открываем мир...", size=(520, 104), fill=((154, 214, 255, 255), (90, 130, 255, 255)), font_size=30)
    save_capsule(OUT / "worldmap" / "hint_locked.png", "Сначала пройди предыдущий мир!", size=(780, 104), fill=((255, 186, 169, 255), (235, 102, 111, 255)), font_size=28)
    save_capsule(OUT / "worldmap" / "back_menu.png", "Назад", size=(180, 80), fill=((156, 224, 255, 255), (97, 149, 255, 255)), font_size=26)
    save_capsule(OUT / "worldmap" / "album_button.png", "Альбом", size=(180, 80), fill=((255, 224, 153, 255), (236, 159, 74, 255)), font_size=26)
    save_capsule(OUT / "worldmap" / "crystal_label.png", "Кристалл", size=(240, 80), fill=((181, 227, 255, 255), (98, 165, 255, 255)), font_size=28)
    save_capsule(OUT / "worldmap" / "shards_label.png", "Осколки", size=(220, 74), fill=((181, 227, 255, 255), (98, 165, 255, 255)), font_size=24)

    world_names = ["Лес", "Лед", "Облака", "Море", "Пустыня", "Роща", "Сны"]
    for idx, name in enumerate(world_names):
        save_world_badge(OUT / "worldmap" / f"world_name_{idx}.png", name)
    save_world_badge(OUT / "worldmap" / "badge_open.png", "Открыт", fill=((153, 228, 180, 255), (74, 192, 126, 255)), size=(120, 52), font_size=20)
    save_world_badge(OUT / "worldmap" / "badge_done.png", "Пройден", fill=((255, 223, 134, 255), (255, 156, 94, 255)), size=(140, 52), font_size=20)
    save_world_badge(OUT / "worldmap" / "badge_lock.png", "Закрыт", fill=((198, 202, 214, 255), (110, 120, 151, 255)), size=(130, 52), font_size=20)

    save_icon_badge(OUT / "world" / "back_button.png", "←", fill=((156, 224, 255, 255), (97, 149, 255, 255)), size=(80, 80), font_size=38)
    save_icon_badge(OUT / "world" / "pause_button.png", "⏸", fill=((175, 192, 255, 255), (103, 112, 216, 255)), size=(100, 100), font_size=44)
    save_icon_badge(OUT / "world" / "shard_icon.png", "✦", fill=((255, 223, 134, 255), (255, 156, 94, 255)), size=(68, 68), font_size=34)
    save_capsule(OUT / "world" / "hint_tap.png", "Нажми сюда!", size=(340, 96), fill=((255, 223, 134, 255), (255, 156, 94, 255)), font_size=28)
    save_capsule(OUT / "world" / "toast_done.png", "Уже пройдено!", size=(420, 96), fill=((255, 223, 134, 255), (255, 156, 94, 255)), font_size=30)
    save_capsule(OUT / "world" / "plus_one.png", "+1", size=(160, 96), fill=((255, 223, 134, 255), (255, 156, 94, 255)), font_size=40)
    mg_defs = [
        ("mg_puzzle.png", "Сортировка", "🍎"),
        ("mg_memory.png", "Пары", "💎"),
        ("mg_sequence.png", "Ритм", "✦"),
        ("mg_drawing.png", "Рисование", "🎨"),
    ]
    for filename, title, glyph in mg_defs:
        save_mg_button(OUT / "world" / filename, title, glyph)
    save_world_badge(OUT / "world" / "done_badge.png", "★", fill=((255, 223, 134, 255), (255, 156, 94, 255)), size=(40, 40), font_size=20)

    print(f"Generated UI assets in {OUT}")


if __name__ == "__main__":
    main()
