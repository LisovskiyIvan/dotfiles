// templates/yandex.ts
// Robust Yandex Games SDK v2 wrapper with complete standalone/local dev mocks.

export interface YandexSDK {
  environment: {
    i18n: {
      lang: string;
    };
  };
  adv: {
    showFullscreenAdv: (opts: {
      callbacks: {
        onClose?: (wasShown: boolean) => void;
        onError?: (err: unknown) => void;
      };
    }) => void;
    showRewardedVideo: (opts: {
      callbacks: {
        onOpen?: () => void;
        onRewarded?: () => void;
        onClose?: () => void;
        onError?: (err: unknown) => void;
      };
    }) => void;
  };
  features: {
    LoadingAPI?: {
      ready: () => void;
    };
    GameplayAPI?: {
      start: () => void;
      stop: () => void;
    };
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

declare global {
  interface Window {
    YaGames?: {
      init: () => Promise<YandexSDK>;
    };
  }
}

export class YandexClient {
  public sdk: YandexSDK | null = null;
  public player: YandexPlayer | null = null;
  public isPlatform = false;
  public lang: 'ru' | 'en' = 'ru';
  private lastInterstitialAt = 0;
  private readonly INTERSTITIAL_COOLDOWN_MS = 60_000;

  /**
   * Initializes SDK.
   * @param onPause Called when platform requests pause (e.g. ad opens or tab unfocused) -> MUTE AUDIO & PAUSE GAME
   * @param onResume Called when platform resumes -> UNMUTE AUDIO & RESUME GAME
   */
  public async init({ onPause, onResume }: { onPause?: () => void; onResume?: () => void } = {}): Promise<void> {
    // Check manual override query param for testing: ?lang=ru or ?lang=en
    const urlLang = new URLSearchParams(window.location.search).get('lang');
    if (urlLang) {
      this.lang = urlLang.toLowerCase().startsWith('ru') ? 'ru' : 'en';
    }

    const hasYaGames = await this.waitForYaGames(2000);
    if (hasYaGames && window.YaGames) {
      try {
        this.sdk = await window.YaGames.init();
        this.isPlatform = this.detectPlatform(this.sdk);

        this.sdk.on?.('game_api_pause', () => onPause?.());
        this.sdk.on?.('game_api_resume', () => onResume?.());

        // CRITICAL: always touch sdk.environment.i18n.lang, even when ?lang override is present.
        // The draft debug panel lights the 文 ("I18N is used", req. 2.14) indicator by the FACT
        // of property access on startup. Early return on ?lang (without this read) leaves it red.
        // Correct order: read SDK first, then let ?lang override the RESULT (priority unchanged).
        const sdkLang = this.sdk.environment?.i18n?.lang;
        if (urlLang) {
          this.lang = urlLang.toLowerCase().startsWith('ru') ? 'ru' : 'en';
        } else if (sdkLang) {
          this.lang = sdkLang.toLowerCase().startsWith('ru') ? 'ru' : 'en';
        }

        try {
          this.player = await this.sdk.getPlayer({ scopes: false });
        } catch {
          // Guest player mode: cloud saves fallback to localStorage
        }
      } catch (err) {
        console.info('[YandexSDK] Running in standalone fallback mode:', err);
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
        if (window.YaGames) return resolve(true);
        if (Date.now() - t0 > timeoutMs) return resolve(false);
        setTimeout(check, 100);
      };
      check();
    });
  }

  private detectPlatform(sdk: YandexSDK): boolean {
    try {
      const ao = (window.location as any).ancestorOrigins;
      if (ao && ao.length > 0) return [...ao].some((o: string) => /(^|\.)yandex\./.test(o));
      if (document.referrer) return /(^|\.)yandex\./.test(new URL(document.referrer).hostname);
    } catch (_) {}
    return !!(sdk as any).deviceInfo?.type;
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

  /**
   * Binds tab-switch/minimize (focus loss) to the same pause/resume handlers
   * as platform events. Call once from game bootstrap AFTER init():
   *
   *   yandex.bindLifecycleHandlers({ onPause, onResume });
   *
   * All sources — game_api_pause/resume, visibilitychange, blur/focus —
   * funnel into one pause/resume pair owned by the game.
   */
  public bindLifecycleHandlers({ onPause, onResume }: { onPause?: () => void; onResume?: () => void } = {}): void {
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) onPause?.();
      else onResume?.();
    });
    window.addEventListener('blur', () => onPause?.());
    window.addEventListener('focus', () => onResume?.());
  }

  // --- Interstitial Ads (60s Cooldown, Natural Pauses Only) ---
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

  // --- Rewarded Video (User-Initiated, Safe Callback) ---
  public showRewardedVideo(onReward: () => void, onClose?: (rewarded: boolean) => void): void {
    if (!this.isPlatform) {
      console.info('[YandexSDK] Standalone mock: Rewarded video granted');
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

  /**
   * Rewarded video WITH explicit user consent.
   * Shows a confirm dialog (question/ok/cancel strings come from the game's
   * i18n dict so the offer is always in the player's language) and calls
   * showRewardedVideo() only when the player accepts.
   * NEVER call showRewardedVideo() directly from game-over/auto flows.
   */
  public confirmAndShowRewarded(
    strings: { question: string; ok?: string; cancel?: string },
    onReward: () => void,
    onClose?: (rewarded: boolean) => void,
  ): void {
    const accepted = window.confirm(strings.question);
    if (!accepted) {
      onClose?.(false);
      return;
    }
    this.showRewardedVideo(onReward, onClose);
  }

  // --- Cloud Saves with localStorage Fallback ---
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

  // --- Leaderboards ---
  public async submitScore(leaderboardName: string, score: number): Promise<void> {
    if (!this.player || !this.isPlatform) return;
    try {
      const lb = await this.sdk?.getLeaderboards();
      await lb?.setLeaderboardScore(leaderboardName, score);
    } catch (_) {}
  }
}

export const yandex = new YandexClient();
