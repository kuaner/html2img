import Cocoa
import WebKit
import PDFKit

/// Renders a local HTML file into an `NSImage` using an offscreen WKWebView.
public final class Renderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var window: NSWindow?
    private var completion: ((Result<NSImage, Error>) -> Void)?
    private var segmentedCompletion: ((Result<[NSImage], Error>) -> Void)?
    private var segmentHeight: CGFloat?
    private var segmentBySections = false

    /// Wrap each logical slice of report HTML in an element with this attribute; use `renderSegmentedBySections`.
    public static let sectionAttribute = "data-html2img-section"

    /// Render a local HTML file to an image.
    /// - Parameters:
    ///   - fileURL: Local file URL pointing to the HTML file.
    ///   - width: Viewport width in points (default 800).
    ///   - completion: Called on the main thread with the result.
    public func render(
        fileURL: URL,
        width: CGFloat = 800,
        completion: @escaping (Result<NSImage, Error>) -> Void
    ) {
        self.completion = completion
        self.segmentHeight = nil
        self.segmentBySections = false

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        webView.navigationDelegate = self
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.isReleasedWhenClosed = false
        window.alphaValue = 0.0
        self.window = window

        let directory = fileURL.deletingLastPathComponent()
        webView.loadFileURL(fileURL, allowingReadAccessTo: directory)
    }

    /// Render a local HTML file into multiple image segments.
    /// - Parameters:
    ///   - fileURL: Local file URL pointing to the HTML file.
    ///   - width: Viewport width in points (default 800).
    ///   - segmentHeight: Height per output segment in points.
    ///   - completion: Called with ordered segment images from top to bottom.
    public func renderSegmented(
        fileURL: URL,
        width: CGFloat = 800,
        segmentHeight: CGFloat,
        completion: @escaping (Result<[NSImage], Error>) -> Void
    ) {
        self.segmentedCompletion = completion
        self.segmentHeight = max(1, segmentHeight)
        self.segmentBySections = false

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        webView.navigationDelegate = self
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.isReleasedWhenClosed = false
        window.alphaValue = 0.0
        self.window = window

        let directory = fileURL.deletingLastPathComponent()
        webView.loadFileURL(fileURL, allowingReadAccessTo: directory)
    }

    /// Render a local HTML file into one PNG per `[data-html2img-section]` block (document order).
    public func renderSegmentedBySections(
        fileURL: URL,
        width: CGFloat = 800,
        completion: @escaping (Result<[NSImage], Error>) -> Void
    ) {
        self.segmentedCompletion = completion
        self.segmentHeight = nil
        self.segmentBySections = true

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        webView.navigationDelegate = self
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.isReleasedWhenClosed = false
        window.alphaValue = 0.0
        self.window = window

        let directory = fileURL.deletingLastPathComponent()
        webView.loadFileURL(fileURL, allowingReadAccessTo: directory)
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        waitForPageLoad {
            self.captureContentHeight()
        }
    }

    // MARK: - Private

    private func waitForPageLoad(_ done: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { done() }
    }

    private func captureContentHeight() {
        webView?.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
            let totalHeight: CGFloat
            if let h = result as? Double {
                totalHeight = h > 0 ? h : 600
            } else if let h = result as? Int {
                totalHeight = CGFloat(h) > 0 ? CGFloat(h) : 600
            } else {
                totalHeight = 600
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.segmentBySections {
                    self.captureSectionRanges()
                } else if let segmentHeight = self.segmentHeight {
                    self.generateSegmentedPDF(totalHeight: totalHeight, segmentHeight: segmentHeight)
                } else {
                    self.generatePDF(height: totalHeight)
                }
            }
        }
    }

    private func generatePDF(height: CGFloat) {
        guard let webView else {
            finish(.failure(RenderError.webViewReleased))
            return
        }

        let config = WKPDFConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: webView.frame.width, height: height)

        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                self.pdfToImage(data: data)
            case .failure(let error):
                self.finish(.failure(error))
            }
        }
    }

    private func pdfToImage(data: Data) {
        guard let pdf = PDFDocument(data: data),
              let page = pdf.page(at: 0) else {
            finish(.failure(RenderError.pdfConversionFailed))
            return
        }

        let rect = page.bounds(for: .mediaBox)
        let image = NSImage(size: rect.size)
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            finish(.failure(RenderError.graphicsContextUnavailable))
            return
        }
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(rect)
        if let pageRef = page.pageRef {
            ctx.drawPDFPage(pageRef)
        }
        image.unlockFocus()

        finish(.success(image))
    }

    private func pdfToImageResult(data: Data) -> Result<NSImage, Error> {
        guard let pdf = PDFDocument(data: data),
              let page = pdf.page(at: 0) else {
            return .failure(RenderError.pdfConversionFailed)
        }

        let rect = page.bounds(for: .mediaBox)
        let image = NSImage(size: rect.size)
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return .failure(RenderError.graphicsContextUnavailable)
        }
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(rect)
        if let pageRef = page.pageRef {
            ctx.drawPDFPage(pageRef)
        }
        image.unlockFocus()
        return .success(image)
    }

    private func generateSegmentedPDF(totalHeight: CGFloat, segmentHeight: CGFloat) {
        var cutOffsets: [CGFloat] = []
        var current: CGFloat = segmentHeight
        while current < totalHeight {
            cutOffsets.append(current)
            current += segmentHeight
        }
        generateSegmentedPDF(totalHeight: totalHeight, cutOffsets: cutOffsets)
    }

    private func generateSegmentedPDF(ranges: [(CGFloat, CGFloat)]) {
        guard let webView else {
            finishSegmented(.failure(RenderError.webViewReleased))
            return
        }

        let validRanges = ranges.filter { $0.1 > 0 }
        guard !validRanges.isEmpty else {
            finishSegmented(.failure(RenderError.invalidSections))
            return
        }

        var rangeIndex = 0
        var images: [NSImage] = []

        func renderNextSegment() {
            if rangeIndex >= validRanges.count {
                finishSegmented(.success(images))
                return
            }

            let (yOffset, currentHeight) = validRanges[rangeIndex]
            let config = WKPDFConfiguration()
            config.rect = CGRect(x: 0, y: yOffset, width: webView.frame.width, height: currentHeight)

            webView.createPDF(configuration: config) { result in
                switch result {
                case .success(let data):
                    switch self.pdfToImageResult(data: data) {
                    case .success(let image):
                        images.append(image)
                        rangeIndex += 1
                        renderNextSegment()
                    case .failure(let error):
                        self.finishSegmented(.failure(error))
                    }
                case .failure(let error):
                    self.finishSegmented(.failure(error))
                }
            }
        }

        renderNextSegment()
    }

    private func generateSegmentedPDF(totalHeight: CGFloat, cutOffsets: [CGFloat]) {
        let normalizedCuts = cutOffsets
            .filter { $0 > 1 && $0 < totalHeight - 1 }
            .sorted()

        var ranges: [(CGFloat, CGFloat)] = []
        var start: CGFloat = 0
        for cut in normalizedCuts {
            let h = cut - start
            if h > 0 {
                ranges.append((start, h))
            }
            start = cut
        }
        if totalHeight - start > 0 {
            ranges.append((start, totalHeight - start))
        }

        if ranges.isEmpty {
            finishSegmented(.failure(RenderError.invalidSections))
            return
        }
        generateSegmentedPDF(ranges: ranges)
    }

    private func captureSectionRanges() {
        guard let webView else {
            finishSegmented(.failure(RenderError.webViewReleased))
            return
        }

        let attr = Self.sectionAttribute.replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (() => {
          const nodes = Array.from(document.querySelectorAll('[\(attr)]'));
          return nodes.map(el => {
            const r = el.getBoundingClientRect();
            const top = Math.round(r.top + window.scrollY);
            const h = Math.round(r.height);
            return [top, h];
          }).filter(pair => pair[1] > 0);
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let error {
                self.finishSegmented(.failure(error))
                return
            }
            var ranges: [(CGFloat, CGFloat)] = []
            if let pairs = result as? [[Any]] {
                for pair in pairs {
                    guard pair.count >= 2,
                          let t = pair[0] as? NSNumber,
                          let h = pair[1] as? NSNumber else { continue }
                    ranges.append((CGFloat(truncating: t), CGFloat(truncating: h)))
                }
            }
            if ranges.isEmpty {
                self.finishSegmented(.failure(RenderError.invalidSections))
                return
            }
            self.generateSegmentedPDF(ranges: ranges)
        }
    }

    private func finish(_ result: Result<NSImage, Error>) {
        DispatchQueue.main.async { [self] in
            webView?.navigationDelegate = nil
            webView?.removeFromSuperview()
            webView = nil
            window = nil
            completion?(result)
            completion = nil
            segmentedCompletion = nil
            segmentHeight = nil
            segmentBySections = false
        }
    }

    private func finishSegmented(_ result: Result<[NSImage], Error>) {
        DispatchQueue.main.async { [self] in
            webView?.navigationDelegate = nil
            webView?.removeFromSuperview()
            webView = nil
            window = nil
            segmentedCompletion?(result)
            segmentedCompletion = nil
            completion = nil
            segmentHeight = nil
            segmentBySections = false
        }
    }
}

// MARK: - Errors

public enum RenderError: LocalizedError {
    case webViewReleased
    case pdfConversionFailed
    case graphicsContextUnavailable
    case invalidSections

    public var errorDescription: String? {
        switch self {
        case .webViewReleased: "WKWebView was released before rendering completed"
        case .pdfConversionFailed: "Failed to convert PDF to image"
        case .graphicsContextUnavailable: "Unable to obtain graphics context"
        case .invalidSections: "No valid [data-html2img-section] blocks found"
        }
    }
}
