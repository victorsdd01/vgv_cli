import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import 'screenshot_web.dart' show defaultFramesDir;

/// `vgv screenshots frames <source>` — builds a local frame library at
/// ~/.vgv/frames from the device bezels you downloaded (e.g. Apple Product
/// Bezels). The editor (`vgv screenshots web`) auto-loads that folder, so you
/// get every frame at full quality without bloating the published package.
///
/// `<source>` is a folder that contains either:
///   • `.dmg` files (macOS Apple Product Bezels) — mounted and their PNGs pulled, or
///   • `.png` device frames (transparent screen) — copied directly.
class FramesExtractor {
  FramesExtractor({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  Future<int> run(List<String> args) async {
    final positional = <String>[];
    String? outArg;
    var maxSide = 2000;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == '-h' || a == '--help') {
        _usage();
        return 0;
      } else if (a == '--out') {
        outArg = i + 1 < args.length ? args[++i] : null;
      } else if (a == '--max') {
        maxSide = int.tryParse(i + 1 < args.length ? args[++i] : '') ?? maxSide;
      } else if (a.startsWith('--out=')) {
        outArg = a.substring('--out='.length);
      } else if (a.startsWith('--max=')) {
        maxSide = int.tryParse(a.substring('--max='.length)) ?? maxSide;
      } else {
        positional.add(a);
      }
    }

    if (positional.isEmpty) {
      _usage();
      return 1;
    }

    final source = positional.first;
    if (!Directory(source).existsSync()) {
      _logger.err('Source folder not found: $source');
      return 1;
    }

    final outDir = outArg ?? defaultFramesDir();
    Directory(outDir).createSync(recursive: true);

    final dmgs = Directory(source)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.dmg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final loosePngs = Directory(source)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList();

    if (dmgs.isEmpty && loosePngs.isEmpty) {
      _logger
        ..err('No .dmg or .png frames found in: $source')
        ..info(styleDim.wrap('  Point it at a folder of Apple Product Bezel .dmg files '
            'or device-frame PNGs.'));
      return 1;
    }
    if (dmgs.isNotEmpty && !Platform.isMacOS) {
      _logger.info(styleDim.wrap(
          '  .dmg mounting needs macOS — copying loose .png frames only.'));
    }

    _logger
      ..info('')
      ..info(styleBold.wrap(lightCyan.wrap('  🖼  Building frame library'))!)
      ..info('  ${styleDim.wrap('→ $outDir')}')
      ..info('');

    var count = 0;
    final progress = _logger.progress('Extracting frames');

    // Loose PNGs first.
    for (final png in loosePngs) {
      if (_processPng(png.readAsBytesSync(), p.basename(png.path), outDir, maxSide)) {
        count++;
      }
    }

    // DMGs (macOS only).
    if (Platform.isMacOS) {
      for (final dmg in dmgs) {
        final mount = Directory.systemTemp
            .createTempSync('vgv_bezel_')
            .path;
        try {
          final ok = await _attach(dmg.path, mount);
          if (!ok) {
            _logger.warn('  Skipped (could not mount): ${p.basename(dmg.path)}');
            continue;
          }
          for (final f in Directory(mount)
              .listSync(recursive: true)
              .whereType<File>()) {
            final lower = f.path.toLowerCase();
            if (!lower.endsWith('.png')) continue;
            // Apple bezels live under a PNG/ folder; skip icons/backgrounds.
            if (!lower.contains('${Platform.pathSeparator}png${Platform.pathSeparator}')) {
              continue;
            }
            if (_processPng(f.readAsBytesSync(), p.basename(f.path), outDir, maxSide)) {
              count++;
            }
          }
        } finally {
          await _detach(mount);
          try {
            Directory(mount).deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    }

    progress.complete('Extracted $count frame(s)');
    _logger
      ..info('')
      ..info(green.wrap('  ✓ Frame library ready: $count frames in $outDir')!)
      ..info('  ${styleDim.wrap('Open the editor: vgv screenshots web')}')
      ..info('  ${styleDim.wrap('They appear automatically, filtered by the selected device.')}')
      ..info('');
    return 0;
  }

  /// Decode, downscale (alpha preserved), and write a PNG into [outDir].
  bool _processPng(Uint8List bytes, String name, String outDir, int maxSide) {
    try {
      var im = img.decodePng(bytes);
      if (im == null) return false;
      final longSide = im.width > im.height ? im.width : im.height;
      if (longSide > maxSide) {
        final s = maxSide / longSide;
        im = img.copyResize(im,
            width: (im.width * s).round(), height: (im.height * s).round());
      }
      File(p.join(outDir, name)).writeAsBytesSync(img.encodePng(im, level: 6));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mount a .dmg read-only, auto-accepting the software license agreement.
  Future<bool> _attach(String dmg, String mount) async {
    try {
      final r = await Process.run('sh', <String>[
        '-c',
        "printf 'Y\\n' | hdiutil attach '$dmg' -readonly -nobrowse -mountpoint '$mount'",
      ]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _detach(String mount) async {
    try {
      await Process.run('hdiutil', <String>['detach', mount, '-quiet']);
    } catch (_) {}
  }

  void _usage() {
    _logger
      ..info('')
      ..info(styleBold.wrap('  vgv screenshots frames — build a local frame library'))
      ..info('')
      ..info('  ${lightCyan.wrap('vgv screenshots frames <source-dir>')} ${styleDim.wrap('extract frames → ~/.vgv/frames')}')
      ..info('')
      ..info('  ${styleDim.wrap('<source-dir>')} a folder with Apple Product Bezel .dmg files (macOS)')
      ..info('  ${styleDim.wrap('             ')} and/or device-frame .png files (transparent screen).')
      ..info('  ${styleDim.wrap('--out <dir>')}  where to write (default: ~/.vgv/frames).')
      ..info('  ${styleDim.wrap('--max <px>')}   max long side, downscaled (default: 2000).')
      ..info('')
      ..info(styleDim.wrap('  The editor (vgv screenshots web) auto-loads ~/.vgv/frames,'))
      ..info(styleDim.wrap('  full quality, without bloating the published package.'))
      ..info('');
  }
}
