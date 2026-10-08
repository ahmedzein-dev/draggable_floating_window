// Extracts PNG frames from a screen recording, for make_demo_gif.dart.
//
//   swift tool/extract_frames.swift <recording.mov> <frames folder> [fps] [width]
//       [--from=SECONDS] [--to=SECONDS] [--crop=X,Y,WIDTH,HEIGHT]
//
// Record with Cmd+Shift+5 ("Record Selected Portion") on macOS. The frames
// are sampled at [fps] (default 15) between --from and --to (default: the
// whole recording), cropped to the --crop rectangle (in the recording's
// pixels, from the top left), scaled to [width] pixels (default: the cropped
// width) and converted to sRGB. A frames.json file lists them with their
// delays.
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

var positional: [String] = []
var from = 0.0
var to: Double?
var crop: CGRect?
for argument in CommandLine.arguments.dropFirst() {
  if argument.hasPrefix("--from=") {
    from = Double(argument.dropFirst(7))!
  } else if argument.hasPrefix("--to=") {
    to = Double(argument.dropFirst(5))!
  } else if argument.hasPrefix("--crop=") {
    let values = argument.dropFirst(7).split(separator: ",").map { Double($0)! }
    crop = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
  } else {
    positional.append(argument)
  }
}
guard positional.count >= 2 else {
  print(
    "Usage: swift tool/extract_frames.swift <recording.mov> <frames folder> [fps] [width] "
      + "[--from=SECONDS] [--to=SECONDS] [--crop=X,Y,WIDTH,HEIGHT]")
  exit(64)
}
let input = URL(fileURLWithPath: positional[0])
let output = URL(fileURLWithPath: positional[1], isDirectory: true)
let fps = positional.count > 2 ? Double(positional[2])! : 15
let width = positional.count > 3 ? Int(positional[3])! : 0

let asset = AVURLAsset(url: input)
let duration = try await asset.load(.duration).seconds
let end = min(to ?? duration, duration)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

/// Crops [image] to [crop], scales it to [width] and draws it in sRGB, so
/// every frame has the same size and color space.
func prepare(_ image: CGImage) -> CGImage {
  var source = image
  if let crop, let cropped = image.cropping(to: crop) {
    source = cropped
  }
  let targetWidth = width > 0 ? width : source.width
  let targetHeight = Int(
    (Double(source.height) * Double(targetWidth) / Double(source.width)).rounded())
  let context = CGContext(
    data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8,
    bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  context.interpolationQuality = .high
  context.draw(source, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
  return context.makeImage()!
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let count = max(0, Int(((end - from) * fps).rounded(.down)))
let times = (0..<count).map { CMTime(seconds: from + Double($0) / fps, preferredTimescale: 600) }
let delay = Int((1000 / fps).rounded())
var frames: [[String: Any]] = []
var index = 0
// Requesting all the times at once lets the generator decode the video in
// order instead of seeking for every frame.
for await result in generator.images(for: times) {
  let image = try result.image
  let name = String(format: "frame_%04d.png", index)
  guard
    let destination = CGImageDestinationCreateWithURL(
      output.appendingPathComponent(name) as CFURL,
      UTType.png.identifier as CFString,
      1,
      nil
    )
  else {
    print("Cannot write \(name)")
    exit(1)
  }
  CGImageDestinationAddImage(destination, prepare(image), nil)
  CGImageDestinationFinalize(destination)
  frames.append(["file": name, "delay": delay])
  index += 1
}
let json = try JSONSerialization.data(withJSONObject: frames, options: [.prettyPrinted])
try json.write(to: output.appendingPathComponent("frames.json"))
print("Wrote \(index) frames to \(output.path)")
