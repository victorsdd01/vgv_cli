import 'dart:convert';
import 'dart:io';

/// Embeds tool/screenshot_editor.html into
/// lib/core/templates/screenshot_editor_html.dart as a base64 constant, so the
/// globally activated CLI can serve the editor from its local web server.
///
/// Run: dart run tool/generate_editor_html.dart
void main() {
  final html = File('tool/screenshot_editor.html');
  if (!html.existsSync()) {
    stderr.writeln('tool/screenshot_editor.html not found (run from package root).');
    exit(1);
  }
  final b64 = base64.encode(html.readAsBytesSync());
  File('lib/core/templates/screenshot_editor_html.dart').writeAsStringSync(
    '''// GENERATED CODE - DO NOT MODIFY BY HAND.
// Regenerate with: dart run tool/generate_editor_html.dart
// Source: tool/screenshot_editor.html

/// The screenshot editor page (HTML/CSS/JS/Canvas), base64-encoded.
const String screenshotEditorHtmlBase64 =
    '$b64';
''',
  );
  stdout.writeln('Wrote lib/core/templates/screenshot_editor_html.dart (${b64.length} b64 chars)');
}
