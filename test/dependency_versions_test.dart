import 'package:test/test.dart';
import 'package:vgv_cli/core/templates/dependency_versions.dart';

String pubspecWithSdk(String constraint) => '''
name: demo
environment:
  sdk: $constraint

dependencies:
  flutter:
    sdk: flutter
''';

void main() {
  group('pinsForPubspec', () {
    test('Dart 3.13+ gets the main tables (freezed 4)', () {
      final pins = pinsForPubspec(pubspecWithSdk('^3.13.4'));
      expect(pins['freezed'], kDevDependencyVersions['freezed']);
      expect(pins['freezed'], startsWith('^4.'));
      expect(pins['go_router'], kDependencyVersions['go_router']);
    });

    test('Dart 3.12 gets the legacy overrides (freezed 3)', () {
      final pins = pinsForPubspec(pubspecWithSdk('^3.12.2'));
      for (final entry in kLegacyDartVersionOverrides.entries) {
        expect(pins[entry.key], entry.value, reason: entry.key);
      }
      expect(pins['freezed'], startsWith('^3.'));
      // Packages without an override keep the main pin.
      expect(pins['flutter_bloc'], kDependencyVersions['flutter_bloc']);
    });

    test('reads range and quoted constraints', () {
      expect(
        pinsForPubspec(pubspecWithSdk("'>=3.12.0 <4.0.0'"))['freezed'],
        startsWith('^3.'),
      );
      expect(
        pinsForPubspec(pubspecWithSdk('">=3.13.0 <4.0.0"'))['freezed'],
        startsWith('^4.'),
      );
    });

    test('ignores the flutter `sdk: flutter` entries', () {
      const pubspec = '''
name: demo
dependencies:
  flutter:
    sdk: flutter
''';
      expect(pinsForPubspec(pubspec), kAllPinnedVersions);
    });

    test('a newer major is never treated as legacy', () {
      expect(pinsForDart(4, 0)['freezed'], startsWith('^4.'));
    });
  });
}
