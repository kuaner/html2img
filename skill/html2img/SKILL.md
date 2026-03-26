---
name: html2img
description: >
  Render local HTML files to PNG images using the html2img CLI tool. Use this skill whenever the user
  wants to convert an HTML file to an image, take a screenshot of an HTML file, export HTML as PNG,
  render an HTML template to an image, or when you have just generated or modified an HTML file that
  the user might want to see as a rendered image. Also trigger when the user mentions "screenshot HTML",
  "render HTML", "HTML to image", "HTML to PNG", "export as image", or when there's an HTML file in the
  working directory and the user wants to preview or share it visually.
---

# html2img

Render a local HTML file to PNG using the `html2img` CLI tool.

## How it works

`html2img` uses macOS WebKit (offscreen `WKWebView`), exports via PDF, then encodes PNG. Supports CSS, JavaScript, Canvas, Chart.js.

## Usage

```bash
scripts/html2img <input.html> <output.png> [width]
```

That's it. No flags needed. The tool automatically:
1. Measures content height
2. If height ≤ 6000 CSS px → renders single image
3. If height > 6000 and HTML has `[data-html2img-section]` → auto sections mode
4. If height > 6000 and no sections → auto segment-height mode (6000px per segment)

Output is always JSON to stdout:
```json
{"mode":"sections","height":9709,"output_px":19418,"count":11,"files":["output-1.png","output-2.png",...]}
```

### Explicit modes (optional)

Only use these when you need to override auto behavior:

```bash
# Force sections mode
scripts/html2img <input.html> <output.png> [width] --sections

# Force segment-height mode with custom height
scripts/html2img <input.html> <output.png> [width] --segment-height 8000

# Height check only (debugging)
scripts/html2img <input.html> dummy.png [width] --height
```

`--sections` and `--segment-height` are mutually exclusive.

### JSON output format

| Mode | Fields |
|------|--------|
| `single` | `mode`, `height`, `output_px`, `files` |
| `sections` | `mode`, `height`, `output_px`, `count`, `files` |
| `segmented` | `mode`, `height`, `output_px`, `segment_height`, `count`, `files` |
| height check | `height`, `output_px`, `mode`, `recommendation` |

## Key constraints

- **Local files only** — input must be a local `.html` path; remote URLs are not supported.
- **External resources** — CSS/JS/images/fonts may be local or CDN; relative paths and remote URLs are allowed.
- **Output is PNG**.
- **macOS only** — macOS 13+ and WebKit.
- **Default width** — 800px if not specified.

## Section HTML (for LLMs generating reports)

**Convention:** wrap each block that should become its own PNG in an element with `data-html2img-section`. Use document order; each match becomes one output image sized to that element's layout box.

```html
<body>
  <section data-html2img-section class="report-block">
    <h2>Overview</h2>
    ...
  </section>

  <section data-html2img-section class="report-block">
    <h2>Charts</h2>
    ...
  </section>
</body>
```

**Rules for generators:**

1. One logical "slide" or "card group" per `[data-html2img-section]` wrapper — do not split a single chart/table across two sections.
2. Prefer block-level wrappers (`section`, `div`) that contain the full visual unit (heading + body + footnotes in that unit).
3. Do not nest `[data-html2img-section]` inside another `[data-html2img-section]` (outer box only).
4. Avoid putting the attribute on `position: sticky` roots only; wrap inner content so the export box is stable.
5. After generating HTML, just run `html2img …` — auto mode will detect sections and use them.

## Common troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Image blank or empty | JS/fonts not finished; page may need more time to load |
| Styles missing | Linked CSS paths wrong relative to the HTML file |
| Charts missing | Chart.js or network blocked |
| Long page truncated / blank at bottom | Auto mode should handle this; if not, add `[data-html2img-section]` wrappers |
| Wrong slice boundaries | Adjust `[data-html2img-section]` grouping; avoid splitting components |
| Hero area huge with black space | Using `vh`/`vw` units — use fixed `px` or `rem` instead |
| Background image not visible | CSS `background-image` may not resolve in some cases; prefer `<img>` tag |
| Absolute overlay not rendering | Not an html2img issue — `position: absolute` + `z-index` works; check containing block has explicit dimensions |

## CSS guidelines

- **Safe**: `px`, `rem`, `em`, `%`, `clamp()`, `position: absolute`, `z-index`, `object-fit`, flexbox, grid
- **Avoid**: `vh`, `vw`, `vmin`, `vmax` — viewport units are unreliable in offscreen rendering
- **Hero backgrounds**: use `<img>` tag with `position: absolute` + `inset: 0` + `object-fit: cover`, not CSS `background-image` on a pseudo-element
- **Fixed heights preferred**: use `px` or `rem` for section heights, never `vh`
