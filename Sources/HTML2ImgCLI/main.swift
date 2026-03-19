import Cocoa
import HTML2ImgCore

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("Usage: html2img <input.html> <output.png> [width]\n", stderr)
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
let width = args.count > 3 ? CGFloat(Double(args[3]) ?? 800) : 800

var isDir: ObjCBool = false
guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDir), !isDir.boolValue else {
    fputs("Error: file not found: \(inputPath)\n", stderr)
    exit(1)
}

let fileURL = URL(fileURLWithPath: inputPath)

let app = NSApplication.shared
let renderer = Renderer()

renderer.render(fileURL: fileURL, width: width) { result in
    switch result {
    case .success(let image):
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            fputs("Error: failed to encode PNG\n", stderr)
            exit(1)
        }
        do {
            try png.write(to: URL(fileURLWithPath: outputPath))
            print(outputPath)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    case .failure(let error):
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
    exit(0)
}

app.run()
