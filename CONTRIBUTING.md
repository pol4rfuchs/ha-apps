# Neues Projekt hinzufügen

## 1. Ordner anlegen

```
pages/
└── neues-projekt/
    └── index.html
```

## 2. Card in `index.html` (Root) ergänzen

Im `<div class="grid">` Block eine neue Card einfügen:

```html
<a class="card" data-search-card href="./neues-projekt/">
  <div class="meta"><span class="badge">Kategorie</span></div>
  <h3>Projektname</h3>
  <p>Kurze Beschreibung des Projekts.</p>
  <span class="card-link">./neues-projekt/ →</span>
</a>
```

## 3. Nav-Link ergänzen (optional)

In `index.html`, `404.html` und allen Sub-Pages im `<nav>`-Block:

```html
<a href="./neues-projekt/">Projektname</a>
```

## 4. Shortlink in `_redirects` ergänzen (optional)

```
/kürzel    /neues-projekt/    301
```

## 5. Sitemap ergänzen

In `sitemap.xml` neue Einträge:

```xml
<url><loc>https://pol4rfuchs.codeberg.page/neues-projekt/</loc></url>
```

## 6. Committen & pushen

```powershell
git add .
git commit -m "pages: add neues-projekt"
git push origin pages
```

---

## Asset-Regeln

| Situation | Pfad |
|---|---|
| Hub-CSS/JS (Root-Seiten) | `./assets/css/site.css` |
| Sub-Page eine Ebene tief | `../assets/css/site.css` |
| Sub-Page zwei Ebenen tief | `../../assets/css/site.css` |
| Projekt-eigene Assets | im eigenen Ordner, z.B. `./assets/logo.png` |
| `404.html` | immer `/assets/css/site.css` (absolut) |

Selbst enthaltene Projekte (eigenes CSS/JS wie GPU Tools AIO) brauchen keine Hub-Assets.
