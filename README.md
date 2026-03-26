# html2img

A lightweight macOS command-line tool that renders local HTML files to PNG images using WebKit. No Chrome, no Puppeteer, no heavyweight dependencies — just native WebKit.

## Use Cases

- **Agent screenshots** — AI agents generate interactive UI components (charts, dashboards, cards) as HTML, then capture them as images for sharing or embedding
- **HTML template rendering** — Use HTML/CSS templates to generate posters, social media cards, infographics, then export as PNG
- **Chart & diagram export** — Render Chart.js / Canvas visualizations to high-quality images
- **Report generation** — Convert HTML reports to images for automated delivery

## Features

- Full CSS / JavaScript / Canvas / Chart.js support via WKWebView
- **Auto mode** — no flags needed; automatically measures height and picks the best rendering strategy (single / sections / segment-height)
- Configurable viewport width
- Explicit `--sections` (one PNG per `[data-html2img-section]` block) or `--segment-height` fallback
- JSON output for programmatic use
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

### Auto mode (recommended)

Just run it. No flags needed:

```bash
html2img input.html output.png
html2img input.html output.png 1200   # custom width
```

The tool automatically:
1. Measures content height
2. If height ≤ 6000 CSS px → renders single image
3. If height > 6000 and HTML has `[data-html2img-section]` → sections mode
4. If height > 6000 and no sections → segment-height mode (6000px per segment)

### Explicit modes

```bash
html2img input.html output.png --sections               # force sections mode
html2img input.html output.png --segment-height 8000     # force segment-height
html2img input.html output.png --height                  # height check only (debugging)
```

### Output

All modes output JSON to stdout:

```json
{"mode":"single","height":600,"output_px":1200,"files":["output.png"]}
{"mode":"sections","height":9709,"output_px":19418,"count":11,"files":["output-1.png","output-2.png",...]}
{"mode":"segmented","height":9709,"output_px":19418,"segment_height":6000,"count":3,"files":["output-1.png","output-2.png","output-3.png"]}
```

| Field | Description |
|-------|-------------|
| `mode` | `single`, `sections`, or `segmented` |
| `height` | Content height in CSS pixels |
| `output_px` | Output height in pixels (Retina 2x) |
| `count` | Number of output files (sections/segmented only) |
| `segment_height` | Segment height used (segmented only) |
| `files` | Array of output file paths |

### Section-based slicing

Wrap each logical block in a container with `data-html2img-section`:

```html
<section data-html2img-section>...</section>
<section data-html2img-section>...</section>
```

```bash
html2img report.html out.png --sections
# → out-1.png, out-2.png, ...
```

One image per section's bounding box, in document order.

### As a Swift library

```swift
import HTML2Img

let renderer = Renderer()

// Single image
renderer.render(fileURL: url, width: 800) { result in
    switch result {
    case .success(let image): /* use NSImage */ break
    case .failure(let error): print(error)
    }
}

// By sections
renderer.renderSegmentedBySections(fileURL: url, width: 800) { result in
    switch result {
    case .success(let images): break // one NSImage per [data-html2img-section]
    case .failure(let error): print(error)
    }
}

// Auto measure
renderer.measureAuto(fileURL: url, width: 800) { result in
    switch result {
    case .success(let info):
        // info.height, info.sectionCount, info.hasSections
        break
    case .failure(let error): print(error)
    }
}
```

Add the dependency in `Package.swift`:

```swift
.package(url: "https://github.com/kuaner/html2img.git", from: "0.1.0")
```

## Testing

```bash
make test
```

Tests cover auto-mode logic, output parsing, and edge cases. See `Tests/HTML2ImgTests/` for details.

## Notes

- **Local files only** — `html2img` renders local HTML files. Remote URLs are not supported.
- **External resources** — CSS/JS/images can be local files or loaded from CDN. Both relative paths and remote URLs are supported.
- **Single-image height limit** — practical hard cap is about **28800 output pixels** (roughly **14400 CSS px/pt** at Retina 2x). Beyond this range, single-image mode may truncate or render blank near the bottom.
- **Recommended threshold** — keep single-image exports under **12000 output pixels** for safer results; auto mode handles this automatically.
- **Avoid `vh`/`vw` units** — viewport units are unreliable in offscreen WKWebView rendering. Use fixed `px`, `rem`, or `clamp()` instead.

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
