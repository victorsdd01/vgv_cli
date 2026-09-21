import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
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

Future<int> runAddWith(
  Directory dir,
  List<String> args, {
  required Logger logger,
}) async {
  final original = Directory.current;
  Directory.current = dir;
  try {
    return await AddRunner(logger: logger, interactive: true).run(args);
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

  group('vgv add flavors · app name', () {
    /// A project whose folder name and display name deliberately differ, so a
    /// name taken from the folder is distinguishable from the real one.
    void scaffold({String label = 'Viejo Nombre'}) {
      final folder = _folderName(dir);
      writePubspec('app');
      writeGradle('android { defaultConfig { applicationId = "com.x.$folder" } }');
      Directory('${dir.path}/android/app/src/main').createSync(recursive: true);
      File('${dir.path}/android/app/src/main/AndroidManifest.xml')
          .writeAsStringSync('<manifest><application android:label="$label" '
              '/></manifest>');
    }

    String gradle() =>
        File('${dir.path}/android/app/build.gradle.kts').readAsStringSync();

    test('keeps the app name it detects, only adding the suffixes', () async {
      scaffold();
      final logger = _ScriptedLogger(keepName: true);
      expect(await runAddWith(dir, <String>['flavors', '--flavors', 'dev,prod'],
          logger: logger), 0);
      expect(logger.asked.first, contains('Viejo Nombre'));
      expect(gradle(), contains('"app_name", "Viejo Nombre Dev"'));
      expect(gradle(), contains('"app_name", "Viejo Nombre"'));
    });

    test('uses the name you type when you decline to keep it', () async {
      scaffold();
      final logger =
          _ScriptedLogger(keepName: false, newName: 'Nombre Nuevo');
      expect(await runAddWith(dir, <String>['flavors', '--flavors', 'dev'],
          logger: logger), 0);
      expect(logger.asked.any((String m) => m.startsWith('App name')), isTrue);
      expect(gradle(), contains('"app_name", "Nombre Nuevo Dev"'));
      expect(gradle(), isNot(contains('Viejo Nombre')));
    });

    test('--app-name wins and skips the question entirely', () async {
      scaffold();
      final logger = _ScriptedLogger(keepName: true);
      expect(
          await runAddWith(dir,
              <String>['flavors', '--flavors', 'dev', '--app-name', 'Forzado'],
              logger: logger),
          0);
      expect(logger.asked.any((String m) => m.startsWith('Keep ')), isFalse);
      expect(gradle(), contains('"app_name", "Forzado Dev"'));
    });

    test('falls back to the folder name when nothing declares one', () async {
      final folder = _folderName(dir);
      writePubspec('app');
      writeGradle('android { defaultConfig { applicationId = "com.x.$folder" } }');
      final logger = _ScriptedLogger(keepName: true);
      expect(await runAddWith(dir, <String>['flavors', '--flavors', 'dev'],
          logger: logger), 0);
      expect(logger.asked.first, contains(folder));
    });
  });
}

/// The temp folder name, which is what the command matches the app id against.
String _folderName(Directory d) => d.path.split(Platform.pathSeparator).last;

/// A logger that answers prompts from a script, so the interactive branches
/// can be tested without a terminal.
class _ScriptedLogger extends Logger {
  _ScriptedLogger({required this.keepName, this.newName});

  /// Answer to the "Keep …?" confirmation.
  final bool keepName;

  /// Answer to "App name:" when [keepName] is false.
  final String? newName;

  final List<String> asked = <String>[];

  @override
  bool confirm(String? message, {bool defaultValue = false}) {
    asked.add(message ?? '');
    // Every other confirm ("Apply this to the project?") is a yes.
    return message != null && message.startsWith('Keep ') ? keepName : true;
  }

  @override
  String prompt(String? message, {Object? defaultValue, bool hidden = false}) {
    asked.add(message ?? '');
    return newName ?? (defaultValue?.toString() ?? '');
  }
}
