---
name: yandex-games
description: >-
  Build browser games for Yandex Games (Яндекс Игры). Enforces Bun, latest Vite/Three.js/Rapier,
  SDK v2 wired in <head> (LoadingAPI/GameplayAPI), language strictly via ysdk.environment.i18n.lang,
  progress/levels/settings saved via ysdk.getPlayer, sounds paused on focus loss and ads,
  logical interstitials with 60s cooldown, rewarded ads only after asking the user.
---

# Yandex Games (Яндекс Игры) — Game Development Skill

Guide and blueprints for the **game itself**: SDK integration, language, saves, audio lifecycle, and ads.
Store-facing assets (texts, icon, cover, screenshots, videos, `yandex/` package) live in the **`yandex-assets`** skill.

---

## 1. Core Principles & Philosophy

1. **SDK Is Wired In**: `/sdk.js` is declared in `<head>` before the game bundle. `YaGames.init()`, `LoadingAPI.ready()`, and `GameplayAPI.start()/stop()` are called at the right lifecycle moments (§3).
2. **Zero External Requests**: The final build is 100% self-contained. No external CDNs, Google Fonts, remote scripts, or tracking pixels. Everything (fonts, sounds) resides inside the uploaded zip. The only allowed external script is the platform's `/sdk.js`.
3. **Relative Asset Paths**: Vite must use `base: './'`. Absolute paths (`/assets/...`) fail because Yandex hosts game iframes from arbitrary S3/bucket subfolders.
4. **Graceful Standalone Mode**: The game runs identically in local dev (`bun run dev`) and in the Yandex iframe. When the SDK is absent or times out, fall back to mocks and `localStorage` without errors or blocking gameplay.
5. **Language From SDK**: Language is driven **only** by `ysdk.environment.i18n.lang` (`ru`/`en`), with `?lang=ru|en` override for testing (§4).
6. **Saves Via Player**: Progress, unlocked levels, and settings persist through `ysdk.getPlayer()` (`getData`/`setData`) with `localStorage` fallback (§5).
7. **Responsible Audio & Ads**: Sounds pause on tab switch/minimize (focus loss) and during any ad (§6). Interstitials appear only at natural pauses with a 60-second cooldown; rewarded videos are **always** offered to the user first and never autoplay (§7).

---

## 2. Tech Stack & Dependencies

All projects must use **Bun** and latest stable versions:

| Category | Recommended Stack | Key Packages |
| :--- | :--- | :--- |
| **Package Manager** | Bun | `bun install`, `bun run dev`, `bun run build`, `bun run pack` |
| **Bundler** | Vite (latest v8+) | `vite`, `typescript` |
| **2D Games** | Canvas 2D / DOM / Pixi | `@dimforge/rapier2d-compat` (for 2D physics) |
| **3D Games** | Three.js + Rapier | `three`, `@types/three`, `@dimforge/rapier3d-compat` (or 2D compat for 2.5D) |
| **Audio** | Procedural Web Audio API | Zero external audio asset size; 100% offline (§6) |
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
    "pack": "rm -rf dist && vite build && cd dist && rm -f ../game-yandex.zip && zip -rq ../game-yandex.zip ."
  }
}
```
> **IMPORTANT**: In the generated zip archive, `index.html` must be in the archive's root directory, NOT inside a nested `dist/` folder.

---

## 3. Yandex Games SDK v2 Integration (SDK подключён)

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

Full template in `templates/yandex.ts`. Key contract:

- `init({ onPause, onResume })` — waits for `window.YaGames` (2s timeout → standalone mock), calls `YaGames.init()`, subscribes to `game_api_pause` / `game_api_resume`, resolves the player via `getPlayer({ scopes: false })`.
- `loadingReady()` — call once after assets are loaded and the first frame can render (`LoadingAPI.ready()`).
- `gameplayStart()` / `gameplayStop()` — wrap every active-play segment: start on level/match begin, stop on pause, Game Over, and **before any ad** (§7).
- `detectPlatform()` — ancestorOrigins / referrer / `deviceInfo` check; ads and cloud saves engage only on platform.
- Focus-loss wiring (in game bootstrap, see §6): `visibilitychange` + `blur`/`focus` call the same `onPause`/`onResume` handlers as platform events.

---

## 4. Language — Strictly `ysdk.environment.i18n.lang`

Moderation Requirement 2.14: language adapts automatically to the user's platform locale.

1. On `init()`, read `sdk.environment.i18n.lang`; normalize to `ru` if it starts with `ru`, otherwise `en`.
2. `?lang=ru` / `?lang=en` URL params **override** the SDK value (for moderation testing and local dev).
3. Without SDK: fall back to `navigator.language`, default `ru`.
4. Set `document.documentElement.lang` and re-render all strings; support `data-i18n` DOM rebinding.

Dictionary pattern in `templates/i18n.ts` (RU+EN dictionaries, `t(key, params)`, `setLanguage`/`applyI18nToDOM`).

---

## 5. Saves — Progress, Levels, Settings via `ysdk.getPlayer()`

All persistent state (level progress, unlocked content, user settings, best score) goes through the player object:

```ts
// Load: cloud first (platform + authorized), localStorage fallback/merge
const progress = await yandex.loadData('progress_v1', { level: 1, unlocked: [1], sound: true });
// Save: localStorage immediately, cloud flush when on platform
await yandex.saveData('progress_v1', progress);
```

Rules:

- One namespaced key per domain (`progress_v1`, `settings_v1`), never unbounded key growth.
- Always write `localStorage` synchronously first — the game must survive guest mode and offline.
- `player.setData()` / `getData()` only when `isPlatform && player`; wrap in `try/catch` (guests throw).
- If the game calls `setData`/`getData`, the **«Игра использует облачные сохранения»** checkbox in the console MUST be enabled (see §9).

---

## 6. Audio — Pause on Focus Loss and Ads

Procedural Web Audio synth template in `templates/sound.ts` (jump, score, explode, click, victory, defeat — zero audio files).

Mandatory lifecycle:

1. **No autoplay**: no sound before the first user gesture (click/tap). Create/resume `AudioContext` lazily inside the gesture handler.
2. **Focus loss pauses everything**: subscribe to `document.visibilitychange` (`document.hidden`), `window blur`/`focus`, and platform `game_api_pause`/`resume` — all route into one `pauseAudio()` / `resumeAudio()` pair (`AudioContext.suspend()` / `resume()`, stop loops, mute SFX via `sound.setMute(true/false)` or suspend).
3. **Ads mute the game**: `showFullscreenAdv` / `showRewardedVideo` pause audio on open and resume on close/error — handled inside the wrapper's ad methods, never left to call sites.
4. Persist the user's mute choice in settings (`settings_v1`, §5).

---

## 7. Advertising — Logical Places, Rewarded Only With Consent

Template methods: `showFullscreenAdv(onClose)` and `showRewardedVideo(onReward, onClose)` in `templates/yandex.ts`.

### Interstitial (`showFullscreenAdv`)

- Show **only** at natural pauses: Game Over screen, level restart, return to menu, victory screen. **NEVER** on first load, mid-gameplay, or during active input.
- **60-second cooldown** enforced in the wrapper (`INTERSTITIAL_COOLDOWN_MS`); calls inside cooldown silently report `wasShown=false`.
- No-op off-platform (reports `false`) so local dev flow never blocks.
- Wrapper calls `gameplayStop()` before showing and `gameplayStart()` on close/error; audio pauses/resumes with it (§6).

### Rewarded (`showRewardedVideo`)

- **ALWAYS ask the user first**: rewarded ads trigger exclusively from an explicit player action (button «Возродиться», «Подсказка», «x2 награда») preceded by a clear offer — a dialog/screen stating what the player watches and what they get, with visible Decline/Close. No auto-showing after Game Over, no disguised buttons.
- Grant the reward **exclusively** in the `onRewarded` callback — never on open or close.
- Off-platform mock grants the reward immediately so the flow is testable locally.

---

## 8. Validation & Pre-Moderation Gate (Game)

Before finishing any task, verify the game side:

```bash
python3 scripts/validate_yandex_game.py
```

Checks:

- `/sdk.js` declared in `<head>` of `index.html` before the bundle
- `vite.config.ts` uses `base: './'`
- No external URLs in built output (except `/sdk.js`)
- `YaGames.init`, `LoadingAPI.ready`, `GameplayAPI.start/stop`, `environment.i18n.lang`, `getPlayer`/`setData`/`getData` call sites present
- Zip archive structure (`index.html` at root of zip)

Media/text checks (`yandex/` sizes, 16:9 screenshots, videos, char limits) belong to the `yandex-assets` skill: `validate_yandex_submission.py`.

---

## 9. Developer Console Guide: Leaderboards & Deployment Checklist

### A. Leaderboards Setup (manual console step)

1. Open the dev console (`https://yandex.ru/dev/games/console/`) → your game → **«Лидерборды»** → **«Добавить лидерборд»**.
2. **Technical ID must match the code constant byte-for-byte** (e.g. `LEADERBOARD_ID = 'best'`; `Best` vs `best` silently drops scores).
3. Player-facing names: RU (`Рекорд`) + EN (`Best Score`); type `Числовой` (scores) or `Время` (timers); sort `По убыванию` (scores) / `По возрастанию` (timers); allow hiding names.
4. Code facts: scores persist **only for authorized players** — wrap `submitScore` in `try/catch` and mirror the local best in `localStorage`. Max 10 leaderboards per game.

### B. Game Deployment Checklist (moderation)

#### 1. Build archive (`*-yandex.zip`)

- `index.html` **MUST** be at the zip root (`game.zip/index.html`, never `game.zip/dist/index.html`).
- `base: './'` — no absolute `/assets/...` paths.
- Zero external requests; size ≤ 100 MB.

#### 2. «Общее» tab (game-relevant)

- **«Игра использует облачные сохранения»**: enable iff the code calls `player.setData()` / `player.getData()`.
- Platforms: `Десктопные`, `Мобильные` (+ `Планшеты`); orientation `Любая` for adaptive.
- Languages: `Русский` + `Английский` (moderator flips their Yandex profile language and expects the game to follow via `ysdk.environment.i18n.lang`).
- Dev comment (≤ 2048): paste the SDK-compliance text (LoadingAPI, GameplayAPI, 60s ads, i18n) — full template lives in the `yandex-assets` skill.

#### 3. Draft testing (game-relevant)

- No sound before first click/tap (Autoplay Policy).
- No fullscreen ad on first load; first ad only on restart/Game Over.
- During any ad: gameplay and audio fully stop.
- Mobile layout: controls and UI stay inside the viewport incl. safe area.
- Promo materials (icon/cover/screenshots/videos/texts): see the **`yandex-assets`** skill.
