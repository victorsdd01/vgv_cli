import 'dart:convert';
import 'dart:io';

/// Embeds tool/frame_screenshots.py into lib/core/templates/screenshot_script.dart
/// as a base64 constant (single source of truth = the .py), so the globally
/// activated CLI can write it to a temp file and run it. Base64 avoids any
/// string-escaping pitfalls.
///
/// Run: dart run tool/generate_screenshot_script.dart
void main() {
  final py = File('tool/frame_screenshots.py');
  if (!py.existsSync()) {
    stderr.writeln('tool/frame_screenshots.py not found (run from package root).');
    exit(1);
  }
  final b64 = base64.encode(py.readAsBytesSync());
  final out = File('lib/core/templates/screenshot_script.dart')
    ..parent.createSync(recursive: true);
  out.writeAsStringSync('''// GENERATED CODE - DO NOT MODIFY BY HAND.
// Regenerate with: dart run tool/generate_screenshot_script.dart
// Source: tool/frame_screenshots.py

/// The Pillow screenshot-framing script, base64-encoded.
const String frameScreenshotsPyBase64 =
    '$b64';
''');
  stdout.writeln('Wrote lib/core/templates/screenshot_script.dart (${b64.length} b64 chars)');
}
