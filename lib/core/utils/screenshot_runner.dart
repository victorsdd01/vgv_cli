import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../templates/screenshot_script.dart';

/// Runs `vgv screenshots`: frames raw app screenshots into store-ready
/// marketing posters via the bundled Pillow script. Works on ANY Flutter
/// project (input = raw PNGs + a manifest); no dependency on the vgv template.
class ScreenshotRunner {
  ScreenshotRunner({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.first == '-h' || args.first == '--help') {
      _usage();
      return args.isEmpty ? 1 : 0;
    }
    if (args.first == '--init') {
      _init(args.length > 1 ? args[1] : 'store_screenshots');
      return 0;
    }

    final manifest = args.first;
    if (!File(manifest).existsSync()) {
      _logger
        ..err('Manifest not found: $manifest')
        ..info(styleDim.wrap('  Create one with: vgv screenshots --init'));
      return 1;
    }

    // Tooling: python3 + Pillow (we don't auto-install — instruct instead).
    if (!await _has('python3')) {
      _logger
        ..err('python3 was not found on your PATH.')
        ..info(styleDim.wrap('  macOS ships Python 3. Otherwise: brew install python'));
      return 1;
    }
    final pillow = await Process.run(
        'python3', ['-c', 'import PIL'], runInShell: true);
    if (pillow.exitCode != 0) {
      _logger
        ..err('Python Pillow is not installed.')
        ..info(styleDim.wrap('  Install it: python3 -m pip install --user pillow'));
      return 1;
    }

    // Write the bundled script to a temp file and run it.
    final script = File(p.join(Directory.systemTemp.path, 'vgv_frame_screenshots.py'));
    script.writeAsBytesSync(base64.decode(frameScreenshotsPyBase64));

    _logger.info(styleBold.wrap(lightCyan.wrap('  📸 Rendering store screenshots…')));
    final result = await Process.run(
        'python3', [script.path, 'manifest', manifest], runInShell: true);

    if (result.exitCode == 0) {
      for (final line in result.stdout.toString().trim().split('\n')) {
        if (line.trim().isNotEmpty) _logger.info('    ${green.wrap('✓')} $line');
      }
      _logger
        ..info('')
        ..info(green.wrap('  Done — store-ready posters generated.'))
        ..info('');
    } else {
      _logger
        ..err('  Screenshot generation failed:')
        ..err(result.stderr.toString());
    }
    return result.exitCode;
  }

  Future<bool> _has(String cmd) async {
    try {
      final r = await Process.run('which', [cmd], runInShell: true);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _init(String dir) {
    Directory(p.join(dir, 'raw')).createSync(recursive: true);
    Directory(p.join(dir, 'out')).createSync(recursive: true);
    final manifest = File(p.join(dir, 'manifest.json'));
    manifest.writeAsStringSync('''[
  {
    "device": "iphone",
    "type": "hero",
    "src": "raw/icon.png",
    "out": "out/00_hero.png",
    "headline": "Your app, **beautifully** framed",
    "subtitle": "Say what makes it great.",
    "accent": "#39D6E0"
  },
  {
    "device": "iphone",
    "type": "poster",
    "src": "raw/01.png",
    "out": "out/01.png",
    "headline": "A **clear** headline here",
    "subtitle": "One line of supporting copy.",
    "accent": "#39D6E0"
  },
  {
    "device": "android",
    "type": "poster",
    "src": "raw/01.png",
    "out": "out/01_android.png",
    "headline": "Also on **Android**",
    "subtitle": "Same engine, Android frame.",
    "accent": "#7C4DFF",
    "bg": "#141018"
  }
]
''');
    File(p.join(dir, 'README.md')).writeAsStringSync('''# Store screenshots

1. Drop your raw app screenshots in `raw/` (e.g. `raw/01.png`, `raw/icon.png`).
2. Edit `manifest.json`:
   - `device`: iphone | android | ipad | macbook | desktop
   - `type`: poster (frame + text) | hero (app icon + tagline) | frame (frame only)
   - `headline`: wrap words in **double asterisks** to paint them with `accent`.
   - `accent` / `bg`: hex colors (bg optional; defaults to a tint of accent).
3. Render:
   ```bash
   vgv screenshots $dir/manifest.json
   ```
   Framed, store-ready PNGs land in `out/`.

Requires Python 3 + Pillow (`python3 -m pip install --user pillow`).
''');
    _logger
      ..info('')
      ..info(green.wrap('  Scaffolded $dir/'))
      ..info('    ${styleDim.wrap('raw/')}         drop your screenshots here')
      ..info('    ${styleDim.wrap('manifest.json')} edit headlines/devices/colors')
      ..info('    ${styleDim.wrap('out/')}         rendered posters')
      ..info('')
      ..info('  Then: ${lightCyan.wrap('vgv screenshots $dir/manifest.json')}')
      ..info('');
  }

  void _usage() {
    _logger
      ..info('')
      ..info(styleBold.wrap('  vgv screenshots — store marketing screenshots'))
      ..info('')
      ..info('  ${lightCyan.wrap('vgv screenshots --init [dir]')}   ${styleDim.wrap('scaffold a manifest + folders')}')
      ..info('  ${lightCyan.wrap('vgv screenshots <manifest>')}     ${styleDim.wrap('render framed posters from a manifest')}')
      ..info('')
      ..info(styleDim.wrap('  Frames iPhone/Android/iPad/MacBook/desktop with backgrounds and'))
      ..info(styleDim.wrap('  headlines. Requires Python 3 + Pillow.'))
      ..info('');
  }
}
