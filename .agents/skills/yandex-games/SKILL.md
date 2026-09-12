---
name: yandex-games
description: >-
  Build, localize, monetize, and publish games for Yandex Games (Яндекс Игры).
  Enforces Bun, latest Vite/Three.js/Rapier dependencies, SDK v2 integration (Loading/Gameplay API,
  interstitial cooldown, rewarded ads, cloud saves, leaderboards), strict bilingual RU/EN i18n via SDK,
  autonomous asset sourcing/procedural synthesis, automated media generation (icon, cover, screenshots,
  ffmpeg gameplay videos), and complete yandex/ store submission metadata compliant with platform moderation.
---

# Yandex Games (Яндекс Игры) — Game Development & Publishing Skill

Comprehensive guide, patterns, and toolkits for developing, integrating, packaging, and publishing browser games to **Yandex Games (Яндекс Игры)**.

---

## 1. Core Principles & Philosophy

1. **Zero External Requests**: The final build must be 100% self-contained. No external CDNs, Google Fonts, remote scripts, or tracking pixels. Everything (including fonts and sound effects) must reside inside the uploaded zip archive. The only allowed external script is the platform's `/sdk.js`.
2. **Relative Asset Paths**: Vite must use `base: './'`. Absolute paths (`/assets/...`) fail because Yandex hosts game iframes from arbitrary S3/bucket subfolders.
3. **Graceful Standalone Mode**: Games must run identically during local development (`bun run dev`) and on the Yandex platform iframe. When the SDK is absent or times out, it must fall back to mocks and `localStorage` without errors or blocking gameplay.
4. **Strict Bilingual Localization (Requirement 2.14)**: Language MUST be driven by `ysdk.environment.i18n.lang`. The moderation team inspects both Russian (`ru`) and English (`en`). URL parameters `?lang=ru` and `?lang=en` must be supported for testing.
5. **Responsible Advertising**: Interstitial ads must observe a 60-second cooldown and appear only during natural pauses (game over, level restart, return to menu). Rewarded videos must be user-initiated and award prizes exclusively on the `onRewarded` callback. Sound and physics must pause during ads.
6. **Complete Submission Package (`yandex/`)**: Every project must contain a `yandex/` directory with verified text fields (strictly respecting character limits), 512×512 icon, 800×470 cover, desktop/mobile screenshots, and horizontal/vertical gameplay videos recorded or encoded via `ffmpeg`.

---

## 2. Tech Stack & Dependencies

All projects must use **Bun** and latest stable versions:

| Category | Recommended Stack | Key Packages |
| :--- | :--- | :--- |
| **Package Manager** | Bun | `bun install`, `bun run dev`, `bun run build`, `bun run pack` |
| **Bundler** | Vite (latest v8+) | `vite`, `typescript` |
| **2D Games** | Canvas 2D / DOM / Pixi | `@dimforge/rapier2d-compat` (for 2D physics) |
| **3D Games** | Three.js + Rapier | `three`, `@types/three`, `@dimforge/rapier3d-compat` (or 2D compat for 2.5D) |
| **Audio** | Procedural Web Audio API | Zero external audio asset size; 100% offline |
| **Fonts** | Local WOFF2 / TTF | Bundled in `public/fonts/` with `@font-face` (Cyrillic + Latin) |

### Vite Configuration (`vite.config.ts`)
```ts
import { defineConfig } from 'vite';

// CRITICAL: base './' is required. Absolute /assets/ paths 404 in Yandex S3 iframes.
export default defineConfig({
  base: './',
  build: {
    target: 'es2022',
    assetsInlineLimit: 0,
  },
});
```

### Package.json Scripts
```json
{
  "name": "my-yandex-game",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "pack": "rm -rf dist && vite build && cd dist && rm -f ../game-yandex.zip && zip -rq ../game-yandex.zip .",
    "media": "python3 scripts/generate_yandex_media.py"
  }
}
```
> **IMPORTANT**: In the generated zip archive, `index.html` must be in the archive's root directory, NOT inside a nested `dist/` folder.

---

## 3. Yandex Games SDK v2 Integration

### HTML `<head>` Setup (`index.html`)
Requirement 1.1 of moderation: `/sdk.js` must be declared in `<head>` before the game bundle script:
```html
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no" />
  <title>Game Title</title>
  <!-- Yandex Games SDK v2: must be in <head> before game bundle -->
  <script src="/sdk.js"></script>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/src/main.ts"></script>
</body>
</html>
```

### SDK Wrapper Blueprint (`src/yandex.ts`)
The game must use a wrapper that abstracts all SDK features and provides seamless local development mocks:

```ts
// src/yandex.ts
export interface YandexSDK {
  environment: { i18n: { lang: string } };
  adv: {
    showFullscreenAdv: (opts: { callbacks: { onClose?: (wasShown: boolean) => void; onError?: (err: unknown) => void } }) => void;
    showRewardedVideo: (opts: { callbacks: { onOpen?: () => void; onRewarded?: () => void; onClose?: () => void; onError?: (err: unknown) => void } }) => void;
  };
  features: {
    LoadingAPI?: { ready: () => void };
    GameplayAPI?: { start: () => void; stop: () => void };
  };
  getPlayer: (opts?: { scopes: boolean }) => Promise<YandexPlayer>;
  getLeaderboards: () => Promise<YandexLeaderboards>;
  on?: (event: string, callback: () => void) => void;
}

export interface YandexPlayer {
  getData: (keys?: string[]) => Promise<Record<string, unknown>>;
  setData: (data: Record<string, unknown>, flush?: boolean) => Promise<void>;
  isAuthorized: () => boolean;
  getName: () => string;
}

export interface YandexLeaderboards {
  setLeaderboardScore: (name: string, score: number) => Promise<void>;
}

class YandexManager {
  public sdk: YandexSDK | null = null;
  public player: YandexPlayer | null = null;
  public isPlatform = false;
  public lang: 'ru' | 'en' = 'ru';
  private lastInterstitialAt = 0;
  private readonly INTERSTITIAL_COOLDOWN_MS = 60_000; // 60-second rule

  public async init({ onPause, onResume }: { onPause?: () => void; onResume?: () => void } = {}): Promise<void> {
    // 1. Language detection (SDK -> URL param -> navigator -> fallback ru)
    const urlLang = new URLSearchParams(window.location.search).get('lang');
    if (urlLang) {
      this.lang = urlLang.toLowerCase().startsWith('ru') ? 'ru' : 'en';
    }

    // 2. Detect YaGames global (timeout for standalone dev)
    const hasYaGames = await this.waitForYaGames(2000);
    if (hasYaGames && window.YaGames) {
      try {
        this.sdk = await window.YaGames.init();
        this.isPlatform = this.detectPlatform(this.sdk);
        
        // Listen to platform pause/resume events (mutes audio, pauses physics)
        this.sdk.on?.('game_api_pause', () => onPause?.());
        this.sdk.on?.('game_api_resume', () => onResume?.());

        const sdkLang = this.sdk.environment?.i18n?.lang;
        if (!urlLang && sdkLang) {
          this.lang = sdkLang.toLowerCase().startsWith('ru') ? 'ru' : 'en';
        }

        try {
          this.player = await this.sdk.getPlayer({ scopes: false });
        } catch {
          // Guest player mode
        }
      } catch (err) {
        console.info('[YandexSDK] Standalone fallback:', err);
      }
    } else {
      const navLang = navigator.language || 'ru';
      if (!urlLang) {
        this.lang = navLang.toLowerCase().startsWith('ru') ? 'ru' : 'en';
      }
    }

    document.documentElement.lang = this.lang;
  }

  private waitForYaGames(timeoutMs = 2000): Promise<boolean> {
    const t0 = Date.now();
    return new Promise((resolve) => {
      const check = () => {
        if ((window as any).YaGames) return resolve(true);
        if (Date.now() - t0 > timeoutMs) return resolve(false);
        setTimeout(check, 100);
      };
      check();
    });
  }

  private detectPlatform(sdk: any): boolean {
    try {
      const ao = (window.location as any).ancestorOrigins;
      if (ao && ao.length > 0) return [...ao].some((o: string) => /(^|\.)yandex\./.test(o));
      if (document.referrer) return /(^|\.)yandex\./.test(new URL(document.referrer).hostname);
    } catch (_) {}
    return !!sdk.deviceInfo?.type;
  }

  // --- Mandatory Moderation Lifecycle Calls ---
  public loadingReady(): void {
    try { this.sdk?.features?.LoadingAPI?.ready(); } catch (_) {}
  }

  public gameplayStart(): void {
    try { this.sdk?.features?.GameplayAPI?.start(); } catch (_) {}
  }

  public gameplayStop(): void {
    try { this.sdk?.features?.GameplayAPI?.stop(); } catch (_) {}
  }

  // --- Advertising API with Safety Rules ---
  public showFullscreenAdv(onClose?: (wasShown: boolean) => void): void {
    const now = Date.now();
    if (!this.isPlatform || now - this.lastInterstitialAt < this.INTERSTITIAL_COOLDOWN_MS) {
      onClose?.(false);
      return;
    }

    this.lastInterstitialAt = now;
    this.gameplayStop();
    try {
      this.sdk?.adv.showFullscreenAdv({
        callbacks: {
          onClose: (wasShown) => {
            this.gameplayStart();
            onClose?.(!!wasShown);
          },
          onError: () => {
            this.gameplayStart();
            onClose?.(false);
          },
        },
      });
    } catch {
      this.gameplayStart();
      onClose?.(false);
    }
  }

  public showRewardedVideo(onReward: () => void, onClose?: (rewarded: boolean) => void): void {
    if (!this.isPlatform) {
      console.info('[YandexSDK] Local mock rewarded video');
      onReward();
      onClose?.(true);
      return;
    }

    this.gameplayStop();
    let rewarded = false;
    try {
      this.sdk?.adv.showRewardedVideo({
        callbacks: {
          onRewarded: () => {
            rewarded = true;
            onReward();
          },
          onClose: () => {
            this.gameplayStart();
            onClose?.(rewarded);
          },
          onError: () => {
            this.gameplayStart();
            if (!rewarded) onClose?.(false);
          },
        },
      });
    } catch {
      this.gameplayStart();
      onClose?.(false);
    }
  }

  // --- Cloud Saves & Leaderboards ---
  public async loadData<T extends Record<string, any>>(key: string, fallback: T): Promise<T> {
    const local = localStorage.getItem(key);
    let result = local ? JSON.parse(local) : fallback;

    if (this.player && this.isPlatform) {
      try {
        const cloud = await this.player.getData([key]);
        if (cloud && cloud[key]) {
          result = { ...result, ...cloud[key] };
        }
      } catch (_) {}
    }
    return result;
  }

  public async saveData(key: string, data: Record<string, any>): Promise<void> {
    localStorage.setItem(key, JSON.stringify(data));
    if (this.player && this.isPlatform) {
      try {
        await this.player.setData({ [key]: data });
      } catch (_) {}
    }
  }

  public async submitScore(leaderboardName: string, score: number): Promise<void> {
    if (!this.player || !this.isPlatform) return;
    try {
      const lb = await this.sdk?.getLeaderboards();
      await lb?.setLeaderboardScore(leaderboardName, score);
    } catch (_) {}
  }
}

export const yandex = new YandexManager();
```

---

## 4. Bilingual Localization (RU & EN)

Moderation Requirement 2.14 states that language must adapt automatically to the user's platform locale.

### Dictionary Pattern (`src/i18n.ts`)
```ts
export type Lang = 'ru' | 'en';

const STRINGS: Record<Lang, Record<string, string>> = {
  ru: {
    title: 'Моя Игра',
    score: 'СЧЁТ: {n}',
    record: 'РЕКОРД: {n}',
    gameOver: 'ИГРА ОКОНЧЕНА',
    restart: 'ИГРАТЬ СНОВА',
    reviveAd: 'ВОЗРОДИТЬСЯ (РЕКЛАМА)',
    howToPlay: 'КАК ИГРАТЬ',
  },
  en: {
    title: 'My Game',
    score: 'SCORE: {n}',
    record: 'BEST: {n}',
    gameOver: 'GAME OVER',
    restart: 'PLAY AGAIN',
    reviveAd: 'REVIVE (AD)',
    howToPlay: 'HOW TO PLAY',
  },
};

export function t(lang: Lang, key: string, params?: Record<string, string | number>): string {
  let str = STRINGS[lang]?.[key] ?? STRINGS.ru[key] ?? key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      str = str.replace(`{${k}}`, String(v));
    }
  }
  return str;
}
```

---

## 5. Autonomous Asset Strategy

The agent must gather or create all assets independently:

1. **Procedural Web Audio API Synth**:
   Use oscillators, frequency sweeps, noise buffers, and gain ramps to synthesize all audio effects without loading audio files:
   - **Jump / Bounce**: Quick pitch bend from 150 Hz to 450 Hz with sine/triangle wave.
   - **Score / Coin Chime**: High sine wave (880 Hz to 1320 Hz) with exponential decay.
   - **Explosion**: White noise buffer filtered with a low-pass filter and rapid decay.
   - **Click / Tap**: Short 20ms square wave chirp.
   - **Game Over**: Descending minor chord or pitch bend (400 Hz down to 80 Hz).
2. **Procedural Canvas Textures**:
   Render 16×16 or 32×32 pixel art textures with HTML5 Canvas, then upload them as `THREE.CanvasTexture` with `texture.magFilter = THREE.NearestFilter` and `texture.minFilter = THREE.NearestFilter`.
3. **Open-Source Asset Fetching**:
   If specific textures/sprites/models are needed (e.g. Minecraft textures or Kenney CC0 packs), execute a Bun fetch script (`scripts/fetch_assets.ts`) to download them from public GitHub raw repos.

---

## 6. The `yandex/` Store Submission Package

Every game repository MUST contain a `yandex/` folder with complete text and media assets ready for copy-pasting into the Developer Console:

```
yandex/
├── README.md               # Summary & step-by-step submission instructions
├── 01_general_info.md      # Fields for "Общее" tab
├── 02_description_ru.md    # Fields for "Русский" tab
├── 03_description_en.md    # Fields for "English" tab
├── icon_512.png            # PNG 512×512 px (Strict requirement)
├── cover_800x470.png       # PNG 800×470 px (Strict requirement)
├── screenshots/            # Gameplay screenshots
│   ├── desktop_1.png       # 1280×720 or 1920×1080 (Landscape)
│   ├── desktop_2.png
│   ├── desktop_3.png
│   ├── desktop_4.png
│   ├── mobile_1.png        # 720×1280 or 1080×1920 (Portrait)
│   └── mobile_2.png
└── video/                  # Promotional gameplay video
    ├── gameplay_horizontal.mp4 # 16:9 H.264 MP4 (~15-30s)
    └── gameplay_vertical.mp4   # 9:16 H.264 MP4 (~15-30s)
```

### Strict Character Limits & Field Checklist

#### 1. Общее (General)
- **Версия**: `0.0.0.1`
- **Поддерживаемые платформы**: Десктопные, Мобильные, Планшеты
- **Ориентация**: Любая (или Альбомная / Портретная)
- **Рекомендуемые языки перевода**: Русский (`ru`), Английский (`en`)
- **Управление языком**: Автоматически через Yandex Games SDK (`ysdk.environment.i18n.lang`).
- **Возрастной рейтинг**: `0+` (если нет насилия/азарта), `6+`, `12+`
- **Категории**: 1–2 категории (например: «Аркады», «Казуальные», «Головоломки»)
- **Теги**: 3–5 тегов
- **Ключевые слова**: через запятую (**СТРОГО ≤ 100 символов**)
- **Облачные сохранения**: Да / Нет
- **Отсроченная публикация**: Нет
- **Комментарий разработчика** (**СТРОГО ≤ 2048 символов**):
  Comprehensive moderation note detailing SDK v2 compliance: LoadingAPI.ready(), GameplayAPI.start/stop, 60s interstitial cooldown, rewarded video flow, i18n SDK language auto-detection, relative paths `./`, zero external network calls, audio mute on blur/pause.

#### 2. Описание и продвижение (RU & EN)
Each language tab must provide:
- **Название / Title**: **СТРОГО ≤ 50 символов**
- **Описание для SEO / SEO Description**: **СТРОГО ≤ 160 символов**
- **Короткое описание / Short Description**: **СТРОГО ≤ 70 символов**
- **Об игре / About**: **СТРОГО ≤ 1000 символов**
- **Как играть / How to Play**: **СТРОГО ≤ 1000 символов**

---

## 7. Automated Media Generation with ffmpeg

The agent MUST generate or record media assets autonomously using the included Python + Pillow + ffmpeg script:

```bash
python3 scripts/generate_yandex_media.py
```

### Script Execution Workflow
1. **Icon (`yandex/icon_512.png`)**:
   Creates a 512×512 image featuring the main character/item, high-contrast border, vignette, and title banner.
2. **Cover (`yandex/cover_800x470.png`)**:
   Creates an 800×470 promo banner with title, badges ("БЕСПЛАТНО", "БЕЗ РЕГИСТРАЦИИ", feature highlights), and stylized game elements.
3. **Screenshots (`yandex/screenshots/`)**:
   Renders 4 landscape screenshots (1280×720 or 1920×1080) and 2–4 portrait screenshots (720×1280 or 1080×1920) displaying distinct gameplay phases:
   - Core gameplay with HUD and active controls
   - Action / Combo / Explosion / Particle burst
   - Progression / Shop / Level select / Upgrades
   - Victory / Game Over / Leaderboard screen
4. **Gameplay Videos (`yandex/video/`)**:
   Simulates 150–300 frames of gameplay animation (particle motion, bouncing, score popups) into a temporary frame directory, then encodes them with `ffmpeg`:
   ```bash
   # Horizontal (16:9)
   ffmpeg -y -framerate 30 -i temp_frames/frame_%04d.png -c:v libx264 -pix_fmt yuv420p -crf 20 yandex/video/gameplay_horizontal.mp4

   # Vertical (9:16)
   ffmpeg -y -framerate 30 -i temp_vframes/vframe_%04d.png -c:v libx264 -pix_fmt yuv420p -crf 20 yandex/video/gameplay_vertical.mp4
   ```

---

## 8. Validation & Pre-Moderation Gate

Before finishing any task or submitting a game, run the validation script:
```bash
python3 scripts/validate_yandex_submission.py
```
This script checks:
- All character lengths in `yandex/*.md` against limits (50, 160, 70, 1000, 100, 2048)
- Dimensions of `icon_512.png` (exact 512×512) and `cover_800x470.png` (exact 800×470)
- Resolution and aspect ratios of screenshots
- Presence and format of `gameplay_horizontal.mp4` and `gameplay_vertical.mp4`
- Correct zip archive structure (`index.html` at root of zip).

---

## 9. Developer Console Guide: Leaderboards Setup & Deployment Checklist

### A. Пошаговая настройка Таблицы Лидеров (Leaderboards) в Консоли

Чтобы лидерборд работал и модерация не вернула замечание, его необходимо **вручную завести в Консоли разработчика**:

1. **Где создать**:
   - Откройте Консоль разработчика Яндекс Игр (`https://yandex.ru/dev/games/console/`).
   - Выберите вашу игру (или черновик).
   - В левом меню перейдите в раздел **«Лидерборды»** (Таблицы лидеров).
   - Нажмите кнопку **«Добавить лидерборд»**.

2. **Заполнение полей в Консоли**:
   - **Техническое название (ID)**:
     - **КРИТИЧНО**: должно **символ в символ** совпадать с константой в коде игры (например, `LEADERBOARD_ID = 'best'` или `HelixTowerLeaderboard`).
     - Если имя отличается хотя бы на одну букву или регистр (`Best` vs `best`), вызов `lb.setLeaderboardScore()` в коде молча проигнорирует отправку счета без ошибки.
   - **Название для игроков**:
     - Вкладка **Русский**: например, `Рекорд` или `Топ игроков`.
     - Вкладка **English**: например, `Best Score` или `Top Players`.
   - **Тип лидерборда**:
     - `Числовой` (Numeric) — для очков, уровней, золота.
     - `Время` (Time) — для таймеров прохождения (миллисекунды).
   - **Порядок сортировки**:
     - `По убыванию` (Descending) — для большинства игр (чем больше очков, тем выше место).
     - `По возрастанию` (Ascending) — для таймеров (чем меньше время, тем выше место).
   - **Разрешить игрокам скрывать имя**: включить (требование приватности).

3. **Технические нюансы в коде игры**:
   - Лидерборд Яндекс Игр сохраняет результаты **только для авторизованных игроков** (`player.isAuthorized() == true`).
   - Для гостей вызов `getLeaderboards()` возвращает ошибку или пустые данные — поэтому в коде отправка рекорда должна быть обернута в `try/catch`, а локальный рекорд должен дублироваться в `localStorage`.
   - Максимум: до 10 лидербордов на одну игру.

---

### B. Что обязательно учесть при Деплое на Яндекс Игры (Чеклист Модерации)

#### 1. Сборка архива игры (`*-yandex.zip`)
- **Главная ошибка модерации №1**: `index.html` **ОБЯЗАН** находиться в корне zip-архива!
  - ❌ Неправильно: `my-game.zip/dist/index.html` (модерация отклонит игру в первые секунды).
  - ✅ Правильно: `my-game.zip/index.html`, `my-game.zip/assets/...`.
  - Команда упаковки в `package.json`:
    ```bash
    rm -rf dist && vite build && cd dist && zip -rq ../game-yandex.zip .
    ```
- **Относительные пути**: в `vite.config.ts` строго `base: './'`. Яндекс крутит игру внутри iframe с подпапкой в S3 хранилище. Абсолютные пути (`/assets/...`, `/favicon.ico`) приведут к белому экрану и ошибкам 404.
- **Полная автономность**: 0 внешних запросов. Нельзя использовать CDN (unpkg, cdnjs, Google Fonts). Все шрифты и текстуры должны лежать внутри архива.
- **Размер архива**: до 100 МБ.

#### 2. Вкладка «Общее» в Консоли
- **Чекбокс «Игра использует облачные сохранения»**:
  - Если в коде вызывается `player.setData()` / `player.getData()` — **ОБЯЗАТЕЛЬНО включите этот чекбокс**! Без него облачный доступ будет заблокирован платформой.
- **Поддерживаемые платформы**:
  - Отметить: `Десктопные`, `Мобильные` (и `Планшеты`).
- **Ориентация**:
  - Если игра адаптивна — выбрать **«Любая»**.
  - Если игра строго альбомная — выбрать **«Альбомная»**.
- **Возрастной рейтинг**:
  - `0+` для казуальных/аркадных игр без реалистичного насилия и крови.
- **Языки игры**:
  - Добавить `Русский` и `Английский`.
  - Модератор в консоли переключит язык своего профиля Яндекса и проверит, что игра сама переключилась через `ysdk.environment.i18n.lang`.
- **Ключевые слова**:
  - Через запятую, строго **до 100 символов** с пробелами.
- **Комментарий разработчика** (до 2048 символов):
  - Обязательно вставьте готовый текст из `yandex/01_general_info.md` со списком реализованных требований (LoadingAPI, GameplayAPI, реклама 60с, i18n).

#### 3. Вкладка «Промо-материалы»
- **Иконка**: строго PNG 512×512 px (`yandex/icon_512.png`).
- **Обложка**: строго PNG 800×470 px (`yandex/cover_800x470.png`).
- **Скриншоты**:
  - Десктопные (альбомные, 1280×720 или 1920×1080) — минимум 2–4 штуки.
  - Мобильные (портретные, 720×1280 или 1080×1920) — минимум 1–2 штуки.
- **Видео**:
  - Горизонтальное видео геймплея 16:9 (`gameplay_horizontal.mp4`).
  - Вертикальное видео геймплея 9:16 (`gameplay_vertical.mp4`).

#### 4. Финальная проверка в черновике перед кнопкой «Отправить на модерацию»
- Откройте игру в тестовом окне черновика консоли Яндекса.
- **Autoplay звука**: игра **не должна** издавать звуки до первого клика или тапа пользователя по экрану (требование браузеров и модерации).
- **Полноэкранная реклама**: не должна открываться при первой загрузке игры. Первый показ разрешен только при перезапуске уровня или экране Game Over.
- **Пауза**: при показе рекламы игра и звуки должны полностью останавливаться.
- **Мобильный вид**: элементы управления и интерфейс не должны выходить за границы экрана смартфонов (включая safe area).
