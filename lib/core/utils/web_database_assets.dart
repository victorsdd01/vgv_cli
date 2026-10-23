import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'flutter_toolchain.dart';

/// Puts the two files drift needs to run SQLite in the browser into `web/`
/// (see https://drift.simonbinder.eu/platforms/web/):
///
/// * `sqlite3.wasm`, downloaded from the GitHub release of the `sqlite3`
///   version in `pubspec.lock` — it is not shipped inside the pub package.
/// * `drift_worker.js`, **compiled** from `tool/drift_worker.dart`. The
///   prebuilt worker from drift's releases bundles whatever sqlite3 bindings
///   drift was released with, which can be older than the resolved `sqlite3`
///   and then fails to link the wasm (`LinkError: … xFileSize64`). Compiling
///   it from the project uses exactly the app's versions.
class WebDatabaseAssets {
  const WebDatabaseAssets(this.toolchain);

  final FlutterToolchain toolchain;

  /// Source of the worker; kept outside `web/` so it is not copied into the
  /// web build output.
  static const String workerSourcePath = 'tool/drift_worker.dart';

  static const String workerSource = '''// Compiled to web/drift_worker.js — recompile after upgrading drift:
//   dart compile js -O4 tool/drift_worker.dart -o web/drift_worker.js
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
''';

  /// Printed when the files cannot be set up; the project still builds.
  static const String manualStep =
      'Web database: dart compile js -O4 tool/drift_worker.dart -o '
      'web/drift_worker.js, and download sqlite3.wasm (sqlite3 version from '
      'pubspec.lock) into web/ — https://drift.simonbinder.eu/platforms/web/';

  /// Release URL of the `sqlite3.wasm` matching the `sqlite3` version resolved
  /// in [lockContent], or null when it is not there.
  static String? sqlite3WasmUrl(String lockContent) {
    try {
      final packages = (loadYaml(lockContent) as YamlMap)['packages'] as YamlMap;
      final version = (packages['sqlite3'] as YamlMap?)?['version'] as String?;
      if (version == null) return null;
      return 'https://github.com/simolus3/sqlite3.dart/releases/download/'
          'sqlite3-$version/sqlite3.wasm';
    } catch (_) {
      return null;
    }
  }

  /// Sets both files up in `<projectName>/web/`. Returns whether both are in
  /// place.
  Future<bool> install(String projectName) async {
    final worker = await _compileWorker(projectName);
    final wasm = await _downloadWasm(projectName);
    return worker && wasm;
  }

  Future<bool> _compileWorker(String projectName) async {
    File(p.join(projectName, workerSourcePath))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(workerSource);
    try {
      final result = await Process.run(
        toolchain.dartExecutable,
        toolchain.dart(<String>[
          'compile',
          'js',
          '-O4',
          workerSourcePath,
          '-o',
          'web/drift_worker.js',
        ]),
        workingDirectory: projectName,
        runInShell: true,
      );
      // Build by-products that would otherwise ship with the web build.
      for (final extra in <String>['.deps', '.map']) {
        final file = File(p.join(projectName, 'web', 'drift_worker.js$extra'));
        if (file.existsSync()) file.deleteSync();
      }
      return result.exitCode == 0 &&
          File(p.join(projectName, 'web', 'drift_worker.js')).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _downloadWasm(String projectName) async {
    final lock = File(p.join(projectName, 'pubspec.lock'));
    if (!lock.existsSync()) return false;
    final url = sqlite3WasmUrl(lock.readAsStringSync());
    if (url == null) return false;
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return false;
      File(p.join(projectName, 'web', 'sqlite3.wasm'))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(res.bodyBytes);
      return true;
    } catch (_) {
      return false;
    }
  }
}
