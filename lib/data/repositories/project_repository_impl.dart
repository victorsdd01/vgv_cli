import '../../domain/entities/project_config.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/file_system_datasource.dart';
import '../datasources/flutter_command_datasource.dart';

/// Implementation of ProjectRepository
class ProjectRepositoryImpl implements ProjectRepository {
  final FileSystemDataSource _fileSystemDataSource;
  final FlutterCommandDataSource _flutterCommandDataSource;

  ProjectRepositoryImpl({
    required FileSystemDataSource fileSystemDataSource,
    required FlutterCommandDataSource flutterCommandDataSource,
  })  : _fileSystemDataSource = fileSystemDataSource,
        _flutterCommandDataSource = flutterCommandDataSource;

  @override
  Future<void> createProject(ProjectConfig config) async {
    await _flutterCommandDataSource.createFlutterProject(
      projectName: config.projectName,
      organizationName: config.organizationName,
      platforms: config.platforms,
      mobilePlatform: config.mobilePlatform,
      desktopPlatform: config.desktopPlatform,
      customDesktopPlatforms: config.customDesktopPlatforms,
    );

    await _fileSystemDataSource.addDependencies(
      config.projectName, 
      StateManagementType.bloc, 
      true,
      true,
      true
    );

    await _fileSystemDataSource.createCleanArchitectureStructure(
      config.projectName, 
      StateManagementType.bloc,
      ArchitectureType.cleanArchitecture,
      includeGoRouter: true,
      includeFreezed: true,
    );

    await _fileSystemDataSource.createStateManagementTemplates(
      config.projectName, 
      StateManagementType.bloc,
      true
    );

    await _fileSystemDataSource.ensureCleanArchitectureFiles(config.projectName);

    if (config.includeLinterRules) {
      await _fileSystemDataSource.createLinterRules(config.projectName);
    }

    await _fileSystemDataSource.createBuildYaml(config.projectName);

    await _fileSystemDataSource.createVSCodeLaunchConfig(config.projectName);

    await _fileSystemDataSource.createGitIgnore(config.projectName);

    await _fileSystemDataSource.createInternationalization(config.projectName);

    await _fileSystemDataSource.createBarrelFiles(
      config.projectName, 
      StateManagementType.bloc, 
      true,
      true
    );

    // IMPORTANTE: Primero instalar dependencias antes de generar código
    await _flutterCommandDataSource.cleanBuildCache(config.projectName);

    // Generar archivos de localización (requiere intl_utils instalado)
    await _flutterCommandDataSource.generateLocalizationFiles(config.projectName);

    // Generar archivos de Freezed y Drift (requiere build_runner instalado)
    await _flutterCommandDataSource.runBuildRunner(config.projectName);

    // Setup CocoaPods for iOS/macOS platforms
    await _flutterCommandDataSource.setupCocoaPods(config.projectName, config.platforms);
  }

  @override
  Future<void> addStateManagement(String projectName, StateManagementType stateManagement) async {
    // This method is called when only state management is needed (no Go Router)
    // Add dependencies to pubspec.yaml
    await _fileSystemDataSource.addDependencies(projectName, stateManagement, false, false, false);

    // Create directory structure
    await _fileSystemDataSource.createCleanArchitectureStructure(projectName, stateManagement, ArchitectureType.cleanArchitecture);

    // Create state management templates
    await _fileSystemDataSource.createStateManagementTemplates(projectName, stateManagement, false);

    // Update main.dart
    await _fileSystemDataSource.updateMainFile(projectName, stateManagement, false, false, false);
  }

  @override
  Future<void> addGoRouter(String projectName) async {
    // This method is called when Go Router is added to an existing project
    // We need to get the current state management type from the project
    // For now, we'll assume it's none and let the main createProject handle the integration
    
    // Create Go Router templates
    await _fileSystemDataSource.createGoRouterTemplates(projectName);
  }

           @override
         Future<void> addCleanArchitecture(String projectName) async {
           // This method is called when Clean Architecture is added to an existing project
           // For now, we'll assume no state management when adding CA to existing project
           await _fileSystemDataSource.createCleanArchitectureStructure(projectName, StateManagementType.none, ArchitectureType.cleanArchitecture, includeFreezed: false);
         }

  @override
  Future<bool> isFlutterInstalled() async {
    return await _flutterCommandDataSource.isFlutterInstalled();
  }
} 