import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/entities/project_config.dart';

/// Rewrites the generated Material 3 theme to seed its `ColorScheme` from the
/// brand color the user chose (`ColorScheme.fromSeed`). No-op when unset.
class ThemeSeedGenerator {
  const ThemeSeedGenerator();

  /// Path of the theme this rewrites, relative to the project root.
  static const String themePath = 'lib/application/theme/theme.dart';

  /// Returns whether a seed color was written. Replaces whatever `seedColor:`
  /// the theme has (the template's `Colors.blue` or a previous brand color),
  /// so it can be re-applied by `vgv add seed`.
  Future<bool> generate(ProjectConfig config) async {
    final hex = config.seedColorHex;
    if (hex == null || hex.isEmpty) return false;
    final file = File(path.join(config.projectName, themePath));
    if (!file.existsSync()) return false;
    final source = file.readAsStringSync();
    final seed = RegExp(r'seedColor:\s*(Colors\.\w+|(const\s+)?Color\(0x[0-9A-Fa-f]{8}\))');
    if (!seed.hasMatch(source)) return false;
    file.writeAsStringSync(
        source.replaceAll(seed, 'seedColor: Color(0xFF${hex.toUpperCase()})'));
    return true;
  }
}
