// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "html2img",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "html2img", targets: ["HTML2ImgCLI"]),
        .library(name: "HTML2Img", targets: ["HTML2ImgCore"]),
    ],
    targets: [
        .target(
            name: "HTML2ImgCore",
            path: "Sources/HTML2ImgCore"
        ),
        .executableTarget(
            name: "HTML2ImgCLI",
            dependencies: ["HTML2ImgCore"],
            path: "Sources/HTML2ImgCLI"
        ),
        .testTarget(
            name: "HTML2ImgTests",
            dependencies: ["HTML2ImgCore"],
            path: "Tests/HTML2ImgTests"
        ),
    ]
)
