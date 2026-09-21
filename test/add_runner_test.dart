import 'dart:io';

import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/add_runner.dart';

/// Runs `vgv add …` with the process rooted at [dir].
Future<int> runAdd(Directory dir, List<String> args) async {
  final original = Directory.current;
  Directory.current = dir;
  try {
    return await AddRunner(interactive: false).run(args);
  } finally {
    Directory.current = original;
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('vgv_add_'));
  tearDown(() => dir.deleteSync(recursive: true));

  void writePubspec(String name) =>
      File('${dir.path}/pubspec.yaml').writeAsStringSync(
        'name: $name\n'
        'environment:\n  sdk: ^3.0.0\n'
        'dependencies:\n  flutter:\n    sdk: flutter\n',
      );

  void writeGradle(String content) {
    Directory('${dir.path}/android/app').createSync(recursive: true);
    File('${dir.path}/android/app/build.gradle.kts').writeAsStringSync(content);
  }

  group('vgv add', () {
    test('no subcommand prints usage and fails', () async {
      expect(await runAdd(dir, <String>[]), 1);
    });

    test('unknown subcommand fails', () async {
      expect(await runAdd(dir, <String>['nonsense']), 1);
    });

    test('--help succeeds', () async {
      expect(await runAdd(dir, <String>['--help']), 0);
    });
  });

  group('vgv add flavors', () {
    test('refuses outside a Flutter project', () async {
      expect(await runAdd(dir, <String>['flavors']), 1);
    });

    test('refuses a Dart package with no flutter dependency', () async {
      File('${dir.path}/pubspec.yaml')
          .writeAsStringSync('name: pure_dart\nenvironment:\n  sdk: ^3.0.0\n');
      expect(await runAdd(dir, <String>['flavors']), 1);
    });

    test('refuses a Flutter project with no native folders', () async {
      writePubspec('app');
      expect(await runAdd(dir, <String>['flavors']), 1);
    });

    test('rejects an unknown flavor token', () async {
      writePubspec('app');
      writeGradle('android { defaultConfig { applicationId = "com.x.app" } }');
      expect(await runAdd(dir, <String>['flavors', '--flavors', 'dev,qa']), 1);
    });

    test('refuses when the app id does not end with the folder name', () async {
      writePubspec('app');
      writeGradle('android { defaultConfig { applicationId = "com.x.other" } }');
      expect(await runAdd(dir, <String>['flavors']), 1);
    });

    test('refuses when the app id cannot be detected', () async {
      writePubspec('app');
      writeGradle('android { defaultConfig { } }');
      expect(await runAdd(dir, <String>['flavors']), 1);
    });

    test('refuses a project that already declares product flavors', () async {
      writePubspec('app');
      writeGradle('''
android {
    defaultConfig { applicationId = "com.x.${_folderName(dir)}" }
    productFlavors {
        create("dev") { dimension = "environment" }
    }
    buildTypes { release { } }
}
''');
      expect(await runAdd(dir, <String>['flavors']), 1);
    });
  });
}

/// The temp folder name, which is what the command matches the app id against.
String _folderName(Directory d) => d.path.split(Platform.pathSeparator).last;
