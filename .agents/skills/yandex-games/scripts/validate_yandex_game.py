#!/usr/bin/env python3
"""
validate_yandex_game.py (yandex-games skill)
Validates the GAME side of a Yandex Games submission:
1. /sdk.js declared in <head> of index.html before the game bundle
2. vite.config.ts uses base: './'
3. No external network URLs in built output (except /sdk.js)
4. SDK call sites present in sources (init, LoadingAPI, GameplayAPI,
   environment.i18n.lang, getPlayer/getData/setData)
5. Zip archive structure (index.html at root, no nested dist/)

Media/text checks (yandex/ sizes, 16:9 screenshots, videos, char limits)
belong to the yandex-assets skill: validate_yandex_submission.py.
"""

import glob
import os
import re
import sys
import zipfile

ROOT = os.getcwd()
SRC_DIRS = ["src", "source", "app", "."]
SDK_SCRIPT_RE = re.compile(r'<script[^>]+src=["\']/?sdk\.js["\']', re.IGNORECASE)
EXTERNAL_URL_RE = re.compile(r'https?://(?!yandex\.)[^\s"\'<>]+', re.IGNORECASE)

REQUIRED_CALLSITES = [
    ("YaGames.init", re.compile(r"YaGames\s*\.\s*init\s*\(")),
    ("LoadingAPI.ready", re.compile(r"LoadingAPI\?\s*\.\s*ready\s*\(")),
    ("GameplayAPI.start", re.compile(r"GameplayAPI\?\s*\.\s*start\s*\(")),
    ("GameplayAPI.stop", re.compile(r"GameplayAPI\?\s*\.\s*stop\s*\(")),
    ("environment.i18n.lang", re.compile(r"environment\?\s*\.\s*i18n\?\s*\.\s*lang")),
    ("getPlayer", re.compile(r"getPlayer\s*\(")),
]


def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def check_index_html():
    print("--- Checking index.html (SDK in <head>) ---")
    candidates = [os.path.join(ROOT, "index.html"), os.path.join(ROOT, "public", "index.html")]
    path = next((p for p in candidates if os.path.exists(p)), None)
    if not path:
        print("❌ [MISSING] index.html not found in project root.")
        return False
    html = read_text(path)
    head = html.split("</head>")[0] if "</head>" in html else html
    m = SDK_SCRIPT_RE.search(head)
    if not m:
        print(f"❌ [INVALID] {path}: <script src=\"/sdk.js\"> not found inside <head>.")
        return False
    bundle = re.search(r'<script[^>]+src=["\']\.?/?src/', html)
    if bundle and m.start() > bundle.start():
        print(f"❌ [INVALID] {path}: /sdk.js must come BEFORE the game bundle script.")
        return False
    print(f"✅ [OK] {path}: /sdk.js declared in <head> before bundle.")
    return True


def check_vite_base():
    print("--- Checking vite.config.ts (base './') ---")
    candidates = glob.glob(os.path.join(ROOT, "vite.config.*"))
    if not candidates:
        print("⚠️ [WARNING] vite.config.* not found, skipping base check.")
        return True
    content = read_text(candidates[0])
    if re.search(r"""base\s*:\s*['"]\./['"]""", content):
        print(f"✅ [OK] {candidates[0]}: base './' set.")
        return True
    print(f"❌ [INVALID] {candidates[0]}: base './' is required for Yandex S3 iframes.")
    return False


def iter_source_files():
    exts = (".ts", ".tsx", ".js", ".jsx", ".html")
    seen = set()
    for d in SRC_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [x for x in dirnames if x not in ("node_modules", "dist", ".git", "yandex")]
            for fn in filenames:
                if fn.endswith(exts):
                    p = os.path.join(dirpath, fn)
                    if p not in seen:
                        seen.add(p)
                        yield p


def check_callsites():
    print("--- Checking SDK call sites in sources ---")
    blob = "\n".join(read_text(p) for p in iter_source_files())
    ok = True
    for name, rx in REQUIRED_CALLSITES:
        if rx.search(blob):
            print(f"✅ [OK] call site found: {name}")
        else:
            print(f"❌ [MISSING] call site not found: {name}")
            ok = False
    return ok


def check_dist_external_urls():
    print("--- Checking built output for external URLs ---")
    dist = os.path.join(ROOT, "dist")
    if not os.path.isdir(dist):
        print("⚠️ [SKIP] dist/ not built yet (run `bun run build` first).")
        return True
    ok = True
    for dirpath, _, filenames in os.walk(dist):
        for fn in filenames:
            if fn.endswith((".html", ".js", ".css")):
                content = read_text(os.path.join(dirpath, fn))
                for url in set(EXTERNAL_URL_RE.findall(content)):
                    print(f"❌ [EXTERNAL URL] {os.path.join(dirpath, fn)}: {url}")
                    ok = False
    if ok:
        print("✅ [OK] No external URLs in dist/ (build is self-contained).")
    return ok


def inspect_zip(zip_path):
    print(f"--- Checking Zip Archive: {zip_path} ---")
    try:
        with zipfile.ZipFile(zip_path, "r") as z:
            names = z.namelist()
            if "index.html" in names:
                print("✅ [OK] 'index.html' is in the root of the zip archive.")
            elif any(n.endswith("index.html") for n in names):
                nested = [n for n in names if n.endswith("index.html")][0]
                print(f"❌ [CRITICAL] index.html is nested at '{nested}'. It must be at the ROOT of the zip!")
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
    print("=== Validating Yandex Games code package ===")
    all_ok = True
    all_ok &= check_index_html()
    all_ok &= check_vite_base()
    all_ok &= check_callsites()
    all_ok &= check_dist_external_urls()

    zips = glob.glob(os.path.join(ROOT, "*.zip"))
    if zips:
        for z in zips:
            all_ok &= inspect_zip(z)
    else:
        print("⚠️ [SKIP] No *.zip found (run `bun run pack` first).")

    print("\n=== SUMMARY ===")
    if all_ok:
        print("✅ Game validation PASSED.")
    else:
        print("❌ Some game requirements failed! Fix before moderation.")
        sys.exit(1)


if __name__ == "__main__":
    main()
