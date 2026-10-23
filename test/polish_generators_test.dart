import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/polish_generators.dart';
import 'package:vgv_cli/domain/entities/project_config.dart';

void main() {
  test('icon config lists only the platforms the project has', () async {
    final tmp = Directory.systemTemp.createTempSync('vgv_icons_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final master = File(p.join(tmp.path, 'master.png'))..writeAsBytesSync([0]);
    final root = Directory(p.join(tmp.path, 'app'))..createSync();
    File(p.join(root.path, 'pubspec.yaml'))
        .writeAsStringSync('name: app\n\ndev_dependencies:\n  test: any\n');

    final original = Directory.current;
    Directory.current = tmp;
    try {
      await const IconSetGenerator().generate(ProjectConfig(
        projectName: 'app',
        organizationName: 'com.acme',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
        platforms: const [
          PlatformType.mobile,
          PlatformType.web,
          PlatformType.desktop,
        ],
        desktopPlatform: DesktopPlatform.custom,
        customDesktopPlatforms: const CustomDesktopPlatforms(
            windows: false, macos: true, linux: false),
        iconMasterPath: master.path,
      ));
    } finally {
      Directory.current = original;
    }

    final yaml =
        File(p.join(root.path, 'flutter_launcher_icons.yaml')).readAsStringSync();
    expect(yaml, contains('android: true'));
    expect(yaml, contains('ios: true'));
    expect(yaml, contains('  web:'));
    expect(yaml, contains('  macos:'));
    expect(yaml, isNot(contains('windows')));
  });
}
