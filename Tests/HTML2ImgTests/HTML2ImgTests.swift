import XCTest
@testable import HTML2ImgCore

final class HTML2ImgTests: XCTestCase {
    func testRendererInit() {
        let renderer = Renderer()
        XCTAssertNotNil(renderer)
    }
}
