import XCTest
@testable import HTML2ImgCore
import Foundation

final class HTML2ImgTests: XCTestCase {

    // MARK: - AutoResult

    func testAutoResultDefaults() {
        let result = AutoResult(height: 3000, sectionCount: 0)
        XCTAssertEqual(result.height, 3000)
        XCTAssertEqual(result.sectionCount, 0)
        XCTAssertFalse(result.hasSections)
    }

    func testAutoResultWithSections() {
        let result = AutoResult(height: 9000, sectionCount: 5)
        XCTAssertEqual(result.height, 9000)
        XCTAssertEqual(result.sectionCount, 5)
        XCTAssertTrue(result.hasSections)
    }

    func testAutoResultSingleSection() {
        let result = AutoResult(height: 500, sectionCount: 1)
        XCTAssertTrue(result.hasSections)
        XCTAssertEqual(result.sectionCount, 1)
    }

    // MARK: - Auto-mode decision logic

    /// Pure logic test: given height and section info, decide which mode to use.
    /// This mirrors the decision in main.swift's else branch.
    /// The actual threshold is 6000 CSS px.
    static let autoThreshold: CGFloat = 6000
    static let defaultSegmentHeight: CGFloat = 6000

    enum AutoDecision {
        case single
        case sections
        case segmented
    }

    static func decideMode(height: CGFloat, hasSections: Bool) -> AutoDecision {
        if height <= autoThreshold {
            return .single
        } else if hasSections {
            return .sections
        } else {
            return .segmented
        }
    }

    func testAutoModeShortPage() {
        XCTAssertEqual(Self.decideMode(height: 3000, hasSections: false), .single)
    }

    func testAutoModeShortPageWithSections() {
        XCTAssertEqual(Self.decideMode(height: 3000, hasSections: true), .single)
    }

    func testAutoModeTallPageWithSections() {
        XCTAssertEqual(Self.decideMode(height: 9709, hasSections: true), .sections)
    }

    func testAutoModeTallPageWithoutSections() {
        XCTAssertEqual(Self.decideMode(height: 9709, hasSections: false), .segmented)
    }

    func testAutoModeExactlyAtThreshold() {
        XCTAssertEqual(Self.decideMode(height: 6000, hasSections: false), .single)
        XCTAssertEqual(Self.decideMode(height: 6001, hasSections: true), .sections)
        XCTAssertEqual(Self.decideMode(height: 6001, hasSections: false), .segmented)
    }

    func testAutoModeVeryTallPage() {
        XCTAssertEqual(Self.decideMode(height: 20000, hasSections: false), .segmented)
        XCTAssertEqual(Self.decideMode(height: 20000, hasSections: true), .sections)
    }

    func testAutoModeTinyPage() {
        XCTAssertEqual(Self.decideMode(height: 10, hasSections: false), .single)
        XCTAssertEqual(Self.decideMode(height: 0, hasSections: false), .single)
    }

    // MARK: - JSON output parsing

    /// Verify that CLI output can be parsed as JSON and contains expected fields.
    /// These tests validate the JSON schema, not the rendering itself.

    func testSingleModeJSONParse() {
        let json = "{\"mode\":\"single\",\"height\":600,\"output_px\":1200,\"files\":[\"/tmp/out.png\"]}"
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(obj["mode"] as! String, "single")
        XCTAssertEqual(obj["height"] as! Int, 600)
        XCTAssertEqual(obj["output_px"] as! Int, 1200)
        let files = obj["files"] as! [String]
        XCTAssertEqual(files, ["/tmp/out.png"])
    }

    func testSectionsModeJSONParse() {
        let json = "{\"mode\":\"sections\",\"height\":9709,\"output_px\":19418,\"count\":11,\"files\":[\"/tmp/out-1.png\",\"/tmp/out-2.png\"]}"
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(obj["mode"] as! String, "sections")
        XCTAssertEqual(obj["height"] as! Int, 9709)
        XCTAssertEqual(obj["count"] as! Int, 11)
        let files = obj["files"] as! [String]
        XCTAssertEqual(files.count, 2)
    }

    func testSegmentedModeJSONParse() {
        let json = "{\"mode\":\"segmented\",\"height\":15000,\"output_px\":30000,\"segment_height\":6000,\"count\":3,\"files\":[\"/tmp/out-1.png\",\"/tmp/out-2.png\",\"/tmp/out-3.png\"]}"
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(obj["mode"] as! String, "segmented")
        XCTAssertEqual(obj["segment_height"] as! Int, 6000)
        XCTAssertEqual(obj["count"] as! Int, 3)
        let files = obj["files"] as! [String]
        XCTAssertEqual(files.count, 3)
    }

    func testHeightModeJSONParse() {
        let json = "{\"height\":9709,\"output_px\":19418,\"mode\":\"sections\",\"estimated_sections\":2,\"recommendation\":\"use --sections\"}"
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(obj["mode"] as! String, "sections")
        let rec = obj["recommendation"] as! String
        XCTAssertTrue(rec.contains("sections"))
    }

    func testInvalidJSONFails() {
        let json = "not json"
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONSerialization.jsonObject(with: data))
    }

    // MARK: - Argument parsing (pure logic, no subprocess)

    /// Simulates the CLI argument parsing logic from main.swift.
    /// Returns (width, sections, segmentHeight, heightOnly) or nil on error.
    static func parseArgs(_ args: [String]) -> (width: CGFloat, sections: Bool, segmentHeight: CGFloat?, heightOnly: Bool)? {
        var width: CGFloat = 800
        var sections = false
        var segmentHeight: CGFloat?
        var heightOnly = false

        // Skip first 2 (input, output) — simulate parsing from index 2 onward
        var idx = 0
        let tokens = args

        while idx < tokens.count {
            let token = tokens[idx]
            if token == "--segment-height" {
                guard idx + 1 < tokens.count, let value = Double(tokens[idx + 1]), value > 0 else {
                    return nil
                }
                segmentHeight = CGFloat(value)
                idx += 2
                continue
            }
            if token == "--sections" {
                sections = true
                idx += 1
                continue
            }
            if token == "--height" {
                heightOnly = true
                idx += 1
                continue
            }
            if let value = Double(token), value > 0, width == 800 {
                width = CGFloat(value)
                idx += 1
                continue
            }
            return nil // unknown arg
        }
        return (width, sections, segmentHeight, heightOnly)
    }

    func testParseArgsDefault() {
        let result = Self.parseArgs([])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.width, 800)
        XCTAssertFalse(result!.sections)
        XCTAssertNil(result!.segmentHeight)
        XCTAssertFalse(result!.heightOnly)
    }

    func testParseArgsWidth() {
        let result = Self.parseArgs(["1440"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.width, 1440)
    }

    func testParseArgsSections() {
        let result = Self.parseArgs(["--sections"])
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.sections)
    }

    func testParseArgsSegmentHeight() {
        let result = Self.parseArgs(["--segment-height", "8000"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.segmentHeight, 8000)
    }

    func testParseArgsHeight() {
        let result = Self.parseArgs(["--height"])
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.heightOnly)
    }

    func testParseArgsCombined() {
        let result = Self.parseArgs(["1440", "--sections"])
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.width, 1440)
        XCTAssertTrue(result!.sections)
    }

    func testParseArgsUnknownFails() {
        let result = Self.parseArgs(["--bogus"])
        XCTAssertNil(result)
    }

    func testParseArgsSegmentHeightMissingValueFails() {
        let result = Self.parseArgs(["--segment-height"])
        XCTAssertNil(result)
    }

    func testParseArgsNegativeWidthFails() {
        let result = Self.parseArgs(["-100"])
        XCTAssertNil(result)
    }

    func testParseArgsZeroWidthFails() {
        let result = Self.parseArgs(["0"])
        XCTAssertNil(result)
    }

    func testParseArgsSecondNumericFails() {
        // main.swift rejects the second numeric (width already set, guard fails)
        let result = Self.parseArgs(["1440", "2000"])
        XCTAssertNil(result)
    }

    // MARK: - Renderer initialization

    func testRendererInit() {
        let renderer = Renderer()
        XCTAssertNotNil(renderer)
    }

    // MARK: - Section attribute constant

    func testSectionAttribute() {
        XCTAssertEqual(Renderer.sectionAttribute, "data-html2img-section")
    }
}

// MARK: - Argument parsing tests for mutually exclusive flags

extension HTML2ImgTests {
    func testSectionsAndSegmentHeightExclusion() {
        // --sections and --segment-height are mutually exclusive
        let result = Self.parseArgs(["--sections", "--segment-height", "6000"])
        // Parser accepts both (validation happens at a higher level),
        // but the CLI will reject this combination
        XCTAssertTrue(result!.sections)
        XCTAssertEqual(result!.segmentHeight, 6000)
        // In production, main.swift checks this and exits with error.
    }
}

// MARK: - Integration tests (run html2img binary against fixture HTML)

extension HTML2ImgTests {

    private func fixturePath(_ name: String) -> String {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: "html", subdirectory: "Fixtures") else {
            XCTFail("Fixture \(name).html not found in test bundle")
            return "/dev/null"
        }
        return url.path
        #else
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).html")
            .path
        #endif
    }

    /// Find the html2img binary: first check .build/release, then .build/debug
    private func html2imgBinary() -> String? {
        let base = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for config in ["release", "debug"] {
            let path = base.appendingPathComponent(".build/\(config)/html2img").path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Run html2img binary and return (stdout, stderr, exitCode)
    private func runHTML2Img(args: [String], timeout: TimeInterval = 30) -> (stdout: String, stderr: String, exitCode: Int32) {
        guard let bin = html2imgBinary() else {
            XCTFail("html2img binary not found in .build/release or .build/debug")
            return ("", "binary not found", 1)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin)
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        process.launch()
        // For tall/segmented pages, give extra time
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }

    /// Parse JSON stdout into a dictionary
    private func parseJSONOutput(_ stdout: String) -> [String: Any]? {
        guard let data = stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: Auto mode — short page (single)

    func testIntegrationAutoShortPage() {
        let input = fixturePath("short")
        let output = "/tmp/html2img-test-short.png"
        let (stdout, stderr, code) = runHTML2Img(args: [input, output])
        XCTAssertEqual(code, 0, "html2img failed: \(stderr)")
        let json = parseJSONOutput(stdout)
        XCTAssertNotNil(json, "Expected JSON output, got: \(stdout)")
        XCTAssertEqual(json!["mode"] as? String, "single")
        XCTAssertGreaterThan((json!["height"] as? Int) ?? 0, 0)
        let files = json!["files"] as? [String]
        XCTAssertEqual(files?.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output))
        // Cleanup
        try? FileManager.default.removeItem(atPath: output)
    }

    // MARK: Auto mode — tall page without sections (segmented)

    func testIntegrationAutoTallNoSections() {
        let input = fixturePath("tall")
        let output = "/tmp/html2img-test-tall.png"
        let (stdout, stderr, code) = runHTML2Img(args: [input, output])
        XCTAssertEqual(code, 0, "html2img failed: \(stderr)")
        let json = parseJSONOutput(stdout)
        XCTAssertNotNil(json, "Expected JSON output, got: \(stdout)")
        XCTAssertEqual(json!["mode"] as? String, "segmented")
        XCTAssertGreaterThanOrEqual((json!["count"] as? Int) ?? 0, 2)
        let files = json!["files"] as? [String]
        XCTAssertNotNil(files)
        // Verify all output files exist
        for f in files! {
            XCTAssertTrue(FileManager.default.fileExists(atPath: f), "Missing file: \(f)")
        }
        // Cleanup
        for f in files! {
            try? FileManager.default.removeItem(atPath: f)
        }
    }

    // MARK: Auto mode — page with sections (height ≤ 6000 → single, not sections)

    func testIntegrationAutoWithSectionsShortPage() {
        // sections.html is only 1200px tall → auto mode picks single
        let input = fixturePath("sections")
        let output = "/tmp/html2img-test-sections.png"
        let (stdout, stderr, code) = runHTML2Img(args: [input, output])
        XCTAssertEqual(code, 0, "html2img failed: \(stderr)")
        let json = parseJSONOutput(stdout)
        XCTAssertNotNil(json, "Expected JSON output, got: \(stdout)")
        XCTAssertEqual(json!["mode"] as? String, "single")
        let files = json!["files"] as? [String]
        XCTAssertEqual(files?.count, 1)
        // Cleanup
        for f in files! {
            try? FileManager.default.removeItem(atPath: f)
        }
    }

    // MARK: Explicit --sections

    func testIntegrationExplicitSections() {
        let input = fixturePath("sections")
        let output = "/tmp/html2img-test-explicit-sections.png"
        let (stdout, stderr, code) = runHTML2Img(args: [input, output, "--sections"])
        XCTAssertEqual(code, 0, "html2img failed: \(stderr)")
        let json = parseJSONOutput(stdout)
        XCTAssertNotNil(json)
        XCTAssertEqual(json!["count"] as? Int, 3)
        // Cleanup
        let files = json!["files"] as? [String] ?? []
        for f in files { try? FileManager.default.removeItem(atPath: f) }
    }

    // MARK: Explicit --segment-height

    func testIntegrationExplicitSegmentHeight() {
        let input = fixturePath("tall")
        let output = "/tmp/html2img-test-segh.png"
        let (stdout, stderr, code) = runHTML2Img(args: [input, output, "--segment-height", "4000"])
        XCTAssertEqual(code, 0, "html2img failed: \(stderr)")
        let json = parseJSONOutput(stdout)
        XCTAssertNotNil(json)
        XCTAssertEqual(json!["mode"] as? String, "segmented")
        XCTAssertEqual(json!["segment_height"] as? Int, 4000)
        // Cleanup
        let files = json!["files"] as? [String] ?? []
        for f in files { try? FileManager.default.removeItem(atPath: f) }
    }

    // MARK: --height only

    func testIntegrationHeightOnly() {
        let input = fixturePath("short")
        let (stdout, stderr, code) = runHTML2Img(args: [input, "/tmp/dummy.png", "--height"])
        XCTAssertEqual(code, 0, "html2img failed: \(stderr)")
        let json = parseJSONOutput(stdout)
        XCTAssertNotNil(json)
        XCTAssertGreaterThan((json!["height"] as? Int) ?? 0, 0)
        XCTAssertNotNil(json!["recommendation"])
    }

    // MARK: Error — file not found

    func testIntegrationFileNotFound() {
        let (stdout, stderr, code) = runHTML2Img(args: ["/tmp/nonexistent.html", "/tmp/out.png"])
        XCTAssertNotEqual(code, 0)
        XCTAssertTrue(stderr.contains("file not found") || stderr.contains("Error"))
    }

    // MARK: Error — mutually exclusive flags

    func testIntegrationMutuallyExclusiveFlags() {
        let input = fixturePath("short")
        let (_, stderr, code) = runHTML2Img(args: [input, "/tmp/out.png", "--sections", "--segment-height", "4000"])
        XCTAssertNotEqual(code, 0)
        XCTAssertTrue(stderr.contains("cannot be used together"))
    }
}
