// Extracts PNG frames from a screen recording, for make_demo_gif.dart.
//
//   swift tool/extract_frames.swift <recording.mov> <frames folder> [fps] [width]
//
// Record with Cmd+Shift+5 ("Record Selected Portion") on macOS. The frames
// are sampled at [fps] (default 15) and scaled to [width] pixels (default:
// the recording's width). A frames.json file lists them with their delays.
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
  print("Usage: swift tool/extract_frames.swift <recording.mov> <frames folder> [fps] [width]")
  exit(64)
}
let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
let fps = arguments.count > 3 ? Double(arguments[3])! : 15
let width = arguments.count > 4 ? Double(arguments[4])! : 0

let asset = AVURLAsset(url: input)
let duration = try await asset.load(.duration).seconds
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
if width > 0 {
  // A zero height keeps the aspect ratio.
  generator.maximumSize = CGSize(width: width, height: 0)
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let count = Int((duration * fps).rounded(.down))
let delay = Int((1000 / fps).rounded())
var frames: [[String: Any]] = []
for index in 0..<count {
  let time = CMTime(seconds: Double(index) / fps, preferredTimescale: 600)
  let (image, _) = try await generator.image(at: time)
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
  CGImageDestinationAddImage(destination, image, nil)
  CGImageDestinationFinalize(destination)
  frames.append(["file": name, "delay": delay])
}
let json = try JSONSerialization.data(withJSONObject: frames, options: [.prettyPrinted])
try json.write(to: output.appendingPathComponent("frames.json"))
print("Wrote \(count) frames to \(output.path)")
