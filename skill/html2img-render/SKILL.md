---
name: html2img-render
description: >
  Render local HTML files to PNG images using the html2img CLI tool. Use this skill whenever the user
  wants to convert an HTML file to an image, take a screenshot of an HTML file, export HTML as PNG,
  render an HTML template to an image, or when you have just generated or modified an HTML file that
  the user might want to see as a rendered image. Also trigger when the user mentions "screenshot HTML",
  "render HTML", "HTML to image", "HTML to PNG", "export as image", or when there's an HTML file in the
  working directory and the user wants to preview or share it visually.
---

# html2img-render

Render a local HTML file to a PNG image using the `html2img` command-line tool.

## How it works

`html2img` uses macOS WebKit to render HTML in an offscreen WKWebView, then exports the result as a PNG. It supports full CSS, JavaScript, Canvas, and Chart.js content.

## Usage

### Basic rendering

```bash
html2img input.html output.png
```

### Custom viewport width

```bash
html2img input.html output.png 1200
```

Default width is 800px.

## Key constraints

- **Local files only** — the input must be a local `.html` file path. Remote URLs are not supported.
- **External resources** — CSS, JS, images, and fonts must be in the same directory (or a subdirectory) as the HTML file. Relative paths work, but remote CDN URLs (e.g. `<script src="https://...">`) will not load.
- **Output is PNG** — the tool always outputs PNG format.

## Workflow

When asked to render HTML to an image, follow these steps:

1. **Locate the HTML file** — Find the `.html` file the user wants to render. If they refer to a file by name, search for it in the working directory.

2. **Verify prerequisites** — Check that:
   - The HTML file exists at the specified path
   - The `html2img` binary is available (try `which html2img` or `html2img --help`)

3. **Choose output path** — If the user doesn't specify an output path, place the PNG next to the HTML file with the same base name, e.g. `report.html` → `report.png`.

4. **Determine width** — Use the default 800px unless the user specifies a different width. If the HTML content is designed for a particular viewport, use that width.

5. **Run the render**:
   ```bash
   html2img <input.html> <output.png> [width]
   ```

6. **Report the result** — Tell the user where the PNG was saved. If the command fails, share the error and suggest fixes (common issues: missing HTML file, external CDN resources, missing local CSS/JS dependencies).

## Common troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Image is blank or empty | JavaScript hasn't finished executing; the page may need more load time |
| Styles are missing | CSS/JS files are not in the same directory as the HTML file |
| Fonts look wrong | Web fonts loaded via CDN won't work; use local font files instead |
| Charts don't appear | Chart.js loaded from CDN won't work; include the library locally |
