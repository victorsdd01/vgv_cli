import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/entities/project_config.dart';

/// Scaffolds a [lefthook](https://github.com/evilmartians/lefthook) config so
/// the generated project runs format/analyze on commit and tests on push.
/// Lefthook itself is not installed automatically — the CLI instructs the user.
class LefthookGenerator {
  const LefthookGenerator();

  Future<void> generate(ProjectConfig config) async {
    if (!config.includeLefthook) return;
    final root = config.projectName;
    _write(path.join(root, 'lefthook.yml'), _lefthookYml());
  }

  String _lefthookYml() => '''# Managed by lefthook — https://github.com/evilmartians/lefthook
#
# Install the binary once (pick one):
#   brew install lefthook          # macOS
#   dart pub global activate lefthook
# Then enable the hooks in this repo:
#   lefthook install

pre-commit:
  parallel: true
  commands:
    format:
      glob: "*.dart"
      run: dart format --set-exit-if-changed {staged_files}
      stage_fixed: true
    analyze:
      glob: "*.dart"
      run: dart analyze --fatal-infos

pre-push:
  commands:
    test:
      run: flutter test
''';

  void _write(String filePath, String content) {
    final file = File(filePath)..parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}
