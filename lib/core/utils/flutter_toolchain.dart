import 'dart:io';

/// Resolves how to invoke the Flutter/Dart toolchain.
///
/// Projects pinned with [FVM](https://fvm.app) must run their commands through
/// `fvm flutter …` / `fvm dart …`, otherwise the CLI silently uses whatever
/// global SDK happens to be on the PATH (a different Flutter version than the
/// project expects).
///
/// Resolution order:
///   1. An explicit choice (`--fvm` / `--no-fvm`) always wins.
///   2. Otherwise auto-detect: `fvm` on the PATH **and** an FVM marker
///      (`.fvmrc` or `.fvm/`) in the working directory.
class FlutterToolchain {
  const FlutterToolchain({required this.useFvm});

  /// A toolchain that always uses the global SDK.
  const FlutterToolchain.global() : useFvm = false;

  /// Whether commands are prefixed with `fvm`.
  final bool useFvm;

  /// Builds a toolchain for [workingDirectory].
  ///
  /// [explicit] comes from `--fvm` / `--no-fvm`; when null we auto-detect.
  static Future<FlutterToolchain> resolve({
    bool? explicit,
    String? workingDirectory,
  }) async {
    if (explicit == false) return const FlutterToolchain(useFvm: false);
    final available = await isFvmAvailable();
    if (explicit == true) return FlutterToolchain(useFvm: available);
    final dir = workingDirectory ?? Directory.current.path;
    return FlutterToolchain(useFvm: available && hasFvmMarker(dir));
  }

  /// True when `fvm` is callable on this machine.
  static Future<bool> isFvmAvailable() async {
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final r = await Process.run(which, <String>['fvm'], runInShell: true);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// True when [dir] is pinned to an FVM-managed SDK.
  static bool hasFvmMarker(String dir) =>
      File('$dir/.fvmrc').existsSync() ||
      Directory('$dir/.fvm').existsSync() ||
      File('$dir/.fvm/fvm_config.json').existsSync();

  /// The executable to spawn for a `flutter …` invocation.
  String get executable => useFvm ? 'fvm' : 'flutter';

  /// The executable to spawn for a `dart …` invocation.
  String get dartExecutable => useFvm ? 'fvm' : 'dart';

  /// Prefixes [args] for a `flutter` command.
  List<String> flutter(List<String> args) =>
      useFvm ? <String>['flutter', ...args] : args;

  /// Prefixes [args] for a `dart` command.
  List<String> dart(List<String> args) =>
      useFvm ? <String>['dart', ...args] : args;

  /// Human-readable prefix for hints printed to the user (`fvm flutter run …`).
  String get hintPrefix => useFvm ? 'fvm ' : '';

  /// The Flutter version FVM has pinned for [dir], when discoverable.
  static String? pinnedVersion(String dir) {
    try {
      final rc = File('$dir/.fvmrc');
      if (rc.existsSync()) {
        final m = RegExp(r'"flutter"\s*:\s*"([^"]+)"').firstMatch(rc.readAsStringSync());
        if (m != null) return m.group(1);
      }
      final legacy = File('$dir/.fvm/fvm_config.json');
      if (legacy.existsSync()) {
        final m = RegExp(r'"flutterSdkVersion"\s*:\s*"([^"]+)"')
            .firstMatch(legacy.readAsStringSync());
        if (m != null) return m.group(1);
      }
    } catch (_) {
      // Unreadable/malformed config — treat as unpinned.
    }
    return null;
  }
}
