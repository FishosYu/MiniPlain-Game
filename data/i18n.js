(function () {
  const DEFAULT_LOCALE = 'zh-CN';
  const STORAGE_KEY = 'stonia.locale';
  const dictionaries = window.STONIA_LOCALES || {};

  function readStoredLocale() {
    try {
      return localStorage.getItem(STORAGE_KEY);
    } catch (err) {
      return null;
    }
  }

  const storedLocale = readStoredLocale();
  let currentLocale = dictionaries[storedLocale] ? storedLocale : DEFAULT_LOCALE;

  function getPath(source, key) {
    if (!source || !key) return undefined;
    return String(key).split('.').reduce((value, part) => {
      if (value && Object.prototype.hasOwnProperty.call(value, part)) return value[part];
      return undefined;
    }, source);
  }

  function format(value, params) {
    if (typeof value !== 'string') return value;
    return value.replace(/\{(\w+)\}/g, (_, name) => (
      Object.prototype.hasOwnProperty.call(params || {}, name) ? params[name] : `{${name}}`
    ));
  }

  function escapeHtml(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
  }

  function assetRoot() {
    const script = document.currentScript || document.querySelector('script[src$="data/i18n.js"]');
    if (!script?.src) return '';
    return new URL('../', script.src).href;
  }

  function iconInfo(kind, id) {
    if (kind === 'item') {
      const item = (window.MINIPLAIN_ITEMS || {})[id] || {};
      return {
        src: item.icon || `assets/2D/items/${id}.png`,
        alt: item.name || id,
      };
    }
    if (kind === 'entity') {
      return {
        src: `assets/2D/entities/${id}.png`,
        alt: id.replaceAll('_', ' '),
      };
    }
    if (kind === 'terrain') {
      return {
        src: `assets/2D/tiles/terrain/${id}.png`,
        alt: id.replaceAll('-', ' '),
      };
    }
    return null;
  }

  function richText(value) {
    return String(value ?? '').replace(/\{icon:(item|entity|terrain):([a-z0-9_-]+)\}/g, '\0$1:$2\0')
      .split('\0')
      .map(part => {
        const match = /^(item|entity|terrain):([a-z0-9_-]+)$/.exec(part);
        if (!match) return escapeHtml(part);
        const icon = iconInfo(match[1], match[2]);
        if (!icon) return '';
        return `<img class="inline-icon inline-icon-${escapeHtml(match[1])}" src="${escapeHtml(assetRoot() + icon.src)}" alt="${escapeHtml(icon.alt)}" loading="lazy">`;
      })
      .join('');
  }

  function lookup(key) {
    const active = dictionaries[currentLocale] || {};
    const fallback = dictionaries[DEFAULT_LOCALE] || {};
    return getPath(active, key) ?? getPath(fallback, key);
  }

  function t(key, params = {}, fallback = '') {
    const value = lookup(key);
    if (value === undefined || Array.isArray(value) || typeof value === 'object') {
      return format(fallback || key, params);
    }
    return format(value, params);
  }

  function list(key, fallback = []) {
    const value = lookup(key);
    return Array.isArray(value) ? value : fallback;
  }

  function setLocale(locale) {
    if (!dictionaries[locale]) return false;
    currentLocale = locale;
    try {
      localStorage.setItem(STORAGE_KEY, locale);
    } catch (err) {
      // Ignore storage failures; the runtime locale is still updated.
    }
    document.documentElement.lang = t('meta.lang', {}, locale);
    return true;
  }

  function nextLocale() {
    const locales = Object.keys(dictionaries);
    const currentIndex = locales.indexOf(currentLocale);
    return locales[(currentIndex + 1) % locales.length] || DEFAULT_LOCALE;
  }

  function bindLocaleToggle(root = document) {
    root.querySelectorAll('[data-locale-toggle]').forEach(button => {
      button.textContent = t('language.toggleLabel', {}, '中/En');
      if (button.dataset.localeToggleBound === 'true') return;
      button.dataset.localeToggleBound = 'true';
      button.addEventListener('click', () => {
        const locale = nextLocale();
        if (!setLocale(locale)) return;
        applyStatic();
        document.dispatchEvent(new CustomEvent('stonia:localechange', {
          detail: { locale },
        }));
      });
    });
  }

  function itemData(id) {
    return (window.MINIPLAIN_ITEMS || {})[id] || {};
  }

  function itemName(id) {
    const fallback = itemData(id).name || id;
    return t(`items.${id}.name`, {}, fallback);
  }

  function itemText(id, field, fallback = '') {
    return t(`items.${id}.texts.${field}`, {}, fallback);
  }

  function itemTextList(id, field, fallback = []) {
    return list(`items.${id}.texts.${field}`, fallback);
  }

  function categoryName(category) {
    return t(`categories.${category}`, {}, category);
  }

  function applyStatic(root = document) {
    document.documentElement.lang = t('meta.lang', {}, currentLocale);
    root.querySelectorAll('[data-i18n]').forEach(el => {
      el.innerHTML = richText(t(el.dataset.i18n, {}, el.textContent));
    });
    root.querySelectorAll('[data-i18n-html]').forEach(el => {
      el.innerHTML = t(el.dataset.i18nHtml, {}, el.innerHTML);
    });
    root.querySelectorAll('[data-i18n-title]').forEach(el => {
      el.title = t(el.dataset.i18nTitle, {}, el.title);
    });
    root.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
      el.placeholder = t(el.dataset.i18nPlaceholder, {}, el.placeholder);
    });
    root.querySelectorAll('[data-i18n-aria-label]').forEach(el => {
      el.setAttribute('aria-label', t(el.dataset.i18nAriaLabel, {}, el.getAttribute('aria-label') || ''));
    });
    root.querySelectorAll('[data-i18n-alt]').forEach(el => {
      el.alt = t(el.dataset.i18nAlt, {}, el.alt || '');
    });
    bindLocaleToggle(root);
  }

  window.STONIA_I18N = {
    DEFAULT_LOCALE,
    get locale() {
      return currentLocale;
    },
    t,
    list,
    setLocale,
    nextLocale,
    bindLocaleToggle,
    itemName,
    itemText,
    itemTextList,
    categoryName,
    richText,
    applyStatic,
  };
})();
