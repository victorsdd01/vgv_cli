import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/version_checker.dart';

void main() {
  group('VersionChecker.compareVersions', () {
    test('equal versions return 0', () {
      expect(VersionChecker.compareVersions('1.0.0', '1.0.0'), 0);
      expect(VersionChecker.compareVersions('2.5.3', '2.5.3'), 0);
    });

    test('older version returns -1', () {
      expect(VersionChecker.compareVersions('1.0.0', '1.0.1'), -1);
      expect(VersionChecker.compareVersions('1.0.0', '1.1.0'), -1);
      expect(VersionChecker.compareVersions('1.0.0', '2.0.0'), -1);
      expect(VersionChecker.compareVersions('1.9.9', '2.0.0'), -1);
    });

    test('newer version returns 1', () {
      expect(VersionChecker.compareVersions('1.0.1', '1.0.0'), 1);
      expect(VersionChecker.compareVersions('1.1.0', '1.0.0'), 1);
      expect(VersionChecker.compareVersions('2.0.0', '1.0.0'), 1);
      expect(VersionChecker.compareVersions('2.0.0', '1.9.9'), 1);
    });

    test('handles different length versions', () {
      expect(VersionChecker.compareVersions('1.0', '1.0.0'), 0);
      expect(VersionChecker.compareVersions('1.0.0', '1.0'), 0);
    });
  });

  group('VersionChecker.formatVersion', () {
    test('removes caret prefix', () {
      expect(VersionChecker.formatVersion('^1.0.0'), '1.0.0');
    });

    test('returns version without caret unchanged', () {
      expect(VersionChecker.formatVersion('1.0.0'), '1.0.0');
    });
  });

  group('VersionChecker.getLatestVersion', () {
    test('returns known package version', () {
      expect(VersionChecker.getLatestVersion('flutter_bloc'), '^9.1.1');
      expect(VersionChecker.getLatestVersion('go_router'), '^16.0.0');
    });

    test('returns default for unknown package', () {
      expect(VersionChecker.getLatestVersion('nonexistent_package'), '^1.0.0');
    });
  });
}
