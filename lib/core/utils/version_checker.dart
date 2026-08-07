import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../src/version.dart';

/// Utility class to check for the latest versions of Flutter packages
class VersionChecker {
  static const Map<String, String> _latestVersions = {
    'flutter_bloc': '^9.1.1',
    'hydrated_bloc': '^10.1.1',
    'replay_bloc': '^0.3.0',
    'bloc_concurrency': '^0.3.0',
    'dartz': '^0.10.1',
    'path_provider': '^2.1.5',
    'get_it': '^8.0.3',
    'provider': '^6.1.5',
    'go_router': '^16.0.0',
    'equatable': '^2.0.7',
  };

  static const String _githubApiUrl = 'https://api.github.com/repos/victorsdd01/vgv_cli/releases/latest';
  
  /// The current CLI version — the single source of truth, baked at build
  /// time from `pubspec.yaml` (see `tool/generate_version.dart`).
  ///
  /// Reading `pubspec.yaml` at runtime is unreliable for a globally activated
  /// package, so we rely on the generated [packageVersion] constant instead.
  static String getCurrentVersion() => packageVersion;
  
  /// Get version from Git synchronously (for fallback when pubspec.yaml not found locally)
  static String? getLatestCLIVersionFromGitSync() {
    try {
      // Try curl first (works on macOS/Linux)
      ProcessResult result = Process.runSync(
        'curl',
        ['-s', '--max-time', '5', 'https://raw.githubusercontent.com/victorsdd01/vgv_cli/main/pubspec.yaml'],
        runInShell: true,
      );
      
      if (result.exitCode != 0) {
        // Try wget as fallback (works on Linux)
        result = Process.runSync(
          'wget',
          ['-q', '--timeout=5', '-O', '-', 'https://raw.githubusercontent.com/victorsdd01/vgv_cli/main/pubspec.yaml'],
          runInShell: true,
        );
      }
      
      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        final content = result.stdout.toString();
        final versionMatch = RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(content);
        if (versionMatch != null) {
          return versionMatch.group(1)!;
        }
      }
    } catch (e) {
      // Silently fail - network issues shouldn't break the CLI
    }
    
    return null;
  }
  
  /// Get the latest version for a specific package
  static String getLatestVersion(String packageName) {
    return _latestVersions[packageName] ?? '^1.0.0';
  }

  /// Get all latest versions
  static Map<String, String> getAllLatestVersions() {
    return Map.from(_latestVersions);
  }

  /// Check if a version is the latest
  static bool isLatestVersion(String packageName, String currentVersion) {
    final latest = getLatestVersion(packageName);
    return currentVersion == latest;
  }

  /// Get version recommendations for packages
  static Map<String, String> getVersionRecommendations() {
    return _latestVersions;
  }

  /// Format version for display
  static String formatVersion(String version) {
    return version.replaceAll('^', '');
  }

  /// Get a summary of all latest versions
  static String getVersionSummary() {
    final summary = StringBuffer();
    summary.writeln('📦 Latest Package Versions:');
    summary.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    _latestVersions.forEach((package, version) {
      summary.writeln('  ${package.padRight(15)} ${formatVersion(version)}');
    });
    
    return summary.toString();
  }

  /// Get the latest CLI version from GitHub releases
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
      // Network issues shouldn't break the CLI
    }

    return null;
  }
  
  /// Get the latest CLI version from Git (fallback if no releases)
  static Future<String?> getLatestCLIVersionFromGit() async {
    try {
      // Get from main branch directly (more reliable than API)
      final response = await http.get(
        Uri.parse('https://raw.githubusercontent.com/victorsdd01/vgv_cli/main/pubspec.yaml'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final content = response.body;
        final versionMatch = RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(content);
        if (versionMatch != null) {
          return versionMatch.group(1)!;
        }
      }
    } catch (e) {
      // Silently fail
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
  
  /// Check if an update is available
  static Future<bool> isUpdateAvailable(String currentVersion) async {
    final latestVersion = await getLatestCLIVersion();
    if (latestVersion == null) return false;
    
    return compareVersions(currentVersion, latestVersion) < 0;
  }
  
  /// Compare two version strings
  /// Returns: -1 if version1 < version2, 0 if equal, 1 if version1 > version2
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
    
    // Pad with zeros if needed
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