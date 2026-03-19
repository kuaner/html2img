import Cocoa
import WebKit
import PDFKit

/// Renders a local HTML file into an `NSImage` using an offscreen WKWebView.
public final class Renderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var window: NSWindow?
    private var completion: ((Result<NSImage, Error>) -> Void)?

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

        do {
            let html = try String(contentsOf: fileURL, encoding: .utf8)
            webView.loadHTMLString(html, baseURL: fileURL.deletingLastPathComponent())
        } catch {
            completion(.failure(error))
        }
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
            let height: CGFloat
            if let h = result as? Double {
                height = h > 0 ? h : 600
            } else if let h = result as? Int {
                height = CGFloat(h) > 0 ? CGFloat(h) : 600
            } else {
                height = 600
            }
            self.webView?.frame.size.height = height
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.generatePDF(height: height)
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

    private func finish(_ result: Result<NSImage, Error>) {
        DispatchQueue.main.async { [self] in
            webView?.navigationDelegate = nil
            webView?.removeFromSuperview()
            webView = nil
            window = nil
            completion?(result)
            completion = nil
        }
    }
}

// MARK: - Errors

public enum RenderError: LocalizedError {
    case webViewReleased
    case pdfConversionFailed
    case graphicsContextUnavailable

    public var errorDescription: String? {
        switch self {
        case .webViewReleased: "WKWebView was released before rendering completed"
        case .pdfConversionFailed: "Failed to convert PDF to image"
        case .graphicsContextUnavailable: "Unable to obtain graphics context"
        }
    }
}
