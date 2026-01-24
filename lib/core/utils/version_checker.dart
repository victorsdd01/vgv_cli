import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

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
  
  /// Get the path to the version file
  static String _getVersionFilePath() {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    if (homeDir.isNotEmpty) {
      return path.join(homeDir, '.vgv_version');
    }
    // Fallback to current directory
    return path.join(Directory.current.path, '.vgv_version');
  }
  
  /// Save the installed version to a file
  static void saveInstalledVersion(String version) {
    try {
      final versionFile = File(_getVersionFilePath());
      versionFile.writeAsStringSync(version);
    } catch (e) {
      // Silently fail - not critical
    }
  }
  
  /// Get the installed version from the version file
  static String? getInstalledVersionFromFile() {
    try {
      final versionFile = File(_getVersionFilePath());
      if (versionFile.existsSync()) {
        final version = versionFile.readAsStringSync().trim();
        if (version.isNotEmpty && RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
          return version;
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }
  
  /// Get current version from pubspec.yaml or from installed package
  static String getCurrentVersion() {
    // First, try to get version from the saved version file (most reliable)
    final savedVersion = getInstalledVersionFromFile();
    if (savedVersion != null) {
      return savedVersion;
    }
    
    try {
      // Second, try to get version from dart pub global list
      try {
        final result = Process.runSync(
          'dart',
          ['pub', 'global', 'list'],
          runInShell: true,
        );
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          // Look for flutterforge in the output
          final lines = output.split('\n');
          for (final line in lines) {
            if (line.contains('vgv_cli')) {
              // Format is usually: "vgv_cli 1.10.6 from git ..."
              final versionMatch = RegExp(r'vgv_cli\s+(\d+\.\d+\.\d+)').firstMatch(line);
              if (versionMatch != null) {
                final version = versionMatch.group(1)!;
                // Only save if version file doesn't exist (don't overwrite existing)
                if (getInstalledVersionFromFile() == null) {
                  saveInstalledVersion(version);
                }
                return version;
              }
            }
          }
        }
      } catch (e) {
        // Continue to fallback methods
      }
      
      // Fallback: try to find pubspec.yaml
      final pubspecPath = _findPubspecPath();
      if (pubspecPath != null) {
        final file = File(pubspecPath);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final versionMatch = RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(content);
          if (versionMatch != null) {
            final version = versionMatch.group(1)!;
            // Only save if version file doesn't exist (don't overwrite existing)
            if (getInstalledVersionFromFile() == null) {
              saveInstalledVersion(version);
            }
            return version;
          }
        }
      }
      
      // Last resort: try to get from Git repository
      try {
        final gitVersion = getLatestCLIVersionFromGitSync();
        if (gitVersion != null) {
          // Don't save Git version as installed version, it's just a fallback
          return gitVersion;
        }
      } catch (e) {
        // Ignore errors
      }
    } catch (e) {
      // Fallback to default version
    }
    
    return '1.0.0';
  }
  
  /// Find pubspec.yaml path (works when installed globally or locally)
  /// Prioritizes pub-cache (global installation) over local paths
  static String? _findPubspecPath() {
    try {
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
      final possiblePaths = <String>[];
      
      // FIRST: Try pub-cache locations for globally installed packages (priority)
      if (homeDir.isNotEmpty) {
        final pubCacheBase = path.join(homeDir, '.pub-cache');
        
        // Try global_packages location
        possiblePaths.add(path.join(pubCacheBase, 'global_packages', 'vgv_cli', 'pubspec.yaml'));
        
        // Try git cache location (for packages installed from Git)
        try {
          final gitCacheDir = Directory(path.join(pubCacheBase, 'git', 'cache'));
          if (gitCacheDir.existsSync()) {
            final entries = gitCacheDir.listSync();
            for (final entry in entries) {
              if (entry is Directory) {
                final pubspecFile = File(path.join(entry.path, 'pubspec.yaml'));
                if (pubspecFile.existsSync()) {
                  final content = pubspecFile.readAsStringSync();
                  // Check if this is the vgv_cli package
                  if (content.contains('name: vgv_cli') || 
                      entry.path.contains('vgv_cli') ||
                      entry.path.contains('flutter-forge')) {
                    possiblePaths.add(pubspecFile.path);
                  }
                }
              }
            }
          }
        } catch (e) {
          // Ignore errors when searching
        }
      }
      
      // SECOND: Try to find pubspec.yaml relative to the script location (local development)
      try {
        final scriptPath = Platform.script.toFilePath();
        final scriptDir = path.dirname(scriptPath);
        final scriptDirNormalized = path.normalize(scriptDir);
        
        possiblePaths.addAll([
          path.join(scriptDirNormalized, 'pubspec.yaml'),
          path.join(scriptDirNormalized, '..', 'pubspec.yaml'),
          path.join(scriptDirNormalized, '..', '..', 'pubspec.yaml'),
          path.join(scriptDirNormalized, '..', '..', '..', 'pubspec.yaml'),
          path.join(scriptDirNormalized, '..', '..', '..', '..', 'pubspec.yaml'),
          path.join(scriptDirNormalized, '..', '..', '..', '..', '..', 'pubspec.yaml'),
          path.join(scriptDirNormalized, '..', '..', '..', '..', '..', '..', 'pubspec.yaml'),
          path.join(Directory.current.path, 'pubspec.yaml'),
        ]);
      } catch (e) {
        // Ignore errors
      }
      
      // Check paths in order (pub-cache first, then local)
      for (final possiblePath in possiblePaths) {
        try {
          final normalizedPath = path.normalize(possiblePath);
          final file = File(normalizedPath);
          if (file.existsSync()) {
            return normalizedPath;
          }
        } catch (e) {
          // Continue searching
        }
      }
    } catch (e) {
      // Try alternative method
    }
    
    return null;
  }
  
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
      final response = await http.get(Uri.parse(_githubApiUrl));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name']?.toString();
        if (tagName != null) {
          return tagName.replaceFirst('v', '');
        }
      }
    } catch (e) {
      // Silently fail - network issues shouldn't break the CLI
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
  
  /// Get the latest CLI version (tries releases first, then Git, returns the newest)
  static Future<String?> getLatestCLIVersionAny() async {
    final releaseVersion = await getLatestCLIVersion();
    final gitVersion = await getLatestCLIVersionFromGit();
    
    // If we have both versions, return the newest one
    if (releaseVersion != null && gitVersion != null) {
      return compareVersions(releaseVersion, gitVersion) >= 0 
          ? releaseVersion 
          : gitVersion;
    }
    
    // If we only have one, return it
    return releaseVersion ?? gitVersion;
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
    final parts1 = version1.split('.').map(int.parse).toList();
    final parts2 = version2.split('.').map(int.parse).toList();
    
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