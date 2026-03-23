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

Render a local HTML file to a PNG image using the `html2img` CLI tool.

## How it works

`html2img` uses macOS WebKit to render HTML in an offscreen WKWebView, then exports the result as a PNG. It supports full CSS, JavaScript, Canvas, and Chart.js content.

## Usage

```bash
scripts/html2img <input.html> <output.png> [width]
```

Default width is 800px.

## Key constraints

- **Local files only** — the input must be a local `.html` file path. Remote URLs are not supported.
- **External resources** — CSS, JS, images, and fonts can be local files or loaded from CDN. Relative paths and remote URLs are supported.
- **Output is PNG** — the tool always outputs PNG format.
- **macOS only** — requires macOS 13+ and WebKit.

## Workflow

When asked to render HTML to an image, follow these steps:

1. **Locate the HTML file** — Find the `.html` file the user wants to render.

2. **Choose output path** — If the user doesn't specify an output path, place the PNG next to the HTML file with the same base name, e.g. `report.html` → `report.png`.

3. **Determine width** — Use the default 800px unless the user specifies a different width.

4. **Run the render**:
   ```bash
   scripts/html2img <input.html> <output.png> [width]
   ```

5. **Report the result** — Tell the user where the PNG was saved. If the command fails, share the error and suggest fixes.

## Common troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| Image is blank or empty | JavaScript hasn't finished executing; the page may need more load time |
| Styles are missing | CSS/JS files are not in the same directory as the HTML file |
| Fonts look wrong | Check that the font URL is correct and accessible; try Google Fonts CDN or local @font-face |
| Charts don't appear | Check the Chart.js script tag is correct and the network is accessible |
