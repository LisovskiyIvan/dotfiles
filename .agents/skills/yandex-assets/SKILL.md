---
name: yandex-assets
description: >-
  Store submission package for Yandex Games (Яндекс Игры): yandex/ folder texts
  translated into ALL supported languages (RU + EN) with strict character limits,
  512x512 icon, 800x470 cover, ALL 16:9 screenshots (including mobile slots),
  horizontal/vertical gameplay videos via ffmpeg, and pre-moderation validation.
---

# Yandex Games — Store Assets & Submission Package Skill

Builds the complete `yandex/` submission package: texts, icon, cover, screenshots, videos.
Game code (SDK, saves, ads, audio) lives in the `yandex-games` skill — this skill covers **only** store-facing assets.

---

## 1. The `yandex/` Package Structure

Every game repository MUST contain a `yandex/` folder ready for copy-pasting into the Developer Console:

```
yandex/
├── README.md               # Summary & step-by-step submission instructions
├── 01_general_info.md      # Fields for "Общее" tab
├── 02_description_ru.md    # Fields for "Русский" tab
├── 03_description_en.md    # Fields for "English" tab
├── icon_512.png            # PNG 512×512 px (strict)
├── cover_800x470.png       # PNG 800×470 px (strict)
├── screenshots/            # Gameplay screenshots — ALL 16:9, see §4
│   ├── desktop_1.png       # 1280×720 or 1920×1080
│   ├── desktop_2.png
│   ├── desktop_3.png
│   ├── desktop_4.png
│   ├── mobile_1.png        # ALSO 16:9 (1280×720) — NOT portrait!
│   └── mobile_2.png        # ALSO 16:9 (1280×720) — NOT portrait!
└── video/                  # Promotional gameplay videos
    ├── gameplay_horizontal.mp4 # 16:9 H.264 MP4 (~15–30s)
    └── gameplay_vertical.mp4   # 9:16 H.264 MP4 (~15–30s)
```

Start from the per-file templates — copy them into `yandex/` and fill EVERY field:

- `templates/01_general_info.md` → `yandex/01_general_info.md` (tab «Общее»)
- `templates/02_description_ru.md` → `yandex/02_description_ru.md` (tab «Русский»)
- `templates/03_description_en.md` → `yandex/03_description_en.md` (tab «English»)
- `templates/CONSOLE_FORM.md` — full reference (all tabs, leaderboards, checklists)

Keep the `### header (≤ limit)` + ` ```text ` block format intact — the validator parses it.

---

## 2. Strict Character Limits & Field Checklist

### 2.0. RULE: Every Text in ALL Languages (ВАЖНО)

**Every store text MUST be translated into all supported languages — Russian (`ru`) AND English (`en`).**
No empty tabs, no `[...]` placeholders left, no EN tab copied from RU:

- `02_description_ru.md` and `03_description_en.md` contain the same 5 fields with the same meaning — EN is a **real translation**, not a copy (only proper-noun titles may match).
- `01_general_info.md` (keywords ≤ 100, developer comment ≤ 2048) is filled once.
- The validator FAILS on: missing language file, missing/empty field, placeholder text, over-limit text, EN identical to RU.

### 2.1. Общее (General)

- **Версия**: `0.0.0.1`
- **Поддерживаемые платформы**: Десктопные, Мобильные, Планшеты
- **Ориентация**: Любая (или Альбомная / Портретная)
- **Рекомендуемые языки перевода**: Русский (`ru`), Английский (`en`)
- **Управление языком**: Автоматически через Yandex Games SDK (`ysdk.environment.i18n.lang`).
- **Возрастной рейтинг**: `0+` (без насилия/азарта), `6+`, `12+`
- **Категории**: 1–2 категории (например: «Аркады», «Казуальные», «Головоломки»)
- **Теги**: 3–5 тегов
- **Ключевые слова**: через запятую (**СТРОГО ≤ 100 символов**)
- **Облачные сохранения**: Да / Нет (Да — если игра вызывает `player.setData()` / `player.getData()`, см. скилл `yandex-games`)
- **Отсроченная публикация**: Нет
- **Комментарий разработчика** (**СТРОГО ≤ 2048 символов**):
  Moderation note covering SDK v2 compliance: LoadingAPI.ready(), GameplayAPI.start/stop,
  60s interstitial cooldown, rewarded video flow, i18n auto-detection, relative paths `./`,
  zero external network calls, audio mute on blur/pause. Template text is in `templates/CONSOLE_FORM.md`.

### 2.2. Описание и продвижение (RU & EN)

Each language tab must provide:

- **Название / Title**: **СТРОГО ≤ 50 символов**
- **Описание для SEO / SEO Description**: **СТРОГО ≤ 160 символов**
- **Короткое описание / Short Description**: **СТРОГО ≤ 70 символов**
- **Об игре / About**: **СТРОГО ≤ 1000 символов**
- **Как играть / How to Play**: **СТРОГО ≤ 1000 символов**

---

## 3. Icon & Cover (Strict Sizes)

- **Icon** `yandex/icon_512.png` — PNG, **exactly 512×512 px**: main character/item, high-contrast border, vignette, title banner.
- **Cover** `yandex/cover_800x470.png` — PNG, **exactly 800×470 px**: promo banner with title, badges («БЕСПЛАТНО», «БЕЗ РЕГИСТРАЦИИ», feature highlights), stylized game elements.

---

## 4. Screenshots — ALL 16:9 (ВАЖНО)

**RULE: every screenshot is 16:9 landscape — 1280×720 or 1920×1080. No exceptions.**

- Desktop slots (`desktop_1..4.png`): 1280×720 or 1920×1080.
- Mobile slots (`mobile_1..2.png`): **ALSO 16:9 (1280×720)** — vertical/portrait screenshots (720×1280, 9:16) are **FORBIDDEN** and fail validation.
- Minimum: 2–4 desktop + 1–2 mobile slots; show distinct phases:
  - Core gameplay with HUD and active controls
  - Action / Combo / Explosion / Particle burst
  - Progression / Shop / Level select / Upgrades
  - Victory / Game Over / Leaderboard screen

---

## 5. Gameplay Videos

- `yandex/video/gameplay_horizontal.mp4` — 16:9 H.264 MP4, 1280×720, ~15–30s.
- `yandex/video/gameplay_vertical.mp4` — 9:16 H.264 MP4, 720×1280, ~15–30s.
- Encode from rendered frames with `ffmpeg`:
  ```bash
  # Horizontal (16:9)
  ffmpeg -y -framerate 30 -i temp_frames/frame_%04d.png -c:v libx264 -pix_fmt yuv420p -crf 20 yandex/video/gameplay_horizontal.mp4

  # Vertical (9:16)
  ffmpeg -y -framerate 30 -i temp_vframes/vframe_%04d.png -c:v libx264 -pix_fmt yuv420p -crf 20 yandex/video/gameplay_vertical.mp4
  ```

---

## 6. Automated Media Generation with ffmpeg

Generate or record media autonomously with the included Python + Pillow + ffmpeg script:

```bash
python3 scripts/generate_yandex_media.py "НАЗВАНИЕ ИГРЫ" "ПОДЗАГОЛОВОК"
```

Workflow: icon (512×512) → cover (800×470) → screenshots (all 1280×720 16:9, desktop + mobile slots) → gameplay videos (horizontal 16:9 + vertical 9:16 via ffmpeg).

---

## 7. Validation & Pre-Moderation Gate

Before finishing, run the validation script from the game project root:

```bash
python3 scripts/validate_yandex_submission.py
```

Checks:

- Texts in ALL languages: `01_general_info.md`, `02_description_ru.md`, `03_description_en.md` exist; every field filled, no placeholders, within limits (50, 160, 70, 1000, 100, 2048); EN translated, not copied from RU
- `icon_512.png` exactly 512×512, `cover_800x470.png` exactly 800×470
- **Every** screenshot is 16:9 (portrait files FAIL)
- Presence and format of `gameplay_horizontal.mp4` and `gameplay_vertical.mp4`

Game-code checks (SDK wiring, zip structure, `base: './'`) belong to the `yandex-games` skill.

---

## 8. Console Upload Checklist (Промо-материалы)

- [ ] Icon: `yandex/icon_512.png` (PNG 512×512)
- [ ] Cover: `yandex/cover_800x470.png` (PNG 800×470)
- [ ] Desktop screenshots: 2–4 files, 16:9 landscape
- [ ] Mobile screenshots: 1–2 files, **16:9 landscape** (not portrait)
- [ ] Gameplay videos: `gameplay_horizontal.mp4` (16:9) + `gameplay_vertical.mp4` (9:16)
- [ ] Texts filled in ALL languages: `01_general_info.md`, `02_description_ru.md`, `03_description_en.md` — no placeholders, within limits
- [ ] EN tab is a real translation of RU (same meaning, not a copy); only the title may match
- [ ] `validate_yandex_submission.py` passes with exit code 0
