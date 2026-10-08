// Turns the frames extracted from a screen recording by
// tool/extract_frames.swift into an animated GIF.
//
//   dart run tool/make_demo_gif.dart <frames folder> <output.gif> [width]
//
// Every frame shares one palette, so the parts of the screen that do not
// change encode identically and an optimizer can drop them. Optimize the
// result afterwards, for example:
//
//   gifsicle -O3 --lossy=30 demo.gif -o demo.gif
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/make_demo_gif.dart <frames folder> <output.gif> '
      '[width]',
    );
    exit(64);
  }
  final Directory folder = Directory(args[0]);
  final File output = File(args[1]);
  final int? width = args.length > 2 ? int.parse(args[2]) : null;

  final List<Map<String, Object?>> manifest =
      (jsonDecode(File('${folder.path}/frames.json').readAsStringSync())
              as List<Object?>)
          .cast<Map<String, Object?>>();

  img.Image load(Map<String, Object?> frame) {
    final img.Image image = img.decodePng(
      File('${folder.path}/${frame['file']}').readAsBytesSync(),
    )!;
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
  const int samples = 10;
  final List<img.Image> sampled = <img.Image>[
    for (int i = 0; i < samples; i++)
      load(manifest[(i * (manifest.length - 1) / (samples - 1)).round()]),
  ];
  final img.Image montage = img.Image(
    width: sampled.first.width,
    height: sampled.first.height * samples,
  );
  for (int i = 0; i < samples; i++) {
    img.compositeImage(montage, sampled[i], dstY: i * sampled.first.height);
  }
  final img.NeuralQuantizer palette = img.NeuralQuantizer(
    montage,
    samplingFactor: 4,
  );

  final img.GifEncoder encoder = img.GifEncoder();
  for (final Map<String, Object?> frame in manifest) {
    final img.Image image = load(frame);
    if (image.width != sampled.first.width ||
        image.height != sampled.first.height) {
      stderr.writeln(
        '${frame['file']} is ${image.width}x${image.height}, not '
        '${sampled.first.width}x${sampled.first.height}. Every frame must '
        'have the same size.',
      );
      exit(1);
    }
    final img.Image indexed = img.ditherImage(
      image,
      quantizer: palette,
      kernel: img.DitherKernel.none,
    );
    // GIF delays are in hundredths of a second.
    encoder.addFrame(
      indexed,
      duration: ((frame['delay']! as int) / 10).round(),
    );
  }
  output.writeAsBytesSync(encoder.finish()!);
  stdout.writeln('Wrote ${output.path} (${manifest.length} frames)');
}
