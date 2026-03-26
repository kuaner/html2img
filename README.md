# html2img

A lightweight macOS command-line tool that renders local HTML files to PNG images using WebKit. No Chrome, no Puppeteer, no heavyweight dependencies — just native WebKit.

## Use Cases

- **Agent screenshots** — AI agents generate interactive UI components (charts, dashboards, cards) as HTML, then capture them as images for sharing or embedding
- **HTML template rendering** — Use HTML/CSS templates to generate posters, social media cards, infographics, then export as PNG
- **Chart & diagram export** — Render Chart.js / Canvas visualizations to high-quality images
- **Report generation** — Convert HTML reports to images for automated delivery

## Features

- Full CSS / JavaScript / Canvas / Chart.js support via WKWebView
- Auto-detects content height
- Configurable viewport width
- Optional fixed-height segmentation or `--sections` (one PNG per `[data-html2img-section]` block)
- Usable as a CLI tool or as a Swift library

## Requirements

- macOS 13+
- Xcode 15+ (or Swift 5.9+)

## Install

```bash
git clone https://github.com/kuaner/html2img.git
cd html2img
make install
```

This builds and installs the `html2img` binary to `/usr/local/bin`.

## Usage

### CLI

```bash
html2img input.html output.png
html2img input.html output.png 1200   # custom width
html2img input.html output.png --segment-height 8000  # output-1.png, output-2.png...
html2img input.html output.png --sections  # one PNG per [data-html2img-section] block
```

Single-image limit note:
- Single-image mode has a practical cap around **28800 output px** (about **14400 CSS px/pt** at Retina 2x).
- For reliability, keep single-image exports under **12000 output px**.
- If a page may exceed this limit, prefer adding `data-html2img-section` wrappers and use `--sections`.
- Only when HTML cannot be modified, use `--segment-height` fallback.

### Section-based slicing

When fixed-height slices cut through cards/charts, wrap each logical block in a container with `data-html2img-section` (any tag, e.g. `<section>` or `<div>`):

```html
<section data-html2img-section>...</section>
<section data-html2img-section>...</section>
```

```bash
html2img report.html out.png --sections
```

- Outputs `out-1.png`, `out-2.png`, … in document order, one image per section’s bounding box.

### As a Swift library

```swift
import HTML2Img

let renderer = Renderer()
renderer.render(fileURL: url, width: 800) { result in
    switch result {
    case .success(let image):
        // use NSImage
    case .failure(let error):
        print(error)
    }
}

renderer.renderSegmentedBySections(fileURL: url, width: 800) { result in
    switch result {
    case .success(let images): break // one NSImage per [data-html2img-section]
    case .failure(let error): print(error)
    }
}
```

Add the dependency in `Package.swift`:

```swift
.package(url: "https://github.com/kuaner/html2img.git", from: "0.1.0")
```

## Notes

- **Local files only** — `html2img` renders local HTML files. Remote URLs are not supported.
- **External resources** — CSS/JS/images can be local files or loaded from CDN. Both relative paths and remote URLs are supported.
- **Single-image height limit** — practical hard cap is about **28800 output pixels** (roughly **14400 CSS px/pt** at Retina 2x). Beyond this range, single-image mode may truncate or render blank near the bottom.
- **Recommended threshold** — keep single-image exports under **12000 output pixels** for safer results; use `--sections` or `--segment-height` for taller pages.
- **Avoid `vh`/`vw` units** — viewport units are unreliable in offscreen WKWebView rendering. Use fixed `px`, `rem`, or `clamp()` instead. See [CSS considerations](#css-considerations) below.
- **`position: absolute` works** — absolute positioning is fully supported. Overlays (`position: absolute` + `z-index`) and background layers render correctly.

## CSS considerations

html2img uses a native viewport size (not stretched to content height), so CSS behaves close to a real browser:

- **Safe**: `px`, `rem`, `em`, `%`, `clamp()`, `position: absolute`, `z-index`, `object-fit`, flexbox, grid
- **Avoid**: `vh`, `vw`, `vmin`, `vmax` — these depend on the WKWebView frame size which is not a standard viewport
- **Background images**: CSS `background-image` with relative paths works when loaded via `file://`. For reliability with section-based rendering, prefer `<img>` tags with `position: absolute` for hero-style overlays.

## How it works

1. Loads the HTML file into an offscreen WKWebView (native viewport size, not stretched)
2. Waits for the page to fully load (including JS, Canvas, etc.)
3. Measures the full content height via `scrollHeight`
4. Exports to PDF via `WKWebView.createPDF` with `WKPDFConfiguration.rect`
5. Renders the PDF page to an `NSImage`

## License

MIT
