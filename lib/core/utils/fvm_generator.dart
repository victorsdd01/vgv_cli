import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Pins a generated project to an FVM-managed Flutter SDK.
///
/// Writes `.fvmrc` (so `fvm flutter …` and the CLI's own auto-detection resolve
/// the right SDK) and points the Dart/Flutter VS Code extensions at the
/// project-local SDK symlink, so the editor analyzes with the same version the
/// project builds with.
class FvmGenerator {
  const FvmGenerator();

  /// Path FVM links the project SDK to.
  static const String sdkPath = '.fvm/flutter_sdk';

  /// Writes `.fvmrc` so every later `fvm flutter …` in the project resolves to
  /// the pinned SDK. Call this right after the project is created, before any
  /// pub/codegen step. Returns the pinned version, or null when FVM has none.
  Future<String?> pinSdk(String projectName, {String? version}) async {
    final resolved = version ?? await currentFvmVersion();
    if (resolved == null) return null; // Nothing to pin to; leave it alone.
    _writeFvmrc(projectName, resolved);
    return resolved;
  }

  /// Points the editor at the project-local SDK and ignores the symlink.
  ///
  /// Must run **after** the CLI has written `.vscode/settings.json` and
  /// `.gitignore`, otherwise those steps overwrite this configuration.
  void configureEditor(String projectName) {
    _mergeVsCodeSettings(projectName);
    _appendGitIgnore(projectName);
  }

  /// The Flutter version `fvm` would use here: the global default when one is
  /// set, otherwise the only/first fully-installed cached version. Returns
  /// null when FVM has nothing usable.
  Future<String?> currentFvmVersion() async {
    return _globalDefault() ?? await _firstInstalled();
  }

  /// FVM marks the global SDK with a `default` symlink in its cache dir.
  String? _globalDefault() {
    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) return null;
      final link = Link(p.join(home, 'fvm', 'default'));
      if (!link.existsSync()) return null;
      final target = link.resolveSymbolicLinksSync();
      final name = p.basename(target);
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _firstInstalled() async {
    try {
      final r = await Process.run('fvm', <String>['api', 'list'], runInShell: true);
      if (r.exitCode != 0) return null;
      final data = jsonDecode(r.stdout.toString()) as Map<String, dynamic>;
      final versions = (data['versions'] as List?) ?? const [];
      for (final v in versions) {
        if (v is Map && v['isSetup'] == true && v['name'] != null) {
          return v['name'].toString();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _writeFvmrc(String projectName, String version) {
    File(p.join(projectName, '.fvmrc'))
        .writeAsStringSync('{\n  "flutter": "$version"\n}\n');
  }

  /// Merge into the settings the CLI already wrote instead of clobbering them.
  void _mergeVsCodeSettings(String projectName) {
    final file = File(p.join(projectName, '.vscode', 'settings.json'));
    final settings = <String, dynamic>{};
    if (file.existsSync()) {
      try {
        final parsed = jsonDecode(file.readAsStringSync());
        if (parsed is Map<String, dynamic>) settings.addAll(parsed);
      } catch (_) {
        // Unparseable settings: start from the FVM keys rather than losing the
        // file silently — it is regenerated content, not hand-written.
      }
    }
    settings['dart.flutterSdkPath'] = sdkPath;
    final exclude = <String, dynamic>{
      ...?(settings['files.exclude'] as Map?)?.cast<String, dynamic>(),
      '**/.fvm': true,
    };
    settings['files.exclude'] = exclude;
    final watcher = <String, dynamic>{
      ...?(settings['files.watcherExclude'] as Map?)?.cast<String, dynamic>(),
      '**/.fvm': true,
    };
    settings['files.watcherExclude'] = watcher;

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(settings)}\n');
  }

  /// The SDK symlink is machine-local; the pin in `.fvmrc` is what's shared.
  void _appendGitIgnore(String projectName) {
    final file = File(p.join(projectName, '.gitignore'));
    if (!file.existsSync()) return;
    final content = file.readAsStringSync();
    if (content.contains('.fvm/')) return;
    file.writeAsStringSync('$content\n# FVM (the pinned version lives in .fvmrc)\n.fvm/\n');
  }
}
