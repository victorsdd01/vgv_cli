#!/usr/bin/env dart

import 'dart:io';

/// Version Manager for VGV CLI
/// Automatically increments version numbers for releases
class VersionManager {
  static const String _pubspecPath = 'pubspec.yaml';
  static const String _cliPath = 'lib/vgv_cli.dart';
  
  /// Get current version from pubspec.yaml
  static String getCurrentVersion() {
    final file = File(_pubspecPath);
    final content = file.readAsStringSync();
    
    final versionMatch = RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(content);
    if (versionMatch != null) {
      return versionMatch.group(1)!;
    }
    
    throw Exception('Could not find version in pubspec.yaml');
  }
  
  /// Increment version by type (major, minor, patch)
  static String incrementVersion(String currentVersion, String type) {
    final parts = currentVersion.split('.').map(int.parse).toList();
    
    switch (type.toLowerCase()) {
      case 'major':
        parts[0]++;
        parts[1] = 0;
        parts[2] = 0;
        break;
      case 'minor':
        parts[1]++;
        parts[2] = 0;
        break;
      case 'patch':
        parts[2]++;
        break;
      default:
        throw Exception('Invalid version type. Use: major, minor, or patch');
    }
    
    return parts.join('.');
  }
  
  /// Update version in pubspec.yaml
  static void updatePubspecVersion(String newVersion) {
    final file = File(_pubspecPath);
    final content = file.readAsStringSync();
    
    final updatedContent = content.replaceFirst(
      RegExp(r'version:\s*\d+\.\d+\.\d+'),
      'version: $newVersion'
    );
    
    file.writeAsStringSync(updatedContent);
    print('✅ Updated pubspec.yaml to version $newVersion');
  }
  
  /// Update version in CLI file
  static void updateCLIVersion(String newVersion) {
    final file = File(_cliPath);
    final content = file.readAsStringSync();
    
    final updatedContent = content.replaceFirst(
      RegExp(r"static const String _version = '\d+\.\d+\.\d+'"),
      "static const String _version = '$newVersion'"
    );
    
    file.writeAsStringSync(updatedContent);
    print('✅ Updated CLI version to $newVersion');
  }
  
  /// Create a new release
  static void createRelease(String type) {
    print('🚀 Creating new $type release...');
    print('');
    
    final currentVersion = getCurrentVersion();
    print('📦 Current version: $currentVersion');
    
    final newVersion = incrementVersion(currentVersion, type);
    print('📦 New version: $newVersion');
    print('');
    
    updatePubspecVersion(newVersion);
    updateCLIVersion(newVersion);
    
    print('');
    print('🎉 Release $newVersion created successfully!');
    print('');
    print('📋 Next steps:');
    print('   1. Review the changes');
    print('   2. Commit the version updates');
    print('   3. Create a git tag: git tag v$newVersion');
    print('   4. Push the tag: git push origin v$newVersion');
    print('   5. Create a GitHub release');
  }
  
  /// Show current version info
  static void showVersion() {
    final version = getCurrentVersion();
    print('📦 VGV CLI Version: $version');
    print('');
    print('📋 Version locations:');
    print('   • pubspec.yaml: $version');
    print('   • lib/vgv_cli.dart: $version');
  }
}

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('📦 VGV CLI Version Manager');
    print('');
    print('Usage:');
    print('  dart run scripts/version_manager.dart show          # Show current version');
    print('  dart run scripts/version_manager.dart major         # Increment major version');
    print('  dart run scripts/version_manager.dart minor         # Increment minor version');
    print('  dart run scripts/version_manager.dart patch         # Increment patch version');
    print('');
    print('Examples:');
    print('  dart run scripts/version_manager.dart patch         # 1.0.0 → 1.0.1');
    print('  dart run scripts/version_manager.dart minor         # 1.0.1 → 1.1.0');
    print('  dart run scripts/version_manager.dart major         # 1.1.0 → 2.0.0');
    return;
  }
  
  final command = arguments[0];
  
  try {
    switch (command) {
      case 'show':
        VersionManager.showVersion();
        break;
      case 'major':
      case 'minor':
      case 'patch':
        VersionManager.createRelease(command);
        break;
      default:
        print('❌ Unknown command: $command');
        print('Use: show, major, minor, or patch');
    }
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
} 