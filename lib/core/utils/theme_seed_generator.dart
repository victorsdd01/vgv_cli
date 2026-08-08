import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/entities/project_config.dart';

/// Rewrites the generated Material 3 theme to seed its `ColorScheme` from the
/// brand color the user chose (`ColorScheme.fromSeed`). No-op when unset.
class ThemeSeedGenerator {
  const ThemeSeedGenerator();

  Future<void> generate(ProjectConfig config) async {
    final hex = config.seedColorHex;
    if (hex == null || hex.isEmpty) return;
    final file =
        File(path.join(config.projectName, 'lib/application/theme/theme.dart'));
    if (!file.existsSync()) return;
    final updated =
        file.readAsStringSync().replaceAll('Colors.blue', 'Color(0xFF$hex)');
    file.writeAsStringSync(updated);
  }
}
