// Turns the frames extracted from a screen recording by
// tool/extract_frames.swift into an animated GIF.
//
//   dart run tool/make_demo_gif.dart <frames folder> <output.gif> [options]
//
// Options:
//   --width=PIXELS   scale the frames to this width (default: their width)
//   --speed=FACTOR   play the recording faster, for example 1.25 (default: 1)
//   --max-idle=MS    the longest a frame stays on screen when nothing moves;
//                    longer pauses are shortened to this (default: 1500)
//   --noise=N        8x8 blocks whose average change is at most N (0-255)
//                    and whose pixels change by at most 8N keep the previous
//                    frame's pixels. This removes video compression noise,
//                    so pauses compress well and can be shortened (default:
//                    3, 0 turns it off)
//
// Every frame shares one palette, so the parts of the screen that do not
// change encode identically and an optimizer can drop them. Optimize the
// result afterwards, losslessly:
//
//   gifsicle -O3 demo.gif -o demo.gif
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const int _block = 8;

void main(List<String> args) {
  final List<String> positional = <String>[];
  final Map<String, String> options = <String, String>{};
  for (final String arg in args) {
    final int split = arg.indexOf('=');
    if (arg.startsWith('--') && split > 0) {
      options[arg.substring(2, split)] = arg.substring(split + 1);
    } else {
      positional.add(arg);
    }
  }
  if (positional.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/make_demo_gif.dart <frames folder> <output.gif> '
      '[--width=PIXELS] [--speed=FACTOR] [--max-idle=MS] [--noise=N]',
    );
    exit(64);
  }
  final Directory folder = Directory(positional[0]);
  final File output = File(positional[1]);
  final int? width = int.tryParse(options['width'] ?? '');
  final double speed = double.parse(options['speed'] ?? '1');
  final double maxIdle = double.parse(options['max-idle'] ?? '1500');
  final int noise = int.parse(options['noise'] ?? '3');

  final List<Map<String, Object?>> manifest =
      (jsonDecode(File('${folder.path}/frames.json').readAsStringSync())
              as List<Object?>)
          .cast<Map<String, Object?>>();

  img.Image load(Map<String, Object?> frame) {
    img.Image image = img.decodePng(
      File('${folder.path}/${frame['file']}').readAsBytesSync(),
    )!;
    if (image.numChannels != 3 || image.bitsPerChannel != 8) {
      image = image.convert(format: img.Format.uint8, numChannels: 3);
    }
    if (width == null || image.width == width) {
      return image;
    }
    return img.copyResize(
      image,
      width: width,
      interpolation: img.Interpolation.average,
    );
  }

  // Build one palette from frames spread over the whole recording.
  final int samples = manifest.length < 16 ? manifest.length : 16;
  final List<img.Image> sampled = <img.Image>[
    for (int i = 0; i < samples; i++)
      load(
        manifest[samples == 1
            ? 0
            : (i * (manifest.length - 1) / (samples - 1)).round()],
      ),
  ];
  final int frameWidth = sampled.first.width;
  final int frameHeight = sampled.first.height;
  final img.Image montage = img.Image(
    width: frameWidth,
    height: frameHeight * samples,
  );
  for (int i = 0; i < samples; i++) {
    img.compositeImage(montage, sampled[i], dstY: i * frameHeight);
  }
  final img.NeuralQuantizer palette = img.NeuralQuantizer(
    montage,
    samplingFactor: 4,
  );

  final img.GifEncoder encoder = img.GifEncoder();
  Uint8List? previous;
  img.Image? pending;
  double pendingStart = 0;
  double pendingLength = 0;
  double written = 0;
  int count = 0;

  // GIF delays are in hundredths of a second. Rounding the end time instead
  // of each delay keeps the total length exact.
  void flush() {
    final img.Image? frame = pending;
    if (frame == null) {
      return;
    }
    final double end = pendingStart + pendingLength;
    final int delay = (end / 10).round() - (written / 10).round();
    if (delay > 0) {
      encoder.addFrame(frame, duration: delay);
      written = end;
      count++;
    }
    pending = null;
  }

  double time = 0;
  for (final Map<String, Object?> frame in manifest) {
    final img.Image image = load(frame);
    if (image.width != frameWidth || image.height != frameHeight) {
      stderr.writeln(
        '${frame['file']} is ${image.width}x${image.height}, not '
        '${frameWidth}x$frameHeight. Every frame must have the same size.',
      );
      exit(1);
    }
    final double length = (frame['delay']! as int) / speed;
    final Uint8List pixels = image.toUint8List();
    final bool changed = previous == null ||
        _stabilize(pixels, previous, frameWidth, frameHeight, noise);
    previous = Uint8List.fromList(pixels);
    if (changed) {
      flush();
      pending = img.ditherImage(
        image,
        quantizer: palette,
        kernel: img.DitherKernel.none,
      );
      pendingStart = time;
      pendingLength = length;
      time += length;
    } else {
      // Nothing moved: show the previous frame longer, up to --max-idle.
      final double extra =
          (pendingLength + length).clamp(0.0, maxIdle) - pendingLength;
      if (extra > 0) {
        pendingLength += extra;
        time += extra;
      }
    }
  }
  flush();
  output.writeAsBytesSync(encoder.finish()!);
  stdout.writeln(
    'Wrote ${output.path}: $count frames, ${frameWidth}x$frameHeight, '
    '${(written / 1000).toStringAsFixed(1)} s',
  );
}

/// Copies the 8x8 blocks of [pixels] (RGB) that differ from [previous] by at
/// most [noise] on average, and by at most eight times that in every channel,
/// from [previous]. Returns whether any block changed by more.
bool _stabilize(
  Uint8List pixels,
  Uint8List previous,
  int width,
  int height,
  int noise,
) {
  bool changed = false;
  final int stride = width * 3;
  final int peak = noise * 8;
  for (int top = 0; top < height; top += _block) {
    final int bottom = top + _block < height ? top + _block : height;
    for (int left = 0; left < width; left += _block) {
      final int right = left + _block < width ? left + _block : width;
      int sum = 0;
      bool same = true;
      for (int y = top; y < bottom && same; y++) {
        final int end = y * stride + right * 3;
        for (int i = y * stride + left * 3; i < end; i++) {
          final int difference = (pixels[i] - previous[i]).abs();
          if (difference > peak) {
            same = false;
            break;
          }
          sum += difference;
        }
      }
      if (same && sum > noise * (bottom - top) * (right - left) * 3) {
        same = false;
      }
      if (same) {
        for (int y = top; y < bottom; y++) {
          final int start = y * stride + left * 3;
          pixels.setRange(start, y * stride + right * 3, previous, start);
        }
      } else {
        changed = true;
      }
    }
  }
  return changed;
}
