import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../templates/builtin_frames.dart';
import '../templates/screenshot_editor_html.dart';

/// The local frame library the editor auto-loads: `~/.vgv/frames`.
/// Populated by `vgv screenshots frames`. Full-quality frames without
/// bloating the published package.
String defaultFramesDir() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;
  return p.join(home, '.vgv', 'frames');
}

/// `vgv screenshots web` — serves the in-browser Canvas editor from a tiny
/// local server (no Python, no login). The browser renders + previews; on
/// "Save to project" it POSTs the PNG back and the server writes it to `out/`.
class ScreenshotWebServer {
  ScreenshotWebServer({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  Future<int> run(List<String> args) async {
    final parser = ArgParser()
      ..addOption('raw', help: 'Folder of raw screenshots to pick from.')
      ..addOption('out', help: 'Folder to save framed PNGs (default: out).')
      ..addOption('port', help: 'Port (default: an open one).')
      ..addOption('frames',
          help: 'Folder of device-frame PNGs (transparent screen) to offer as '
              'real frames — e.g. Apple Product Bezels you downloaded locally.')
      ..addFlag('open', defaultsTo: true, help: 'Open the browser automatically.');

    final ArgResults res;
    try {
      res = parser.parse(args);
    } on FormatException catch (e) {
      _logger.err(e.message);
      return 1;
    }

    final rawDir = res['raw'] as String?;
    final framesDir = res['frames'] as String?;
    // Local frame library auto-loaded from ~/.vgv/frames (populated by
    // `vgv screenshots frames`). Full-quality frames without bloating the pkg.
    final libDir = defaultFramesDir();
    final outDir = (res['out'] as String?) ?? 'out';
    Directory(outDir).createSync(recursive: true);

    final port = int.tryParse((res['port'] as String?) ?? '') ?? 0;
    final html = utf8.decode(base64.decode(screenshotEditorHtmlBase64));

    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } catch (e) {
      _logger.err('Could not start the local server: $e');
      return 1;
    }

    final url = 'http://127.0.0.1:${server.port}';
    _logger
      ..info('')
      ..info('  ${styleBold.wrap(lightCyan.wrap('📸 Screenshot editor'))}')
      ..info('  ${lightCyan.wrap(url)}  ${styleDim.wrap('— edit, then "Save to project"')}')
      ..info('  ${styleDim.wrap('Saves to: $outDir/   •   Press Ctrl+C to stop')}')
      ..info('');

    if (res['open'] as bool) _openBrowser(url);

    await for (final request in server) {
      try {
        await _handle(request, html, rawDir, framesDir, libDir, outDir);
      } catch (_) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    }
    return 0;
  }

  Future<void> _handle(
    HttpRequest req,
    String html,
    String? rawDir,
    String? framesDir,
    String libDir,
    String outDir,
  ) async {
    final res = req.response;
    final path = req.uri.path;

    if (path == '/' || path == '/index.html') {
      res.headers.contentType = ContentType.html;
      res.write(html);
      await res.close();
      return;
    }

    if (path == '/api/raw') {
      final images = <Map<String, String>>[];
      if (rawDir != null && Directory(rawDir).existsSync()) {
        for (final f in Directory(rawDir).listSync().whereType<File>()) {
          final name = p.basename(f.path);
          if (_isImage(name)) {
            images.add(<String, String>{'name': name, 'url': '/raw/$name'});
          }
        }
      }
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(<String, dynamic>{'images': images}));
      await res.close();
      return;
    }

    if (path == '/api/frames') {
      final images = <Map<String, String>>[];
      final seen = <String>{};
      // User-provided (--frames) first, then the local library (~/.vgv/frames);
      // both are real Apple/Google bezels the user placed → credited.
      for (final dir in <String?>[framesDir, libDir]) {
        if (dir == null || !Directory(dir).existsSync()) continue;
        for (final f in Directory(dir).listSync().whereType<File>()) {
          final name = p.basename(f.path);
          if (!_isImage(name) || !seen.add(name)) continue;
          images.add(<String, String>{
            'name': _labelFor(name),
            'url': '/frames/${Uri.encodeComponent(name)}',
            'credit': builtinFrameCredit,
          });
        }
      }
      // Built-in bundled frames last (credited).
      var i = 0;
      for (final name in builtinFramesBase64.keys) {
        if (seen.add('$name.png')) {
          images.add(<String, String>{
            'name': name,
            'url': '/builtin/$i',
            'credit': builtinFrameCredit,
          });
        }
        i++;
      }
      images.sort((a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()));
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(<String, dynamic>{'images': images}));
      await res.close();
      return;
    }

    if (path.startsWith('/builtin/')) {
      final i = int.tryParse(p.basename(path));
      final values = builtinFramesBase64.values.toList();
      if (i != null && i >= 0 && i < values.length) {
        res.headers.contentType = ContentType('image', 'png');
        res.add(base64.decode(values[i]));
        await res.close();
        return;
      }
    }

    if (path.startsWith('/raw/') && rawDir != null) {
      final file = File(p.join(rawDir, p.basename(Uri.decodeComponent(path))));
      if (file.existsSync()) {
        res.headers.contentType = ContentType('image', 'png');
        await res.addStream(file.openRead());
        await res.close();
        return;
      }
    }

    if (path.startsWith('/frames/')) {
      final name = p.basename(Uri.decodeComponent(path));
      for (final dir in <String?>[framesDir, libDir]) {
        if (dir == null) continue;
        final file = File(p.join(dir, name));
        if (file.existsSync()) {
          res.headers.contentType = ContentType('image', 'png');
          await res.addStream(file.openRead());
          await res.close();
          return;
        }
      }
    }

    if (path == '/api/save' && req.method == 'POST') {
      final body = await utf8.decoder.bind(req).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final name = p.basename((data['name'] as String?) ?? 'shot.png');
      final dataUrl = (data['dataUrl'] as String?) ?? '';
      final comma = dataUrl.indexOf(',');
      final bytes = base64.decode(comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl);
      final outPath = p.join(outDir, name);
      File(outPath).writeAsBytesSync(bytes);
      _logger.info('  ${green.wrap('✓')} saved $outPath');
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(<String, dynamic>{'ok': true, 'path': outPath}));
      await res.close();
      return;
    }

    res.statusCode = HttpStatus.notFound;
    await res.close();
  }

  bool _isImage(String name) =>
      RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false).hasMatch(name);

  String _labelFor(String fileName) =>
      fileName.replaceAll(RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false), '');

  void _openBrowser(String url) {
    try {
      if (Platform.isMacOS) {
        Process.run('open', <String>[url]);
      } else if (Platform.isWindows) {
        Process.run('cmd', <String>['/c', 'start', url], runInShell: true);
      } else {
        Process.run('xdg-open', <String>[url]);
      }
    } catch (_) {
      // User can open the URL manually.
    }
  }
}
