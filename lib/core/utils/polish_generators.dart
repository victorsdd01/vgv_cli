import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/entities/project_config.dart';

/// Appends `  <name>: <version>` under `dependencies:` / `dev_dependencies:` in
/// the generated pubspec, unless already present. Best-effort (no-op if the
/// section header isn't found).
void addPubspecDependency(String projectRoot, String name, String version,
    {bool dev = false}) {
  final file = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!file.existsSync()) return;
  var s = file.readAsStringSync();
  if (RegExp('^  $name:', multiLine: true).hasMatch(s)) return;
  final header = dev ? 'dev_dependencies:' : 'dependencies:';
  if (!s.contains('$header\n')) return;
  s = s.replaceFirst('$header\n', '$header\n  $name: $version\n');
  file.writeAsStringSync(s);
}

String _humanize(String projectName) => projectName
    .split(RegExp(r'[_\s]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Generates a full launcher icon set config from a 1024×1024 master
/// (flutter_launcher_icons). The CLI instructs the user to run it (needs the
/// new dev dependency resolved first).
class IconSetGenerator {
  const IconSetGenerator();

  Future<void> generate(ProjectConfig config) async {
    final master = config.iconMasterPath;
    if (master == null || master.isEmpty) return;
    final src = File(master);
    if (!src.existsSync()) return;

    final root = config.projectName;
    final dest = File(p.join(root, 'assets', 'icon', 'app_icon.png'))
      ..parent.createSync(recursive: true);
    src.copySync(dest.path);

    final mobile = config.platforms.contains(PlatformType.mobile);
    final web = config.platforms.contains(PlatformType.web);
    final desktop = config.platforms.contains(PlatformType.desktop);
    final buf = StringBuffer()
      ..writeln('flutter_launcher_icons:')
      ..writeln('  image_path: "assets/icon/app_icon.png"');
    if (mobile) {
      buf
        ..writeln('  android: true')
        ..writeln('  ios: true')
        ..writeln('  remove_alpha_ios: true');
    }
    if (web) {
      buf
        ..writeln('  web:')
        ..writeln('    generate: true')
        ..writeln('    image_path: "assets/icon/app_icon.png"');
    }
    if (desktop) {
      buf
        ..writeln('  windows:')
        ..writeln('    generate: true')
        ..writeln('    image_path: "assets/icon/app_icon.png"')
        ..writeln('  macos:')
        ..writeln('    generate: true')
        ..writeln('    image_path: "assets/icon/app_icon.png"');
    }
    File(p.join(root, 'flutter_launcher_icons.yaml'))
        .writeAsStringSync(buf.toString());
    addPubspecDependency(root, 'flutter_launcher_icons', '^0.14.1', dev: true);
  }
}

/// Generates a flutter_native_splash config (color from the brand seed if set,
/// image from the app icon master if provided).
class SplashGenerator {
  const SplashGenerator();

  Future<void> generate(ProjectConfig config) async {
    if (!config.includeSplash) return;
    final root = config.projectName;
    final color = config.seedColorHex != null ? '#${config.seedColorHex}' : '#FFFFFF';
    final hasImage = config.iconMasterPath != null &&
        File(p.join(root, 'assets', 'icon', 'app_icon.png')).existsSync();

    final buf = StringBuffer()
      ..writeln('flutter_native_splash:')
      ..writeln('  color: "$color"')
      ..writeln('  color_dark: "#0E0F11"');
    if (hasImage) {
      buf
        ..writeln('  image: assets/icon/app_icon.png')
        ..writeln('  image_dark: assets/icon/app_icon.png');
    }
    buf
      ..writeln('  android_12:')
      ..writeln('    color: "$color"')
      ..writeln('    color_dark: "#0E0F11"');
    if (hasImage) {
      buf.writeln('    image: assets/icon/app_icon.png');
    }
    File(p.join(root, 'flutter_native_splash.yaml'))
        .writeAsStringSync(buf.toString());
    addPubspecDependency(root, 'flutter_native_splash', '^2.4.1', dev: true);
  }
}

/// Wires window_manager into `main.dart` so desktop builds open with a sane
/// minimum size + window title.
class DesktopWindowGenerator {
  const DesktopWindowGenerator();

  Future<void> generate(ProjectConfig config) async {
    if (!config.desktopWindow || !config.platforms.contains(PlatformType.desktop)) {
      return;
    }
    final root = config.projectName;
    final main = File(p.join(root, 'lib', 'main.dart'));
    if (!main.existsSync()) return;
    var s = main.readAsStringSync();
    if (s.contains('window_manager')) return; // already wired

    s = s.replaceFirst(
      "import 'package:flutter/foundation.dart';",
      "import 'package:flutter/foundation.dart';\n"
          "import 'package:window_manager/window_manager.dart';",
    );

    const block = '''
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        minimumSize: const Size(400, 600),
        title: '{{TITLE}}',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
''';
    s = s.replaceFirst(
      '  WidgetsFlutterBinding.ensureInitialized();\n',
      block.replaceFirst('{{TITLE}}', _humanize(config.projectName)),
    );
    main.writeAsStringSync(s);
    addPubspecDependency(root, 'window_manager', '^0.4.3');
  }
}
