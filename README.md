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
```

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
```

Add the dependency in `Package.swift`:

```swift
.package(url: "https://github.com/kuaner/html2img.git", from: "0.1.0")
```

## Notes

- **Local files only** — `html2img` renders local HTML files. Remote URLs are not supported.
- **External resources** — CSS/JS/images can be local files or loaded from CDN. Both relative paths and remote URLs are supported.

## How it works

1. Loads the HTML file into an offscreen WKWebView
2. Waits for the page to fully load (including JS, Canvas, etc.)
3. Measures the full content height
4. Exports to PDF via `WKWebView.createPDF`
5. Renders the PDF page to an `NSImage`

## License

MIT
