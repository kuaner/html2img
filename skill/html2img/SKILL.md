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
scripts/html2img <input.html> <output.png> [width] --segment-height <height>
scripts/html2img <input.html> <output.png> [width] --sections
```

Default width is 800px.

Single-image limit note:
- Single-image mode has a practical cap around **28800 output px** (about **14400 CSS px/pt** at Retina 2x).
- Prefer staying under **12000 output px** for safer single-image export.
- If a page may exceed single-image limits, first ask/guide the LLM to add `data-html2img-section` wrappers and use `--sections`.
- Only when HTML cannot be modified, fall back to fixed-height slicing with `--segment-height`.

## Key constraints

- **Local files only** — input must be a local `.html` path; remote URLs are not supported.
- **External resources** — CSS/JS/images/fonts may be local or CDN; relative paths and remote URLs are allowed.
- **Output is PNG**.
- **macOS only** — macOS 13+ and WebKit.
- **Single-image height limit** — practical hard cap is around **28800 output px** (about **14400 CSS px/pt** at Retina 2x). Above this, single-image mode can truncate or turn blank near the bottom.
- **Recommended safe range** — keep single-image outputs under **12000 output px** when possible.
- **Very long pages** — avoid a single full-page capture; use `--segment-height` or `--sections`.

## Workflow

When asked to render HTML to images:

1. **Locate the HTML file**.
2. **Choose output path** — if unspecified, default `report.html` → `report.png` next to the file.
3. **Choose width** — default 800 unless the user asks otherwise.
4. **Choose mode (important)**:
   - **Single image (default)**: use no extra flag for normal pages.
   - **Section images (`--sections`)**: if content may be too long, prefer asking the LLM to add `[data-html2img-section]` wrappers, then use this mode.
   - **Fixed-height strips (`--segment-height`)**: fallback only when you cannot modify HTML to add section wrappers.
   - `--sections` and `--segment-height` are mutually exclusive. Do not pass both.
5. **Run**:
   ```bash
   scripts/html2img <input.html> <output.png> [width]
   ```
   Long page (fixed height):
   ```bash
   scripts/html2img <input.html> <output.png> [width] --segment-height 7000
   ```
   One file per section:
   ```bash
   scripts/html2img <input.html> <output.png> [width] --sections
   ```
6. **Report paths** — single file prints one path; segmented modes print `output-1.png`, `output-2.png`, …

## Mode selection rules (for LLMs)

Use this exact decision order to avoid confusion:

1. If the user wants one image and page is not very long -> **single mode** (no flag).
2. Else, if content may exceed single-image limits, guide the LLM to add `[data-html2img-section]` wrappers -> **use `--sections`**.
3. If HTML cannot be changed -> **use `--segment-height`** with a practical height (typically `6000-9000`).

Quick mapping:

| Situation | Command mode |
|---|---|
| Short/simple page, one output | default (no segmentation flag) |
| Long report / possibly over height limit | Prefer adding wrappers + `--sections` |
| HTML cannot be changed | `--segment-height` |

Critical clarification:
- This is **not** "`--sections` vs `--segment-height` always 二选一".
- There are **three** valid modes: default single image, section-based segmentation, fixed-height segmentation.
- Only the two segmentation flags are mutually exclusive.

## Section HTML (for LLMs generating reports)

**Convention:** wrap each block that should become its own PNG in an element with `data-html2img-section`. Use document order; each match becomes one output image sized to that element’s layout box.

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

1. One logical “slide” or “card group” per `[data-html2img-section]` wrapper — do not split a single chart/table across two sections.
2. Prefer block-level wrappers (`section`, `div`) that contain the full visual unit (heading + body + footnotes in that unit).
3. Do not nest `[data-html2img-section]` inside another `[data-html2img-section]` (outer box only).
4. Avoid putting the attribute on `position: sticky` roots only; wrap inner content so the export box is stable.
5. After generating HTML, render with:  
   `scripts/html2img <file.html> <out.png> <width> --sections`

**Copyable LLM instruction**

> Structure the report as a sequence of `<section data-html2img-section>` (or `<div data-html2img-section>`) blocks, each containing one major unit of content. Then export with `html2img … --sections` to get `out-1.png`, `out-2.png`, …

## Common troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Image blank or empty | JS/fonts not finished; page may need more time to load |
| Styles missing | Linked CSS paths wrong relative to the HTML file |
| Charts missing | Chart.js or network blocked |
| Long page truncated / blank at bottom | Use `--segment-height` or structure with `--sections` |
| Wrong slice boundaries | Adjust `[data-html2img-section]` grouping; avoid splitting components |
