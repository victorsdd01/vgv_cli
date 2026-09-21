import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';

import '../templates/dependency_versions.dart';

/// `vgv deps` — audits the package versions the CLI pins into generated
/// projects against the latest published on pub.dev.
///
/// Pins are deliberate: the newest release of a package often needs a newer
/// Dart SDK than the Flutter version most people run, so this reports what has
/// fallen behind instead of silently upgrading.
class DepsRunner {
  DepsRunner({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  Future<int> run(List<String> args) async {
    if (args.contains('-h') || args.contains('--help')) {
      _usage();
      return 0;
    }

    final pinned = kAllPinnedVersions;
    _logger
      ..info('')
      ..info(styleBold.wrap(lightCyan.wrap('  📦 Pinned dependency versions'))!)
      ..info('  ${styleDim.wrap('${pinned.length} packages · comparing with pub.dev')}')
      ..info('');

    final progress = _logger.progress('Checking pub.dev');
    final outdated = <_Outdated>[];
    var checked = 0;
    var unreachable = 0;

    for (final entry in pinned.entries) {
      final latest = await _latestVersion(entry.key);
      checked++;
      progress.update('Checked $checked / ${pinned.length}');
      if (latest == null) {
        unreachable++;
        continue;
      }
      final current = entry.value.replaceAll('^', '');
      if (_isNewer(latest, current)) {
        outdated.add(_Outdated(entry.key, current, latest));
      }
    }
    progress.complete('Checked ${pinned.length} package(s)');
    _logger.info('');

    if (outdated.isEmpty) {
      _logger
        ..info(green.wrap('  ✓ Every pinned version is current.')!)
        ..info('');
      return 0;
    }

    final width = outdated.map((o) => o.name.length).reduce((a, b) => a > b ? a : b);
    _logger.info(styleBold.wrap('  Behind latest')!);
    for (final o in outdated) {
      _logger.info('    ${o.name.padRight(width)}  '
          '${styleDim.wrap(o.pinned)} → ${yellow.wrap(o.latest)}');
    }
    _logger
      ..info('')
      ..info(styleDim.wrap(
          '  Pins live in lib/core/templates/dependency_versions.dart.'))
      ..info(styleDim.wrap(
          '  Before bumping a major, check it still resolves against the Flutter'))
      ..info(styleDim.wrap(
          '  SDK you target — a newer release may require a newer Dart SDK.'));
    if (unreachable > 0) {
      _logger.info(styleDim.wrap('  ($unreachable package(s) could not be checked.)'));
    }
    _logger.info('');
    return 0;
  }

  Future<String?> _latestVersion(String package) async {
    try {
      final res = await http
          .get(Uri.parse('https://pub.dev/api/packages/$package'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = data['latest'] as Map<String, dynamic>?;
      return latest?['version'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Semver-ish comparison that ignores build metadata and treats a
  /// pre-release as older than the matching stable.
  static bool _isNewer(String candidate, String current) {
    final a = _parts(candidate);
    final b = _parts(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static List<int> _parts(String v) {
    final core = v.split(RegExp('[-+]')).first;
    final nums = core.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums;
  }

  void _usage() {
    _logger
      ..info('')
      ..info(styleBold.wrap('  vgv deps — audit the pinned dependency versions'))
      ..info('')
      ..info('  ${lightCyan.wrap('vgv deps')}  ${styleDim.wrap('compare the CLI\'s pins with pub.dev')}')
      ..info('')
      ..info(styleDim.wrap('  These are the versions written into a new project\'s pubspec.'))
      ..info('');
  }
}

class _Outdated {
  const _Outdated(this.name, this.pinned, this.latest);
  final String name;
  final String pinned;
  final String latest;
}
