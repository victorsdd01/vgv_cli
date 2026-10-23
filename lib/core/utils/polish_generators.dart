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

    // Only the platforms the project actually has: flutter_launcher_icons
    // warns about (and skips) any listed platform whose folder is missing.
    final targets = config.flutterPlatforms;
    String generate(String platform) => '  $platform:\n'
        '    generate: true\n'
        '    image_path: "assets/icon/app_icon.png"\n';
    final buf = StringBuffer()
      ..writeln('flutter_launcher_icons:')
      ..writeln('  image_path: "assets/icon/app_icon.png"')
      ..writeln('  android: ${targets.contains('android')}')
      ..writeln('  ios: ${targets.contains('ios')}');
    if (targets.contains('ios')) buf.writeln('  remove_alpha_ios: true');
    for (final platform in const <String>['web', 'windows', 'macos']) {
      if (targets.contains(platform)) buf.write(generate(platform));
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

  /// [image] is a project-relative asset to center on the splash; by default
  /// the app icon master, when the project has one.
  Future<void> generate(ProjectConfig config, {String? image}) async {
    if (!config.includeSplash) return;
    final root = config.projectName;
    final color = config.seedColorHex != null ? '#${config.seedColorHex}' : '#FFFFFF';
    final imagePath = image ??
        ((config.iconMasterPath != null &&
                File(p.join(root, 'assets', 'icon', 'app_icon.png')).existsSync())
            ? 'assets/icon/app_icon.png'
            : null);
    final hasImage = imagePath != null;

    final buf = StringBuffer()
      ..writeln('flutter_native_splash:')
      ..writeln('  color: "$color"')
      ..writeln('  color_dark: "#0E0F11"');
    if (hasImage) {
      buf
        ..writeln('  image: $imagePath')
        ..writeln('  image_dark: $imagePath');
    }
    buf
      ..writeln('  android_12:')
      ..writeln('    color: "$color"')
      ..writeln('    color_dark: "#0E0F11"');
    if (hasImage) {
      buf.writeln('    image: $imagePath');
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

  /// Wires window_manager into `lib/main.dart`. Returns whether it did (false
  /// when not requested, already wired, or `main()` could not be found).
  ///
  /// Works on vgv's own `main.dart` and on a stock Flutter one: when `main()`
  /// does not call `WidgetsFlutterBinding.ensureInitialized()` yet, it is made
  /// `async` and the call is added, since window_manager must run first.
  Future<bool> generate(ProjectConfig config) async {
    if (!config.desktopWindow || !config.platforms.contains(PlatformType.desktop)) {
      return false;
    }
    final root = config.projectName;
    final main = File(p.join(root, 'lib', 'main.dart'));
    if (!main.existsSync()) return false;
    var s = main.readAsStringSync();
    if (s.contains('window_manager')) return false; // already wired

    const ensure = '  WidgetsFlutterBinding.ensureInitialized();\n';
    if (!s.contains(ensure)) {
      final mainDecl = RegExp(r'(?:Future<void>|void)\s+main\(\)\s*(?:async\s*)?\{\n');
      if (!mainDecl.hasMatch(s)) return false;
      s = s.replaceFirst(mainDecl, 'Future<void> main() async {\n$ensure');
    }

    const import = "import 'package:window_manager/window_manager.dart';";
    if (s.contains("import 'package:flutter/foundation.dart';")) {
      s = s.replaceFirst(
        "import 'package:flutter/foundation.dart';",
        "import 'package:flutter/foundation.dart';\n$import",
      );
    } else {
      s = "import 'package:flutter/foundation.dart';\n$import\n$s";
    }

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
      ensure,
      block.replaceFirst('{{TITLE}}', config.effectiveAppName),
    );
    main.writeAsStringSync(s);
    addPubspecDependency(root, 'window_manager', '^0.4.3');
    return true;
  }
}
