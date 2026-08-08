import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/vgv_config.dart';
import 'package:vgv_cli/domain/entities/project_config.dart';

void main() {
  group('VgvConfig.fromYamlString', () {
    test('parses org, output, flavors (list) and git', () {
      final c = VgvConfig.fromYamlString('''
org: com.acme
output: ~/projects
flavors: [dev, prod]
git: false
''');
      expect(c.organization, 'com.acme');
      expect(c.output, '~/projects');
      expect(c.flavors, <Flavor>[Flavor.dev, Flavor.production]);
      expect(c.git, isFalse);
    });

    test('accepts a comma-separated flavors string and organization alias', () {
      final c = VgvConfig.fromYamlString('''
organization: com.x
flavors: dev,staging
''');
      expect(c.organization, 'com.x');
      expect(c.flavors, <Flavor>[Flavor.dev, Flavor.staging]);
      expect(c.git, isNull);
    });

    test('ignores unknown keys and invalid flavor tokens', () {
      final c = VgvConfig.fromYamlString('''
org: com.y
flavors: [dev, bogus]
somethingElse: 42
''');
      expect(c.organization, 'com.y');
      expect(c.flavors, <Flavor>[Flavor.dev]);
    });

    test('empty / non-map / malformed yaml yields an empty config', () {
      expect(VgvConfig.fromYamlString('').organization, isNull);
      expect(VgvConfig.fromYamlString('- just\n- a\n- list').organization, isNull);
      expect(VgvConfig.fromYamlString(': : :').organization, isNull);
    });

    test('template is valid and round-trips', () {
      final c = VgvConfig.fromYamlString(VgvConfig.template);
      expect(c.organization, 'com.mycompany');
      expect(c.flavors,
          <Flavor>[Flavor.dev, Flavor.staging, Flavor.production]);
      expect(c.git, isTrue);
    });
  });
}
