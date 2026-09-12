#!/usr/bin/env python3
"""
generate_yandex_media.py
Generates promotional graphics and gameplay videos for Yandex Games submissions.

Requirements:
- Python 3.8+
- Pillow (PIL)
- ffmpeg in PATH

Outputs generated in yandex/:
- icon_512.png (512x512)
- cover_800x470.png (800x470)
- screenshots/desktop_1..4.png (1280x720)
- screenshots/mobile_1..2.png (720x1280)
- video/gameplay_horizontal.mp4 (1280x720, H.264)
- video/gameplay_vertical.mp4 (720x1280, H.264)
"""

import os
import sys
import math
import random
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = "yandex"
SCREENSHOTS_DIR = os.path.join(OUTPUT_DIR, "screenshots")
VIDEO_DIR = os.path.join(OUTPUT_DIR, "video")

# Ensure target directories exist
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)
os.makedirs(VIDEO_DIR, exist_ok=True)

def find_font(size):
    candidates = [
        "public/fonts/PressStart2P-Regular.ttf",
        "public/assets/fonts/PressStart2P-Regular.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    ]
    for c in candidates:
        if os.path.exists(c):
            try:
                return ImageFont.truetype(c, size)
            except Exception:
                pass
    return ImageFont.load_default()

def draw_beveled_border(draw, x, y, w, h, light="#fcee4b", dark="#553311", thickness=6):
    draw.rectangle([x, y, x + w, y + thickness - 1], fill=light)
    draw.rectangle([x, y, x + thickness - 1, y + h], fill=light)
    draw.rectangle([x, y + h - thickness, x + w, y + h], fill=dark)
    draw.rectangle([x + w - thickness, y, x + w, y + h], fill=dark)

def create_gradient_bg(width, height, top_color, bottom_color):
    base = Image.new("RGBA", (width, height), top_color)
    draw = ImageDraw.Draw(base)
    r1, g1, b1 = top_color[:3]
    r2, g2, b2 = bottom_color[:3]
    for y in range(height):
        t = y / max(1, height - 1)
        r = int(r1 + (r2 - r1) * t)
        g = int(g1 + (g2 - g1) * t)
        b = int(b1 + (b2 - b1) * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))
    return base

def draw_retro_grid(im, spacing=40, color=(255, 255, 255, 20)):
    draw = ImageDraw.Draw(im)
    for x in range(0, im.width, spacing):
        draw.line([(x, 0), (x, im.height)], fill=color, width=1)
    for y in range(0, im.height, spacing):
        draw.line([(0, y), (im.width, y)], fill=color, width=1)

def create_icon(title="GAME", subtitle="3D ARCADE", primary_color="#fcee4b"):
    print("Generating icon_512.png (512x512)...")
    im = create_gradient_bg(512, 512, (25, 25, 40), (10, 10, 20))
    draw_retro_grid(im, spacing=32, color=(255, 255, 255, 15))
    draw = ImageDraw.Draw(im)
    draw_beveled_border(draw, 0, 0, 512, 512, light=primary_color, dark="#221100", thickness=12)

    # Central emblem or block icon
    center_box = [156, 120, 356, 320]
    draw.rectangle(center_box, fill="#2b5329", outline="#54fb54", width=4)
    # Highlight
    draw.rectangle([160, 124, 352, 170], fill="#3d753a")
    # Star / Diamond in center
    draw.polygon([(256, 160), (310, 220), (256, 280), (202, 220)], fill=primary_color, outline="#ffffff")

    # Title Banner
    banner = Image.new("RGBA", (480, 120), (20, 20, 20, 240))
    b_draw = ImageDraw.Draw(banner)
    draw_beveled_border(b_draw, 0, 0, 480, 120, light="#888888", dark="#111111", thickness=5)
    im.paste(banner, (16, 360), banner)

    draw = ImageDraw.Draw(im)
    font_title = find_font(36)
    font_sub = find_font(18)

    draw.text((256 + 3, 390 + 3), title, font=font_title, fill="#000000", anchor="mm")
    draw.text((256, 390), title, font=font_title, fill=primary_color, anchor="mm")

    draw.text((256 + 2, 440 + 2), subtitle, font=font_sub, fill="#000000", anchor="mm")
    draw.text((256, 440), subtitle, font=font_sub, fill="#54fb54", anchor="mm")

    out_path = os.path.join(OUTPUT_DIR, "icon_512.png")
    im.save(out_path)
    print(f"Saved {out_path}")

def create_cover(title="GAME TITLE", subtitle="ОФИЦИАЛЬНАЯ ВЕРСИЯ"):
    print("Generating cover_800x470.png (800x470)...")
    im = create_gradient_bg(800, 470, (30, 30, 50), (12, 12, 25))
    draw_retro_grid(im, spacing=40, color=(255, 255, 255, 18))
    draw = ImageDraw.Draw(im)
    draw_beveled_border(draw, 0, 0, 800, 470, light="#666688", dark="#111122", thickness=8)

    # Decorative game elements
    draw.rectangle([70, 130, 190, 250], fill="#2b5329", outline="#54fb54", width=3)
    draw.rectangle([610, 130, 730, 250], fill="#881111", outline="#ff5555", width=3)

    # Center Panel
    f_big = find_font(38)
    f_sub = find_font(18)
    f_tag = find_font(13)

    draw.text((400 + 4, 110 + 4), title, font=f_big, fill="#000000", anchor="mm")
    draw.text((400, 110), title, font=f_big, fill="#ffff55", anchor="mm")

    draw.text((400 + 2, 165 + 2), subtitle, font=f_sub, fill="#000000", anchor="mm")
    draw.text((400, 165), subtitle, font=f_sub, fill="#ffffff", anchor="mm")

    # Star rating row
    f_star = find_font(28)
    stars = "★ ★ ★ ★ ★"
    draw.text((400, 220), stars, font=f_star, fill="#ffff55", anchor="mm")

    # Feature badges
    badges = ["БЕСПЛАТНО", "БЕЗ РЕГИСТРАЦИИ", "ОНЛАЙН И ОФЛАЙН"]
    bx = 90
    for b in badges:
        bw, bh = 190, 40
        b_img = Image.new("RGBA", (bw, bh), (40, 40, 50, 230))
        b_draw = ImageDraw.Draw(b_img)
        draw_beveled_border(b_draw, 0, 0, bw, bh, light="#aaaaaa", dark="#222222", thickness=3)
        b_draw.text((bw // 2, bh // 2), b, font=f_tag, fill="#55ff55", anchor="mm")
        im.paste(b_img, (bx, 370), b_img)
        bx += 220

    out_path = os.path.join(OUTPUT_DIR, "cover_800x470.png")
    im.save(out_path)
    print(f"Saved {out_path}")

def render_game_scene(w, h, hud_title, score, lives, highlight_text=None, is_mobile=False):
    im = create_gradient_bg(w, h, (35, 45, 65), (15, 20, 30))
    draw_retro_grid(im, spacing=35 if is_mobile else 50, color=(255, 255, 255, 15))
    draw = ImageDraw.Draw(im)

    # Top HUD
    hud_h = 90 if is_mobile else 80
    hud = Image.new("RGBA", (w - 40, hud_h), (20, 20, 25, 230))
    h_draw = ImageDraw.Draw(hud)
    draw_beveled_border(h_draw, 0, 0, w - 40, hud_h, light="#888888", dark="#111111", thickness=4)
    im.paste(hud, (20, 20), hud)

    f_hud = find_font(16 if is_mobile else 18)
    f_val = find_font(20 if is_mobile else 22)
    draw.text((45, 40), hud_title, font=f_hud, fill="#ffff55")
    draw.text((45, 68), f"СЧЁТ: {score}  |  РЕКОРД: 9999", font=f_val, fill="#55ff55")

    # Center game board or arena
    arena_w = w - 80 if is_mobile else 600
    arena_h = h - 260 if is_mobile else 400
    ax = (w - arena_w) // 2
    ay = 130
    arena = Image.new("RGBA", (arena_w, arena_h), (25, 25, 35, 220))
    a_draw = ImageDraw.Draw(arena)
    draw_beveled_border(a_draw, 0, 0, arena_w, arena_h, light="#55aa55", dark="#113311", thickness=5)
    im.paste(arena, (ax, ay), arena)

    # Draw gameplay entities
    draw = ImageDraw.Draw(im)
    cx, cy = ax + arena_w // 2, ay + arena_h // 2
    draw.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], fill="#54fb54", outline="#ffffff", width=3)

    # Highlight popup banner
    if highlight_text:
        bw, bh = min(w - 60, 480), 80
        bx = (w - bw) // 2
        by = ay + arena_h // 2 - 40
        banner = Image.new("RGBA", (bw, bh), (10, 10, 15, 245))
        b_draw = ImageDraw.Draw(banner)
        draw_beveled_border(b_draw, 0, 0, bw, bh, light="#ff5555", dark="#330000", thickness=5)
        f_pop = find_font(22)
        b_draw.text((bw // 2, bh // 2), highlight_text, font=f_pop, fill="#ffff55", anchor="mm")
        im.paste(banner, (bx, by), banner)

    return im

def create_screenshots():
    print("Generating screenshots...")
    # Desktop (1280x720)
    scenes = [
        ("desktop_1_gameplay.png", "УРОВЕНЬ 1", 1250, 3, None),
        ("desktop_2_action.png", "КОМБО АТАКА", 4800, 3, "СУПЕР УДАР x3!"),
        ("desktop_3_shop.png", "МАГАЗИН СКИНОВ", 5200, 3, "НОВЫЙ СКИН ОТКРЫТ!"),
        ("desktop_4_victory.png", "ФИНАЛ", 12800, 3, "ПОБЕДА! РЕКОРД!"),
    ]
    for filename, title, score, lives, highlight in scenes:
        img = render_game_scene(1280, 720, title, score, lives, highlight, is_mobile=False)
        p = os.path.join(SCREENSHOTS_DIR, filename)
        img.save(p)
        print(f"Saved {p}")

    # Mobile (720x1280)
    m_scenes = [
        ("mobile_1_gameplay.png", "УРОВЕНЬ 1", 1250, 3, None),
        ("mobile_2_action.png", "БОНУС", 3400, 3, "МЕГА КОМБО!"),
    ]
    for filename, title, score, lives, highlight in m_scenes:
        img = render_game_scene(720, 1280, title, score, lives, highlight, is_mobile=True)
        p = os.path.join(SCREENSHOTS_DIR, filename)
        img.save(p)
        print(f"Saved {p}")

def create_gameplay_videos(fps=30, duration_sec=5):
    ffmpeg_bin = shutil.which("ffmpeg")
    if not ffmpeg_bin:
        print("WARNING: ffmpeg not found in PATH! Skipping video encoding.")
        return

    total_frames = fps * duration_sec
    temp_dir = os.path.join(OUTPUT_DIR, ".temp_frames")
    os.makedirs(temp_dir, exist_ok=True)

    print(f"Rendering {total_frames} horizontal frames for video...")
    for f in range(total_frames):
        score = 1000 + f * 50
        highlight = "КОМБО x2!" if 40 <= f <= 90 else None
        frame = render_game_scene(1280, 720, "ГЕЙМПЛЕЙ", score, 3, highlight, is_mobile=False)
        frame.save(os.path.join(temp_dir, f"h_frame_{f:04d}.png"))

    out_h = os.path.join(VIDEO_DIR, "gameplay_horizontal.mp4")
    cmd_h = [
        ffmpeg_bin, "-y",
        "-framerate", str(fps),
        "-i", os.path.join(temp_dir, "h_frame_%04d.png"),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "20",
        out_h
    ]
    print(f"Encoding {out_h}...")
    subprocess.run(cmd_h, check=True)
    print(f"Saved {out_h}")

    print(f"Rendering {total_frames} vertical frames for video...")
    for f in range(total_frames):
        score = 1000 + f * 50
        highlight = "КОМБО x2!" if 40 <= f <= 90 else None
        frame = render_game_scene(720, 1280, "ГЕЙМПЛЕЙ", score, 3, highlight, is_mobile=True)
        frame.save(os.path.join(temp_dir, f"v_frame_{f:04d}.png"))

    out_v = os.path.join(VIDEO_DIR, "gameplay_vertical.mp4")
    cmd_v = [
        ffmpeg_bin, "-y",
        "-framerate", str(fps),
        "-i", os.path.join(temp_dir, "v_frame_%04d.png"),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "20",
        out_v
    ]
    print(f"Encoding {out_v}...")
    subprocess.run(cmd_v, check=True)
    print(f"Saved {out_v}")

    # Cleanup temp frames
    shutil.rmtree(temp_dir, ignore_errors=True)
    print("Cleaned up temp frames.")

if __name__ == "__main__":
    game_title = sys.argv[1] if len(sys.argv) > 1 else "SUPER GAME"
    game_sub = sys.argv[2] if len(sys.argv) > 2 else "3D ARCADE"
    create_icon(game_title, game_sub)
    create_cover(game_title, game_sub)
    create_screenshots()
    create_gameplay_videos()
    print("All media generated successfully!")
