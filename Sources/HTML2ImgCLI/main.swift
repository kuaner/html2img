import Cocoa
import HTML2ImgCore

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("Usage: html2img <input.html> <output.png> [width] [--segment-height <height>] [--sections] [--height]\n", stderr)
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
var width: CGFloat = 800
var segmentHeight: CGFloat?
var sections = false
var heightOnly = false

var idx = 3
while idx < args.count {
    let token = args[idx]
    if token == "--segment-height" {
        guard idx + 1 < args.count, let value = Double(args[idx + 1]), value > 0 else {
            fputs("Error: --segment-height requires a positive number\n", stderr)
            exit(1)
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

    fputs("Error: unknown argument: \(token)\n", stderr)
    exit(1)
}

if sections, segmentHeight != nil {
    fputs("Error: --sections and --segment-height cannot be used together\n", stderr)
    exit(1)
}

var isDir: ObjCBool = false
guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDir), !isDir.boolValue else {
    fputs("Error: file not found: \(inputPath)\n", stderr)
    exit(1)
}

let fileURL = URL(fileURLWithPath: inputPath)

let app = NSApplication.shared
let renderer = Renderer()

let maxHeight: CGFloat = 6000
let defaultSegmentHeight: CGFloat = 6000

func outputBaseAndExt() -> (String, String) {
    let outputURL = URL(fileURLWithPath: outputPath)
    let base = outputURL.deletingPathExtension().path
    let ext = outputURL.pathExtension.isEmpty ? "png" : outputURL.pathExtension
    return (base, ext)
}

func writePNG(_ image: NSImage, to path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "html2img", code: 1, userInfo: [NSLocalizedDescriptionKey: "failed to encode PNG"])
    }
    try png.write(to: URL(fileURLWithPath: path))
}

func writeSegmentOutputs(images: [NSImage]) throws -> [String] {
    let (base, ext) = outputBaseAndExt()
    var paths: [String] = []
    for (index, image) in images.enumerated() {
        let path = "\(base)-\(index + 1).\(ext)"
        try writePNG(image, to: path)
        paths.append(path)
    }
    return paths
}

func filesJSON(_ paths: [String]) -> String {
    paths.map { "\"\($0)\"" }.joined(separator: ",")
}

if let segmentHeight {
    renderer.renderSegmented(fileURL: fileURL, width: width, segmentHeight: segmentHeight) { result in
        switch result {
        case .success(let images):
            if images.isEmpty { fputs("Error: no segment images produced\n", stderr); exit(1) }
            do {
                let paths = try writeSegmentOutputs(images: images)
                print("{\"mode\":\"segmented\",\"segment_height\":\(Int(segmentHeight)),\"count\":\(paths.count),\"files\":[\(filesJSON(paths))]}")
            } catch { fputs("Error: \(error)\n", stderr); exit(1) }
        case .failure(let error): fputs("Error: \(error)\n", stderr); exit(1)
        }
        exit(0)
    }
} else if sections {
    renderer.renderSegmentedBySections(fileURL: fileURL, width: width) { result in
        switch result {
        case .success(let images):
            if images.isEmpty { fputs("Error: no section images produced\n", stderr); exit(1) }
            do {
                let paths = try writeSegmentOutputs(images: images)
                print("{\"mode\":\"sections\",\"count\":\(paths.count),\"files\":[\(filesJSON(paths))]}")
            } catch { fputs("Error: \(error)\n", stderr); exit(1) }
        case .failure(let error): fputs("Error: \(error)\n", stderr); exit(1)
        }
        exit(0)
    }
} else if heightOnly {
    renderer.measureHeight(fileURL: fileURL, width: width) { result in
        switch result {
        case .success(let height):
            let outputPx = Int(height * 2)
            let sectionsCount = Int(ceil(height / maxHeight))
            if sectionsCount > 1 {
                print("{\"height\":\(Int(height)),\"output_px\":\(outputPx),\"mode\":\"sections\",\"estimated_sections\":\(sectionsCount),\"recommendation\":\"use --sections\"}")
            } else {
                print("{\"height\":\(Int(height)),\"output_px\":\(outputPx),\"mode\":\"single\",\"recommendation\":\"safe for single image\"}")
            }
        case .failure(let error): fputs("Error: \(error)\n", stderr); exit(1)
        }
        exit(0)
    }
} else {
    // Auto mode: measure height + check sections, then decide
    renderer.measureAuto(fileURL: fileURL, width: width) { result in
        switch result {
        case .success(let info):
            if info.height <= maxHeight {
                renderer.render(fileURL: fileURL, width: width) { result in
                    switch result {
                    case .success(let image):
                        do {
                            try writePNG(image, to: outputPath)
                            let h = Int(image.size.height)
                            print("{\"mode\":\"single\",\"height\":\(h),\"output_px\":\(h * 2),\"files\":[\"\(outputPath)\"]}")
                        } catch { fputs("Error: \(error)\n", stderr); exit(1) }
                    case .failure(let error): fputs("Error: \(error)\n", stderr); exit(1)
                    }
                    exit(0)
                }
            } else if info.hasSections {
                renderer.renderSegmentedBySections(fileURL: fileURL, width: width) { result in
                    switch result {
                    case .success(let images):
                        if images.isEmpty { fputs("Error: no section images produced\n", stderr); exit(1) }
                        do {
                            let paths = try writeSegmentOutputs(images: images)
                            print("{\"mode\":\"sections\",\"height\":\(Int(info.height)),\"output_px\":\(Int(info.height * 2)),\"count\":\(paths.count),\"files\":[\(filesJSON(paths))]}")
                        } catch { fputs("Error: \(error)\n", stderr); exit(1) }
                    case .failure(let error): fputs("Error: \(error)\n", stderr); exit(1)
                    }
                    exit(0)
                }
            } else {
                renderer.renderSegmented(fileURL: fileURL, width: width, segmentHeight: defaultSegmentHeight) { result in
                    switch result {
                    case .success(let images):
                        if images.isEmpty { fputs("Error: no segment images produced\n", stderr); exit(1) }
                        do {
                            let paths = try writeSegmentOutputs(images: images)
                            print("{\"mode\":\"segmented\",\"height\":\(Int(info.height)),\"output_px\":\(Int(info.height * 2)),\"segment_height\":\(Int(defaultSegmentHeight)),\"count\":\(paths.count),\"files\":[\(filesJSON(paths))]}")
                        } catch { fputs("Error: \(error)\n", stderr); exit(1) }
                    case .failure(let error): fputs("Error: \(error)\n", stderr); exit(1)
                    }
                    exit(0)
                }
            }
        case .failure(let error): fputs("Error: \(error)\n", stderr); exit(1)
        }
    }
}

app.run()
