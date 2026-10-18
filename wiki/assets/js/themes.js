/*
  Theme switcher shared by the hub and all add-on wikis.
  Themes: bento (default) · docs
    - hub / 404 / hwinfo-thermalguard (site.css pages): themes.css
    - all other add-on wikis: addon-themes.css (docs = the page's original sidebar look)
  The choice is stored in localStorage (same key everywhere, so it follows you across pages)
  and can be forced with ?theme=docs. Loaded synchronously in <head> to avoid a flash.
  Without JavaScript the pages render in their original look.
*/
(() => {
  const THEMES = [
    ['bento', 'Bento'],
    ['docs', 'Docs'],
  ];
  const DEFAULT = 'bento';
  const KEY = 'pf-wiki-theme';
  const ids = THEMES.map((t) => t[0]);
  const root = document.documentElement;

  const read = () => {
    try {
      const q = new URLSearchParams(location.search).get('theme');
      if (ids.includes(q)) return q;
      const s = localStorage.getItem(KEY);
      if (ids.includes(s)) return s;
    } catch (e) { /* storage blocked */ }
    return DEFAULT;
  };

  const apply = (theme, persist) => {
    root.setAttribute('data-theme', theme);
    document.querySelectorAll('[data-theme-btn]').forEach((b) => {
      b.setAttribute('aria-pressed', String(b.dataset.themeBtn === theme));
    });
    if (persist) {
      try { localStorage.setItem(KEY, theme); } catch (e) { /* ignore */ }
    }
  };

  const fill = (box) => {
    box.setAttribute('role', 'group');
    box.setAttribute('aria-label', 'Design wählen');
    box.innerHTML = THEMES.map(([id, label]) =>
      '<button type="button" data-theme-btn="' + id + '" aria-pressed="false">' + label + '</button>'
    ).join('');
    box.addEventListener('click', (e) => {
      const b = e.target.closest('[data-theme-btn]');
      if (b) apply(b.dataset.themeBtn, true);
    });
  };

  apply(read(), false);

  document.addEventListener('DOMContentLoaded', () => {
    let switchers = document.querySelectorAll('[data-theme-switch]');

    // Add-on wikis have no placeholder: put the switcher under the sidebar brand, else float it.
    if (!switchers.length) {
      const box = document.createElement('div');
      box.setAttribute('data-theme-switch', '');
      const brand = document.querySelector('aside.sidebar .brand');
      if (brand) {
        box.className = 'theme-switch theme-switch--sidebar';
        brand.after(box);
      } else {
        box.className = 'theme-switch theme-switch--floating';
        document.body.appendChild(box);
      }
      switchers = [box];
    }
    switchers.forEach(fill);

    // Hub only: sidebar for the "docs" theme, built from the catalog.
    const groups = document.querySelectorAll('[data-cat-group]');
    const topbar = document.querySelector('.topbar');
    if (groups.length && topbar) {
      const nav = document.createElement('nav');
      nav.className = 'side-nav';
      nav.setAttribute('aria-label', 'Add-ons');
      nav.innerHTML = Array.from(groups).map((g) => {
        const links = Array.from(g.querySelectorAll('[data-search-card]')).map((c) =>
          '<a data-side-link href="' + c.getAttribute('href') + '" style="--a:' + (c.style.getPropertyValue('--a') || '#34d399') + '"><i></i>' +
          c.querySelector('h3').textContent + '</a>'
        ).join('');
        return '<div class="side-title">' + g.dataset.catGroup + '</div>' + links;
      }).join('');
      topbar.after(nav);
    }

    apply(read(), false);
  });
})();
