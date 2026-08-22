import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

/// Embeds the PNGs in tool/frames_builtin/ into
/// lib/core/templates/builtin_frames.dart as base64 (downscaled to keep the
/// package small, alpha preserved so the transparent screen stays a hole).
///
/// Run: dart run tool/generate_builtin_frames.dart
void main() {
  const maxSide = 1200;
  final dir = Directory('tool/frames_builtin');
  final entries = <String>[];

  if (dir.existsSync()) {
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final name = f.uri.pathSegments.last;
      if (!RegExp(r'\.png$', caseSensitive: false).hasMatch(name)) continue;
      var im = img.decodePng(f.readAsBytesSync());
      if (im == null) {
        stderr.writeln('skip (not a PNG): $name');
        continue;
      }
      final longSide = im.width > im.height ? im.width : im.height;
      if (longSide > maxSide) {
        final s = maxSide / longSide;
        im = img.copyResize(im,
            width: (im.width * s).round(), height: (im.height * s).round());
      }
      final png = img.encodePng(im, level: 9);
      final label = name.replaceAll(RegExp(r'\.png$', caseSensitive: false), '');
      entries.add("  '${label.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}': "
          "'${base64.encode(png)}',");
      stdout.writeln('embedded: $label (${png.length ~/ 1024} KB)');
    }
  }

  File('lib/core/templates/builtin_frames.dart').writeAsStringSync('''// GENERATED CODE - DO NOT MODIFY BY HAND.
// Regenerate: dart run tool/generate_builtin_frames.dart
// Bundled device frames (PNG with transparent screen), base64-encoded.
// Source PNGs live in tool/frames_builtin/. See NOTICE for attribution.

/// Attribution shown in the editor for the bundled frames.
const String builtinFrameCredit =
    'Device frames © Apple Inc. Used with permission. Not affiliated with or endorsed by Apple.';

/// Frame label -> base64 PNG.
const Map<String, String> builtinFramesBase64 = <String, String>{
${entries.join('\n')}
};
''');
  stdout.writeln('Wrote lib/core/templates/builtin_frames.dart (${entries.length} frame(s)).');
}
