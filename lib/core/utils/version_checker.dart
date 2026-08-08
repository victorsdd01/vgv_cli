import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../src/version.dart';

/// Resolves the current and latest CLI versions for `vgv -v` / `vgv -u`.
class VersionChecker {
  static const String _githubApiUrl =
      'https://api.github.com/repos/victorsdd01/vgv_cli/releases/latest';
  static const String _mainPubspecUrl =
      'https://raw.githubusercontent.com/victorsdd01/vgv_cli/main/pubspec.yaml';

  /// The current CLI version — the single source of truth, baked at build
  /// time from `pubspec.yaml` (see `tool/generate_version.dart`).
  ///
  /// Reading `pubspec.yaml` at runtime is unreliable for a globally activated
  /// package, so we rely on the generated [packageVersion] constant instead.
  static String getCurrentVersion() => packageVersion;

  /// Latest CLI version from GitHub releases (fallback source).
  static Future<String?> getLatestCLIVersion() async {
    try {
      final response = await http
          .get(Uri.parse(_githubApiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic data;
        try {
          data = json.decode(response.body);
        } on FormatException {
          return null;
        }
        if (data is Map<String, dynamic>) {
          final tagName = data['tag_name']?.toString();
          if (tagName != null) {
            return tagName.replaceFirst('v', '');
          }
        }
      }
    } catch (e) {
      // Network issues shouldn't break the CLI.
    }
    return null;
  }

  /// Latest CLI version from the `main` branch `pubspec.yaml` (canonical).
  static Future<String?> getLatestCLIVersionFromGit() async {
    try {
      final response = await http
          .get(Uri.parse(_mainPubspecUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final versionMatch =
            RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(response.body);
        if (versionMatch != null) {
          return versionMatch.group(1)!;
        }
      }
    } catch (e) {
      // Silently fail.
    }
    return null;
  }

  /// Get the latest CLI version.
  ///
  /// Canonical source is the `main` branch `pubspec.yaml` — that is exactly
  /// what `vgv --update` installs (`dart pub global activate --source git`),
  /// so current-vs-latest comparisons stay consistent. GitHub Releases are
  /// only a fallback when `main` cannot be reached, since the release/tag
  /// pipeline can lag one version behind `main`.
  static Future<String?> getLatestCLIVersionAny() async {
    final gitVersion = await getLatestCLIVersionFromGit();
    if (gitVersion != null) return gitVersion;
    return getLatestCLIVersion();
  }

  /// Compare two version strings.
  /// Returns: -1 if version1 < version2, 0 if equal, 1 if version1 > version2.
  static int compareVersions(String version1, String version2) {
    // Strip any pre-release/build metadata (e.g. 1.2.3-beta+1) and parse
    // defensively so a malformed tag never throws a FormatException.
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final parts1 = parse(version1);
    final parts2 = parse(version2);

    while (parts1.length < parts2.length) {
      parts1.add(0);
    }
    while (parts2.length < parts1.length) {
      parts2.add(0);
    }

    for (int i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }
    return 0;
  }
}
