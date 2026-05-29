# Contributing

## Add a New Project

### 1. Create the folder

```text
pages/
└── new-project/
    └── index.html
```

### 2. Add a card to the root `index.html`

Insert a new card inside the `<div class="grid">` block:

```html
<a class="card" data-search-card href="./new-project/">
  <div class="meta"><span class="badge">Category</span></div>
  <h3>Project Name</h3>
  <p>Short description of the project.</p>
  <span class="card-link">./new-project/ →</span>
</a>
```

### 3. Add a nav link — optional

In `index.html`, `404.html`, and all sub-pages, add this inside the `<nav>` block:

```html
<a href="./new-project/">Project Name</a>
```

### 4. Add a shortlink to `_redirects` — optional

```text
/shortcut    /new-project/    301
```

### 5. Update the sitemap

Add a new entry to `sitemap.xml`:

```xml
<url><loc>https://pol4rfuchs.github.io/ha-apps/new-project/</loc></url>
```

### 6. Commit and push

```powershell
git add .
git commit -m "pages: add new-project"
git push origin pages
```

---

## Asset Rules

| Situation | Path |
|---|---|
| Hub CSS/JS for root pages | `./assets/css/site.css` |
| Sub-page one level deep | `../assets/css/site.css` |
| Sub-page two levels deep | `../../assets/css/site.css` |
| Project-specific assets | inside the project’s own folder, e.g. `./assets/logo.png` |
| `404.html` | always `/assets/css/site.css` absolute path |

Self-contained projects with their own CSS/JS, such as GPU Tools AIO, do not need the hub assets.
