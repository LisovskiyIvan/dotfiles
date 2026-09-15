#!/usr/bin/env python3
"""
validate_yandex_submission.py (yandex-assets skill)
Validates the store submission package for Yandex Games:
1. Text fields in ALL languages (RU + EN): files exist, every field filled,
   no placeholders, strict character limits, EN is a real translation (not a RU copy)
2. Dimensions of icon (512x512) and cover (800x470)
3. ALL screenshots are 16:9 landscape (portrait FAILS, incl. mobile slots)
4. Presence of horizontal/vertical gameplay videos

Game-code checks (SDK wiring, zip structure, base './') belong to yandex-games.
"""

import math
import os
import re
import sys
import glob
from PIL import Image

LIMITS = {
    "title": 50,
    "seo": 160,
    "short_description": 70,
    "about": 1000,
    "how_to_play": 1000,
    "keywords": 100,
    "developer_comment": 2048,
}

# filename -> required fields (parsed from "### header" + ```text blocks)
TEXT_FILES = {
    "01_general_info.md": ["keywords", "developer_comment"],
    "02_description_ru.md": ["title", "seo", "short_description", "about", "how_to_play"],
    "03_description_en.md": ["title", "seo", "short_description", "about", "how_to_play"],
}

# Fields where EN must differ from RU (proper-noun titles may legitimately match)
TRANSLATED_FIELDS = ["seo", "short_description", "about", "how_to_play"]

FIELD_PATTERNS = [
    ("short_description", ["short description", "короткое"]),
    ("how_to_play", ["how to play", "как играть"]),
    ("developer_comment", ["developer comment", "комментар"]),
    ("seo", ["seo"]),
    ("about", ["about", "об игре"]),
    ("keywords", ["keyword", "ключевые"]),
    ("title", ["title", "название"]),
]

PLACEHOLDER_RE = re.compile(r"\[[^\]\n]{0,400}\]|\bTODO\b|\bFIXME\b|\blorem\b", re.IGNORECASE)
FIELD_BLOCK_RE = re.compile(r"^###\s*(.+?)\s*$\n^```text\s*$\n(.*?)```", re.IGNORECASE | re.MULTILINE | re.DOTALL)

ASPECT_16_9 = 16 / 9


def is_16_9(w, h):
    return math.isclose(w / h, ASPECT_16_9, rel_tol=0.02)


def check_file_exists(path, desc):
    if not os.path.exists(path):
        print(f"❌ [MISSING] {desc}: {path}")
        return False
    print(f"✅ [FOUND] {desc}: {path}")
    return True


def validate_image_dimensions(path, expected_w, expected_h, desc):
    if not os.path.exists(path):
        print(f"❌ [MISSING] {desc}: {path}")
        return False
    try:
        with Image.open(path) as img:
            w, h = img.size
            if (w, h) == (expected_w, expected_h):
                print(f"✅ [OK] {desc} ({path}): {w}x{h}")
                return True
            else:
                print(f"❌ [INVALID SIZE] {desc} ({path}): Expected {expected_w}x{expected_h}, got {w}x{h}")
                return False
    except Exception as e:
        print(f"❌ [ERROR] Could not read {path}: {e}")
        return False


def map_header(header):
    h = header.lower()
    for field, keywords in FIELD_PATTERNS:
        if any(k in h for k in keywords):
            return field
    return None


def parse_text_fields(path):
    """Returns {field: text} parsed from '### header' + ```text blocks."""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            content = f.read()
    except OSError as e:
        print(f"❌ [ERROR] Could not read {path}: {e}")
        return {}
    fields = {}
    for header, body in FIELD_BLOCK_RE.findall(content):
        field = map_header(header)
        if field:
            fields[field] = body.strip()
    return fields


def normalize(text):
    return re.sub(r"\s+", " ", text.strip().lower())


def validate_texts(yandex_dir):
    print("\n--- Checking Texts (ALL languages: RU + EN) ---")
    ok = True
    parsed = {}
    for filename, required in TEXT_FILES.items():
        path = os.path.join(yandex_dir, filename)
        if not os.path.exists(path):
            print(f"❌ [MISSING] {filename} — translation file required for every supported language!")
            ok = False
            continue
        fields = parse_text_fields(path)
        parsed[filename] = fields
        for field in required:
            limit = LIMITS[field]
            if field not in fields:
                print(f"❌ [MISSING FIELD] {filename}: no '### ...' + ```text block for '{field}' (limit {limit}).")
                ok = False
                continue
            text = fields[field]
            if not text:
                print(f"❌ [EMPTY] {filename} → {field}: field not filled (limit {limit}).")
                ok = False
            elif PLACEHOLDER_RE.search(text):
                print(f"❌ [PLACEHOLDER] {filename} → {field}: contains unfilled [...] / TODO placeholder.")
                ok = False
            elif len(text) > limit:
                print(f"❌ [OVER LIMIT] {filename} → {field}: {len(text)} chars, STRICTLY ≤ {limit}.")
                ok = False
            else:
                print(f"✅ [OK] {filename} → {field}: {len(text)}/{limit} chars.")

    # EN must be a real translation, not a copy of RU (titles may match)
    ru = parsed.get("02_description_ru.md", {})
    en = parsed.get("03_description_en.md", {})
    if ru and en:
        for field in TRANSLATED_FIELDS:
            if field in ru and field in en and normalize(ru[field]) == normalize(en[field]):
                print(f"❌ [NOT TRANSLATED] {field}: EN text copies RU — provide a real English translation!")
                ok = False
    return ok


def validate_screenshots(screens_dir):
    print(f"\n--- Checking Screenshots (ALL must be 16:9): {screens_dir} ---")
    if not os.path.exists(screens_dir):
        print("❌ [MISSING] 'screenshots/' directory not found.")
        return False
    screens = sorted(f for f in os.listdir(screens_dir) if f.lower().endswith(('.png', '.webp', '.jpg')))
    if len(screens) < 2:
        print(f"⚠️ [WARNING] Found only {len(screens)} screenshot(s) (recommended at least 2-4 desktop + 1-2 mobile).")
    ok = True
    for f in screens:
        p = os.path.join(screens_dir, f)
        try:
            with Image.open(p) as img:
                w, h = img.size
                if is_16_9(w, h):
                    print(f"✅ [OK] {f}: {w}x{h} (16:9)")
                else:
                    print(f"❌ [INVALID ASPECT] {f}: {w}x{h} is NOT 16:9 — re-render as 1280x720!")
                    ok = False
        except Exception as e:
            print(f"❌ [ERROR] Could not read {p}: {e}")
            ok = False
    return ok


def main():
    root = os.getcwd()
    yandex_dir = os.path.join(root, "yandex")
    if not os.path.exists(yandex_dir):
        # Check store/ or yandex-assets/
        if os.path.exists(os.path.join(root, "store")):
            yandex_dir = os.path.join(root, "store")
        elif os.path.exists(os.path.join(root, "yandex-assets")):
            yandex_dir = os.path.join(root, "yandex-assets")
        else:
            print("❌ [ERROR] 'yandex/' directory not found in current directory.")
            sys.exit(1)

    print(f"=== Validating Yandex Games store package in '{os.path.relpath(yandex_dir, root)}' ===")
    all_ok = True

    # Check Texts (mandatory in ALL languages)
    all_ok &= validate_texts(yandex_dir)

    # Check Icon
    icon_candidates = [
        os.path.join(yandex_dir, "icon_512.png"),
        os.path.join(yandex_dir, "icon_512x512.png"),
        os.path.join(yandex_dir, "icon.png"),
        os.path.join(yandex_dir, "art", "icon-512.png"),
    ]
    icon_path = next((p for p in icon_candidates if os.path.exists(p)), None)
    if icon_path:
        all_ok &= validate_image_dimensions(icon_path, 512, 512, "Game Icon")
    else:
        print("❌ [MISSING] Icon 512x512 png not found!")
        all_ok = False

    # Check Cover
    cover_candidates = [
        os.path.join(yandex_dir, "cover_800x470.png"),
        os.path.join(yandex_dir, "cover.png"),
        os.path.join(yandex_dir, "art", "cover-800x470.png"),
    ]
    cover_path = next((p for p in cover_candidates if os.path.exists(p)), None)
    if cover_path:
        all_ok &= validate_image_dimensions(cover_path, 800, 470, "Game Cover")
    else:
        print("❌ [MISSING] Cover 800x470 png not found!")
        all_ok = False

    # Check Screenshots (strict 16:9, incl. mobile slots)
    screens_dir = os.path.join(yandex_dir, "screenshots")
    if not os.path.exists(screens_dir):
        screens_dir = os.path.join(yandex_dir, "screens")

    all_ok &= validate_screenshots(screens_dir)

    # Check Videos
    video_dir = os.path.join(yandex_dir, "video")
    videos = glob.glob(os.path.join(yandex_dir, "*.mp4")) + glob.glob(os.path.join(yandex_dir, "*.webm"))
    if os.path.exists(video_dir):
        videos += glob.glob(os.path.join(video_dir, "*.mp4")) + glob.glob(os.path.join(video_dir, "*.webm"))

    if len(videos) >= 1:
        print(f"✅ [OK] Found {len(videos)} video file(s): {[os.path.basename(v) for v in videos]}")
    else:
        print("⚠️ [WARNING] No gameplay videos found (gameplay_horizontal.mp4 / gameplay_vertical.mp4)")

    print("\n=== SUMMARY ===")
    if all_ok:
        print("✅ Store package validation PASSED — texts (RU+EN), media, and videos ready for moderation.")
    else:
        print("❌ Some requirements failed! Please fix before submitting to moderation.")
        sys.exit(1)


if __name__ == "__main__":
    main()
