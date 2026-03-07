import 'package:test/test.dart';
import 'package:vgv_cli/domain/entities/project_config.dart';

void main() {
  group('ProjectConfig.isValidProjectName', () {
    test('accepts valid lowercase names', () {
      expect(ProjectConfig.isValidProjectName('my_app'), true);
      expect(ProjectConfig.isValidProjectName('flutter_app'), true);
      expect(ProjectConfig.isValidProjectName('app123'), true);
      expect(ProjectConfig.isValidProjectName('a'), true);
    });

    test('rejects names starting with number', () {
      expect(ProjectConfig.isValidProjectName('123app'), false);
    });

    test('rejects names with uppercase', () {
      expect(ProjectConfig.isValidProjectName('MyApp'), false);
      expect(ProjectConfig.isValidProjectName('myApp'), false);
    });

    test('rejects names with dashes', () {
      expect(ProjectConfig.isValidProjectName('my-app'), false);
    });

    test('rejects names with spaces', () {
      expect(ProjectConfig.isValidProjectName('my app'), false);
    });

    test('rejects empty name', () {
      expect(ProjectConfig.isValidProjectName(''), false);
    });

    test('rejects names with special characters', () {
      expect(ProjectConfig.isValidProjectName('my@app'), false);
      expect(ProjectConfig.isValidProjectName('my.app'), false);
    });
  });

  group('ProjectConfig.isValidOrganizationName', () {
    test('accepts valid org names', () {
      expect(ProjectConfig.isValidOrganizationName('com.example'), true);
      expect(ProjectConfig.isValidOrganizationName('dev.mycompany'), true);
      expect(ProjectConfig.isValidOrganizationName('com.my_app'), true);
    });

    test('rejects single character', () {
      expect(ProjectConfig.isValidOrganizationName('a'), false);
    });

    test('rejects names starting with number', () {
      expect(ProjectConfig.isValidOrganizationName('1com.example'), false);
    });

    test('rejects names ending with dot', () {
      expect(ProjectConfig.isValidOrganizationName('com.example.'), false);
    });

    test('rejects empty org name', () {
      expect(ProjectConfig.isValidOrganizationName(''), false);
    });
  });

  group('ProjectConfig.isValid', () {
    test('valid config returns true', () {
      const config = ProjectConfig(
        projectName: 'my_app',
        organizationName: 'com.example',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
      );
      expect(config.isValid, true);
    });

    test('invalid project name returns false', () {
      const config = ProjectConfig(
        projectName: 'MyApp',
        organizationName: 'com.example',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
      );
      expect(config.isValid, false);
    });

    test('invalid org name returns false', () {
      const config = ProjectConfig(
        projectName: 'my_app',
        organizationName: '',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
      );
      expect(config.isValid, false);
    });
  });

  group('CustomDesktopPlatforms', () {
    test('hasAny returns true when at least one platform selected', () {
      const platforms = CustomDesktopPlatforms(
        windows: true,
        macos: false,
        linux: false,
      );
      expect(platforms.hasAny, true);
    });

    test('hasAny returns false when no platforms selected', () {
      const platforms = CustomDesktopPlatforms(
        windows: false,
        macos: false,
        linux: false,
      );
      expect(platforms.hasAny, false);
    });

    test('platformList returns correct list', () {
      const platforms = CustomDesktopPlatforms(
        windows: true,
        macos: false,
        linux: true,
      );
      expect(platforms.platformList, ['windows', 'linux']);
    });
  });
}
