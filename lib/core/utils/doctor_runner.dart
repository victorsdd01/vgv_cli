import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// `vgv doctor` — checks the local toolchain the CLI (and generated projects)
/// rely on, and prints a concise status with install hints. Read-only.
class DoctorRunner {
  DoctorRunner({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  Future<int> run() async {
    _logger
      ..info('')
      ..info(styleBold.wrap('  vgv doctor — environment check')!)
      ..info('');

    // Core toolchain (needed to create/run projects).
    _logger.info(styleBold.wrap('  Core')!);
    final flutter = await _check('flutter', <String>['--version'],
        hint: 'Install Flutter: https://docs.flutter.dev/get-started/install');
    await _check('dart', <String>['--version'],
        hint: 'Bundled with Flutter (or install the Dart SDK).');
    await _check('git', <String>['--version'],
        hint: 'Install git: https://git-scm.com/downloads');

    // Optional toolchains (per feature).
    _logger
      ..info('')
      ..info(styleBold.wrap('  Optional')!);
    final python = await _check('python3', <String>['--version'],
        label: 'python3', suffix: '(vgv screenshots)',
        hint: 'macOS ships Python 3; otherwise: brew install python');
    if (python.ok) {
      await _checkPillow();
    } else {
      _row(false, 'Pillow', null, '(vgv screenshots) → python3 -m pip install --user pillow');
    }
    await _check('ruby', <String>['--version'],
        suffix: '(fastlane)', hint: 'macOS ships Ruby; otherwise: brew install ruby');
    await _check('bundle', <String>['--version'],
        label: 'bundler', suffix: '(fastlane)', hint: 'gem install bundler');
    await _check('lefthook', <String>['version'],
        suffix: '(git hooks)',
        hint: 'brew install lefthook  (or: dart pub global activate lefthook)');
    if (Platform.isMacOS) {
      await _check('pod', <String>['--version'],
          label: 'cocoapods', suffix: '(iOS/macOS builds)',
          hint: 'sudo gem install cocoapods');
    }

    _logger.info('');
    if (!flutter.ok) {
      _logger
        ..warn('Flutter was not found — the core generator needs it.')
        ..info('');
      return 1;
    }
    _logger
      ..info(green.wrap('  Core toolchain looks good.')!)
      ..info('');
    return 0;
  }

  Future<_Result> _check(
    String cmd,
    List<String> args, {
    String? label,
    String? suffix,
    String? hint,
  }) async {
    final name = label ?? cmd;
    try {
      final result = await Process.run(cmd, args, runInShell: true);
      if (result.exitCode == 0) {
        final version = _firstLine(result.stdout.toString()) ??
            _firstLine(result.stderr.toString());
        _row(true, name, version, suffix);
        return _Result(true, version);
      }
    } catch (_) {
      // fall through to "missing"
    }
    _row(false, name, null, suffix, hint: hint);
    return const _Result(false, null);
  }

  Future<void> _checkPillow() async {
    try {
      final result = await Process.run(
        'python3',
        <String>['-c', 'import PIL; print(PIL.__version__)'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        _row(true, 'Pillow', 'Pillow ${_firstLine(result.stdout.toString())}',
            '(vgv screenshots)');
        return;
      }
    } catch (_) {}
    _row(false, 'Pillow', null,
        '(vgv screenshots) → python3 -m pip install --user pillow');
  }

  void _row(bool ok, String name, String? version, String? suffix,
      {String? hint}) {
    final mark = ok ? green.wrap('✓')! : yellow.wrap('•')!;
    final tag = suffix == null ? '' : ' ${styleDim.wrap(suffix)}';
    final detail = ok
        ? styleDim.wrap(version ?? '')!
        : (hint != null ? styleDim.wrap('→ $hint')! : styleDim.wrap('not found')!);
    _logger.info('    $mark ${name.padRight(10)} $detail$tag');
  }

  String? _firstLine(String s) {
    for (final line in s.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }
}

class _Result {
  const _Result(this.ok, this.version);
  final bool ok;
  final String? version;
}
