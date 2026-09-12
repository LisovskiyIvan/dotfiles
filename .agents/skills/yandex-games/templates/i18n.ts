// templates/i18n.ts
// Bilingual localization system for Russian (ru) and English (en).
// Language automatically determined via Yandex Games SDK (Requirement 2.14).

export type Lang = 'ru' | 'en';

export interface DictStrings {
  title: string;
  score: string;
  best: string;
  gameOver: string;
  restart: string;
  reviveAd: string;
  howToPlay: string;
  [key: string]: string;
}

const DICTIONARY: Record<Lang, DictStrings> = {
  ru: {
    title: 'Название Игры',
    score: 'СЧЁТ: {n}',
    best: 'РЕКОРД: {n}',
    gameOver: 'ИГРА ОКОНЧЕНА',
    restart: 'ИГРАТЬ СНОВА',
    reviveAd: 'ВОЗРОДИТЬСЯ (РЕКЛАМА)',
    howToPlay: 'КАК ИГРАТЬ',
  },
  en: {
    title: 'Game Title',
    score: 'SCORE: {n}',
    best: 'BEST: {n}',
    gameOver: 'GAME OVER',
    restart: 'PLAY AGAIN',
    reviveAd: 'REVIVE (AD)',
    howToPlay: 'HOW TO PLAY',
  },
};

let currentLang: Lang = 'ru';

export function setLanguage(lang: Lang): void {
  currentLang = lang === 'en' ? 'en' : 'ru';
  document.documentElement.lang = currentLang;
}

export function getLanguage(): Lang {
  return currentLang;
}

export function t(key: string, params?: Record<string, string | number>): string {
  let text = DICTIONARY[currentLang]?.[key] ?? DICTIONARY.ru[key] ?? key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      text = text.replaceAll(`{${k}}`, String(v));
    }
  }
  return text;
}

/**
 * Automatically updates DOM elements with data-i18n attributes.
 * Example: <span data-i18n="gameOver"></span>
 */
export function applyI18nToDOM(root: ParentNode = document): void {
  root.querySelectorAll<HTMLElement>('[data-i18n]').forEach((el) => {
    const key = el.dataset.i18n;
    if (key) el.textContent = t(key);
  });
  root.querySelectorAll<HTMLElement>('[data-i18n-html]').forEach((el) => {
    const key = el.dataset.i18nHtml;
    if (key) el.innerHTML = t(key);
  });
  root.querySelectorAll<HTMLElement>('[data-i18n-title]').forEach((el) => {
    const key = el.dataset.i18nTitle;
    if (key) el.title = t(key);
  });
}
