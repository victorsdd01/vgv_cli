import 'package:test/test.dart';
import 'package:vgv_cli/domain/entities/project_config.dart';
import 'package:vgv_cli/domain/usecases/validate_project_config_usecase.dart';

void main() {
  late ValidateProjectConfigUseCase useCase;

  setUp(() {
    useCase = ValidateProjectConfigUseCase();
  });

  group('ValidateProjectConfigUseCase', () {
    test('returns empty list for valid config', () {
      const config = ProjectConfig(
        projectName: 'my_app',
        organizationName: 'com.example',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
      );
      expect(useCase.execute(config), isEmpty);
    });

    test('returns error for empty project name', () {
      const config = ProjectConfig(
        projectName: '',
        organizationName: 'com.example',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
      );
      final errors = useCase.execute(config);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('empty'));
    });

    test('returns error for invalid project name', () {
      const config = ProjectConfig(
        projectName: 'MyInvalidApp',
        organizationName: 'com.example',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
      );
      final errors = useCase.execute(config);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Invalid project name'));
    });

    test('returns error for empty organization', () {
      const config = ProjectConfig(
        projectName: 'my_app',
        organizationName: '',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
      );
      final errors = useCase.execute(config);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('empty'));
    });

    test('returns multiple errors for both invalid', () {
      const config = ProjectConfig(
        projectName: '',
        organizationName: '',
        stateManagement: StateManagementType.bloc,
        architecture: ArchitectureType.cleanArchitecture,
      );
      final errors = useCase.execute(config);
      expect(errors.length, 2);
    });
  });
}
