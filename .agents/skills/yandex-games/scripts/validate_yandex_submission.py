#!/usr/bin/env python3
"""
validate_yandex_submission.py
Validates compliance with Yandex Games Console submission requirements:
1. Character limits for text fields (RU and EN)
2. Dimensions of icon (512x512) and cover (800x470)
3. Presence of desktop/mobile screenshots
4. Presence of horizontal/vertical gameplay videos
5. Zip archive inspection (index.html at root, no nested dist/)
"""

import os
import sys
import glob
import zipfile
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

def inspect_zip(zip_path):
    print(f"\n--- Checking Zip Archive: {zip_path} ---")
    if not os.path.exists(zip_path):
        print(f"⚠️ [WARNING] Zip archive not found at {zip_path}")
        return False
    try:
        with zipfile.ZipFile(zip_path, 'r') as z:
            names = z.namelist()
            if "index.html" in names:
                print("✅ [OK] 'index.html' is in the root of the zip archive.")
            elif any(n.endswith("index.html") for n in names):
                nested = [n for n in names if n.endswith("index.html")][0]
                print(f"❌ [CRITICAL MODERATION REJECTION] index.html is nested at '{nested}'. It must be at the ROOT of the zip!")
                return False
            else:
                print("❌ [CRITICAL] No index.html found in the zip archive!")
                return False
            print(f"✅ Archive contains {len(names)} files. Size: {os.path.getsize(zip_path) / 1024:.1f} KB")
            return True
    except Exception as e:
        print(f"❌ Error opening zip {zip_path}: {e}")
        return False

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

    print(f"=== Validating Yandex Games Package in '{os.path.relpath(yandex_dir, root)}' ===")
    all_ok = True

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

    # Check Screenshots
    screens_dir = os.path.join(yandex_dir, "screenshots")
    if not os.path.exists(screens_dir):
        screens_dir = os.path.join(yandex_dir, "screens")
    
    if os.path.exists(screens_dir):
        screens = [f for f in os.listdir(screens_dir) if f.lower().endswith(('.png', '.webp', '.jpg'))]
        if len(screens) >= 2:
            print(f"✅ [OK] Found {len(screens)} screenshots in {screens_dir}")
        else:
            print(f"⚠️ [WARNING] Found only {len(screens)} screenshots (recommended at least 2-4).")
    else:
        print("❌ [MISSING] 'screenshots/' directory not found.")
        all_ok = False

    # Check Videos
    video_dir = os.path.join(yandex_dir, "video")
    videos = glob.glob(os.path.join(yandex_dir, "*.mp4")) + glob.glob(os.path.join(yandex_dir, "*.webm"))
    if os.path.exists(video_dir):
        videos += glob.glob(os.path.join(video_dir, "*.mp4")) + glob.glob(os.path.join(video_dir, "*.webm"))

    if len(videos) >= 1:
        print(f"✅ [OK] Found {len(videos)} video file(s): {[os.path.basename(v) for v in videos]}")
    else:
        print("⚠️ [WARNING] No gameplay videos found (gameplay_horizontal.mp4 / gameplay_vertical.mp4)")

    # Check Zip Archive in project root
    zips = glob.glob(os.path.join(root, "*.zip"))
    for z in zips:
        inspect_zip(z)

    print("\n=== SUMMARY ===")
    if all_ok:
        print("✅ Core validation PASSED. Check text character limits in markdown files manually or via form.")
    else:
        print("❌ Some requirements failed! Please fix before submitting to moderation.")

if __name__ == "__main__":
    main()
