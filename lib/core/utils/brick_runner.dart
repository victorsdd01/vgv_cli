import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import 'vgv_config.dart';

/// `vgv gen brick` — renders one of *your own* Mason bricks into the current
/// project, from any git repository.
///
/// vgv's built-in generators cover the conventions this CLI ships with; this
/// is the escape hatch for the bricks you maintain yourself. Rendering is
/// delegated to the `mason` CLI so bricks behave exactly as they do with
/// `mason make` (same prompts, same hooks).
class BrickRunner {
  BrickRunner({Logger? logger, bool? interactive})
      : _logger = logger ?? Logger(),
        _interactive = interactive ?? stdin.hasTerminal;

  final Logger _logger;
  final bool _interactive;

  /// `stdin.hasTerminal` can be true where prompting still fails: mason_logger
  /// throws StdinException (no echo mode) or StateError (stdout not attached).
  /// Prompts degrade to the non-interactive path instead of crashing.
  String? _ask(String message, {String? defaultValue}) {
    if (!_interactive) return null;
    try {
      return _logger.prompt(message, defaultValue: defaultValue);
    } on StdinException {
      return null;
    } on StateError {
      return null;
    }
  }

  String? _choose(String message, List<String> choices) {
    if (!_interactive) return null;
    try {
      return _logger.chooseOne(message, choices: choices);
    } on StdinException {
      return null;
    } on StateError {
      return null;
    }
  }

  Future<int> run(List<String> args) async {
    if (args.contains('-h') || args.contains('--help')) {
      usage(_logger);
      return 0;
    }

    String? url;
    String? ref;
    String? path;
    var output = '.';
    String? name;
    String? configPath;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      String? next() => i + 1 < args.length ? args[++i] : null;
      if (a == '--url') {
        url = next();
      } else if (a.startsWith('--url=')) {
        url = a.substring(6);
      } else if (a == '--ref') {
        ref = next();
      } else if (a.startsWith('--ref=')) {
        ref = a.substring(6);
      } else if (a == '--path') {
        path = next();
      } else if (a.startsWith('--path=')) {
        path = a.substring(7);
      } else if (a == '-c' || a == '--config') {
        configPath = next();
      } else if (a.startsWith('--config=')) {
        configPath = a.substring(9);
      } else if (a == '-o' || a == '--output') {
        output = next() ?? output;
      } else if (a.startsWith('--output=')) {
        output = a.substring(9);
      } else if (!a.startsWith('-')) {
        name ??= a;
      }
    }

    if (!await _hasMason()) {
      _logger
        ..err('The `mason` CLI was not found on your PATH.')
        ..info(styleDim.wrap('  Install it: dart pub global activate mason_cli'))
        ..info(styleDim.wrap('  vgv renders your bricks through mason so they '
            'behave exactly as with `mason make`.'));
      return 1;
    }

    // Defaults come from vgv.yaml / ~/.vgvrc so you only type the repo once.
    final config = VgvConfig.load();
    url ??= config.bricksUrl;
    ref ??= config.bricksRef;

    if (url == null || url.trim().isEmpty) {
      if (!_interactive) {
        _logger
          ..err('Missing the brick repository. Pass --url <git url>.')
          ..info(styleDim.wrap('  Tip: set `bricks.url` in vgv.yaml to skip this.'));
        return 1;
      }
      url = _ask('Brick repository (git URL):');
    }
    if (url == null || url.trim().isEmpty) {
      _logger.err('A git URL is required.');
      return 1;
    }
    ref ??= _ask('Branch or ref:', defaultValue: 'main') ?? 'main';

    // Discover the bricks in the repo so you can pick one by name.
    if (name == null) {
      final available = await _listBricks(url, ref);
      if (available.isEmpty) {
        if (!_interactive) {
          _logger.err('Missing the brick name. Pass it as the first argument.');
          return 1;
        }
        name = _ask('Brick name:');
      } else if (available.length == 1) {
        name = available.first;
        _logger.info(styleDim.wrap('  Using the only brick in the repo: $name')!);
      } else {
        name = _choose('Which brick?', available);
        if (name == null) {
          _logger
            ..err('Missing the brick name. Pass it as the first argument.')
            ..info(styleDim.wrap('  Available: ${available.join(', ')}'));
          return 1;
        }
      }
    }
    if (name == null || name.trim().isEmpty) {
      _logger.err('A brick name is required.');
      return 1;
    }
    // Bricks usually live in a folder named after themselves.
    path ??= name;

    _logger
      ..info('')
      ..info(styleBold.wrap(lightCyan.wrap('  🧱 $name'))!)
      ..info('  ${styleDim.wrap('$url  ($ref)')}')
      ..info('');

    // Added globally on purpose: a project-local `mason add` needs a
    // mason.yaml, and vgv should not drop mason scaffolding into your repo.
    // Remove first so re-running picks up the latest commit instead of
    // stopping on mason's "already added" prompt.
    await _runMason(<String>['remove', '-g', name], quiet: true);
    final added = await _runMason(<String>[
      'add', '-g', name, '--git-url', url, '--git-ref', ref, '--git-path', path,
    ]);
    if (added != 0) {
      _logger
        ..err('  Could not add the brick.')
        ..info(styleDim.wrap('  Check the URL, the ref, and that the brick '
            'lives at "$path" in the repo (override with --path).'));
      return added;
    }

    Directory(output).createSync(recursive: true);
    // `mason make` prompts for the brick's own variables, so it must inherit
    // this terminal rather than run captured.
    // A config file supplies the brick's variables, which is what makes this
    // usable from a script or CI; without one mason prompts for them.
    final made = await _runMason(<String>[
      'make', name, '-o', output,
      if (configPath != null) ...<String>['-c', configPath],
    ], attached: true);
    if (made != 0) {
      _logger.err('  Brick generation failed.');
      return made;
    }

    _logger
      ..info('')
      ..info(green.wrap('  ✓ Rendered $name into ${p.normalize(output)}')!)
      ..info('  ${styleDim.wrap('Reuse it: vgv gen brick $name')}')
      ..info('');
    return 0;
  }

  /// Top-level directories in the repo that contain a `brick.yaml`.
  Future<List<String>> _listBricks(String url, String ref) async {
    final tmp = Directory.systemTemp.createTempSync('vgv_bricks_');
    try {
      final clone = await Process.run('git', <String>[
        'clone', '--depth', '1', '--branch', ref, url, tmp.path,
      ], runInShell: true);
      if (clone.exitCode != 0) return const <String>[];
      final bricks = <String>[];
      for (final e in tmp.listSync().whereType<Directory>()) {
        final base = p.basename(e.path);
        if (base.startsWith('.')) continue;
        if (File(p.join(e.path, 'brick.yaml')).existsSync()) bricks.add(base);
      }
      // A repository can also be a single brick at its root.
      if (bricks.isEmpty && File(p.join(tmp.path, 'brick.yaml')).existsSync()) {
        return const <String>[];
      }
      bricks.sort();
      return bricks;
    } catch (_) {
      return const <String>[];
    } finally {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<bool> _hasMason() async {
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final r = await Process.run(which, <String>['mason'], runInShell: true);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<int> _runMason(List<String> args,
      {bool attached = false, bool quiet = false}) async {
    try {
      if (attached) {
        final proc = await Process.start('mason', args,
            runInShell: true, mode: ProcessStartMode.inheritStdio);
        return proc.exitCode;
      }
      final r = await Process.run('mason', args, runInShell: true);
      if (r.exitCode != 0 && !quiet) {
        final err = r.stderr.toString().trim();
        if (err.isNotEmpty) _logger.err(err);
      }
      return r.exitCode;
    } catch (e) {
      if (!quiet) _logger.err('Failed to run mason: $e');
      return 1;
    }
  }

  static void usage(Logger logger) {
    logger
      ..info('')
      ..info(styleBold.wrap('  vgv gen brick — render your own Mason brick'))
      ..info('')
      ..info('  ${lightCyan.wrap('vgv gen brick [name]')} ${styleDim.wrap('pick/render a brick from your repo')}')
      ..info('')
      ..info('  ${styleDim.wrap('--url <git>')}   brick repository (remembered in vgv.yaml)')
      ..info('  ${styleDim.wrap('--ref <ref>')}   branch or commit (default: main)')
      ..info('  ${styleDim.wrap('--path <dir>')}  brick folder in the repo (default: the name)')
      ..info('  ${styleDim.wrap('-o, --output')}  where to render (default: .)')
      ..info('  ${styleDim.wrap('-c, --config')}   JSON file with the brick variables (for CI)')
      ..info('')
      ..info(styleDim.wrap('  Omit the name to list the bricks in the repo and pick one.'))
      ..info(styleDim.wrap('  Set defaults in vgv.yaml:'))
      ..info(styleDim.wrap('    bricks:'))
      ..info(styleDim.wrap('      url: https://github.com/you/your_bricks'))
      ..info(styleDim.wrap('      ref: main'))
      ..info('')
      ..info(styleDim.wrap('  Requires the mason CLI: dart pub global activate mason_cli'))
      ..info('');
  }
}
