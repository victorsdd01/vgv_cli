import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/add_runner.dart';

/// A minimal Flutter project on disk, shaped like `flutter create` output.
Directory fakeProject({
  String name = 'shop_app',
  bool flavors = false,
  String? mainDart,
  bool vgvTheme = false,
}) {
  final root = Directory(p.join(
      Directory.systemTemp.createTempSync('vgv_add_').path, name))
    ..createSync(recursive: true);
  addTearDown(() => root.parent.deleteSync(recursive: true));
  void write(String path, String content) => File(p.join(root.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  write('pubspec.yaml', '''
name: $name
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
''');
  write('android/app/build.gradle.kts', '''
android {
    defaultConfig {
        applicationId = "com.acme.$name"
    }
${flavors ? '''    flavorDimensions += "environment"
    productFlavors {
        create("dev") { applicationIdSuffix = ".dev" }
        create("prod") { }
    }''' : ''}
}
''');
  write('ios/Runner.xcodeproj/project.pbxproj', '''
PRODUCT_BUNDLE_IDENTIFIER = com.acme.shopApp.dev;
PRODUCT_BUNDLE_IDENTIFIER = com.acme.shopApp;
PRODUCT_BUNDLE_IDENTIFIER = com.acme.shopApp.RunnerTests;
''');
  Directory(p.join(root.path, 'web')).createSync();
  Directory(p.join(root.path, 'macos')).createSync();
  write('lib/main.dart', mainDart ??
      '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp());
}
''');
  if (vgvTheme) {
    write('lib/application/theme/theme.dart',
        'final light = ColorScheme.fromSeed(seedColor: Colors.blue);\n');
  }
  return root;
}

class Calls {
  final List<String> commands = <String>[];

  Future<int> call(String executable, List<String> args) async {
    commands.add('$executable ${args.join(' ')}');
    return 0;
  }
}

Future<int> runAdd(Directory project, List<String> args, {Calls? calls}) async {
  final original = Directory.current;
  Directory.current = project;
  try {
    return await AddRunner(
      logger: Logger(level: Level.quiet),
      interactive: false,
      runProcess: (calls ?? Calls()).call,
    ).run(args);
  } finally {
    Directory.current = original;
  }
}

String read(Directory project, String path) =>
    File(p.join(project.path, path)).readAsStringSync();

bool exists(Directory project, String path) =>
    FileSystemEntity.typeSync(p.join(project.path, path)) !=
    FileSystemEntityType.notFound;

/// 1×1 PNG header (only the size is read).
List<int> png(int width, int height) => <int>[
      137, 80, 78, 71, 13, 10, 26, 10, // signature
      0, 0, 0, 13, 73, 72, 68, 82, // IHDR
      (width >> 24) & 255, (width >> 16) & 255, (width >> 8) & 255, width & 255,
      (height >> 24) & 255, (height >> 16) & 255, (height >> 8) & 255,
      height & 255,
    ];

void main() {
  group('vgv add lefthook', () {
    test('writes lefthook.yml and refuses to overwrite it', () async {
      final project = fakeProject();
      expect(await runAdd(project, <String>['lefthook']), 0);
      expect(read(project, 'lefthook.yml'), contains('pre-commit:'));

      File(p.join(project.path, 'lefthook.yml')).writeAsStringSync('mine');
      expect(await runAdd(project, <String>['lefthook']), 1);
      expect(read(project, 'lefthook.yml'), 'mine');
      expect(await runAdd(project, <String>['lefthook', '--force']), 0);
    });
  });

  group('vgv add fastlane', () {
    test('needs flavors', () async {
      final project = fakeProject();
      expect(await runAdd(project, <String>['fastlane']), 1);
      expect(exists(project, 'Gemfile'), isFalse);
    });

    test('uses the real Android and iOS ids and the detected flavors', () async {
      final project = fakeProject(flavors: true);
      expect(await runAdd(project, <String>['fastlane']), 0);
      expect(read(project, 'android/fastlane/Appfile'),
          contains('package_name("com.acme.shop_app")'));
      expect(read(project, 'ios/fastlane/Appfile'),
          contains('app_identifier("com.acme.shopApp")'));
      final fastfile = read(project, 'android/fastlane/Fastfile');
      expect(fastfile, contains('lane :deploy_dev'));
      expect(fastfile, contains('lane :deploy_prod'));
      expect(fastfile, isNot(contains('deploy_staging')));
    });
  });

  group('vgv add agents', () {
    test('defaults to CLAUDE.md and never overwrites one', () async {
      final project = fakeProject();
      expect(await runAdd(project, <String>['agents']), 0);
      expect(read(project, 'CLAUDE.md'), contains('Project rules'));

      File(p.join(project.path, 'CLAUDE.md')).writeAsStringSync('my rules');
      expect(await runAdd(project, <String>['agents']), 1);
      expect(read(project, 'CLAUDE.md'), 'my rules');
    });

    test('rejects an unknown agent', () async {
      final project = fakeProject();
      expect(await runAdd(project, <String>['agents', '--agents', 'clippy']), 1);
    });
  });

  group('vgv add seed', () {
    test('rewrites a vgv theme, and can be re-applied', () async {
      final project = fakeProject(vgvTheme: true);
      expect(await runAdd(project, <String>['seed', '--color', '#4b60aa']), 0);
      expect(read(project, 'lib/application/theme/theme.dart'),
          contains('seedColor: Color(0xFF4B60AA)'));
      expect(await runAdd(project, <String>['seed', '--color', '112233']), 0);
      expect(read(project, 'lib/application/theme/theme.dart'),
          contains('seedColor: Color(0xFF112233)'));
    });

    test('explains it needs a vgv project, and validates the color', () async {
      expect(await runAdd(fakeProject(), <String>['seed', '--color', '4B60AA']), 1);
      expect(
          await runAdd(fakeProject(vgvTheme: true), <String>['seed', '--color', 'blue']),
          1);
    });
  });

  group('vgv add window', () {
    test('wires window_manager into a stock main.dart', () async {
      final project = fakeProject();
      final calls = Calls();
      expect(await runAdd(project, <String>['window'], calls: calls), 0);
      final main = read(project, 'lib/main.dart');
      expect(main, contains('Future<void> main() async {'));
      expect(main, contains('await windowManager.ensureInitialized();'));
      expect(main, contains("import 'package:window_manager/window_manager.dart';"));
      expect(read(project, 'pubspec.yaml'), contains('window_manager:'));
      expect(calls.commands.single, endsWith('pub get'));
    });

    test('fails clearly when main() cannot be found', () async {
      final project = fakeProject(mainDart: 'void start() {}\n');
      expect(await runAdd(project, <String>['window']), 1);
      expect(read(project, 'pubspec.yaml'), isNot(contains('window_manager')));
    });
  });

  group('vgv add icons', () {
    test('rejects a file that is not a PNG', () async {
      final project = fakeProject();
      final bad = File(p.join(project.parent.path, 'icon.jpg'))
        ..writeAsStringSync('nope');
      expect(await runAdd(project, <String>['icons', '--from', bad.path]), 1);
    });

    test('configures only the platforms present, then generates', () async {
      final project = fakeProject();
      final master = File(p.join(project.parent.path, 'icon.png'))
        ..writeAsBytesSync(png(1024, 1024));
      final calls = Calls();
      expect(
          await runAdd(project, <String>['icons', '--from', master.path],
              calls: calls),
          0);
      final yaml = read(project, 'flutter_launcher_icons.yaml');
      expect(yaml, contains('android: true'));
      expect(yaml, contains('  web:'));
      expect(yaml, contains('  macos:'));
      expect(yaml, isNot(contains('windows')));
      expect(exists(project, 'assets/icon/app_icon.png'), isTrue);
      expect(calls.commands.last, endsWith('run flutter_launcher_icons'));
    });
  });

  group('vgv add splash', () {
    test('writes the color and a custom image', () async {
      final project = fakeProject();
      final image = File(p.join(project.parent.path, 'splash.png'))
        ..writeAsBytesSync(png(512, 512));
      final calls = Calls();
      expect(
          await runAdd(project,
              <String>['splash', '--color', '4B60AA', '--image', image.path],
              calls: calls),
          0);
      final yaml = read(project, 'flutter_native_splash.yaml');
      expect(yaml, contains('color: "#4B60AA"'));
      expect(yaml, contains('image: assets/splash/splash.png'));
      expect(exists(project, 'assets/splash/splash.png'), isTrue);
      expect(calls.commands.last, endsWith('run flutter_native_splash:create'));
    });

    test('rejects an invalid color', () async {
      expect(await runAdd(fakeProject(), <String>['splash', '--color', 'red']), 1);
    });
  });

  test('unknown subcommand fails', () async {
    expect(await runAdd(fakeProject(), <String>['nope']), 1);
  });
}
