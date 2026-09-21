import '../../data/datasources/file_system_datasource.dart';
import '../../data/datasources/flutter_command_datasource.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../domain/repositories/project_repository.dart';
import '../../presentation/controllers/cli_controller.dart';
import '../utils/flutter_toolchain.dart';

/// Dependency injection container
class DependencyInjection {
  static DependencyInjection? _instance;
  static DependencyInjection get instance {
    _instance ??= DependencyInjection._();
    return _instance!;
  }

  DependencyInjection._({FlutterToolchain? toolchain})
      : toolchain = toolchain ?? const FlutterToolchain.global();

  /// How Flutter/Dart are invoked (global SDK or through FVM).
  final FlutterToolchain toolchain;

  static void initialize({FlutterToolchain? toolchain}) {
    _instance = DependencyInjection._(toolchain: toolchain);
  }

  static void reset() {
    _instance = null;
  }

  // Data Sources
  FileSystemDataSource get fileSystemDataSource => FileSystemDataSourceImpl();
  FlutterCommandDataSource get flutterCommandDataSource =>
      FlutterCommandDataSourceImpl(toolchain: toolchain);

  // Repositories
  ProjectRepository get projectRepository => ProjectRepositoryImpl(
        fileSystemDataSource: fileSystemDataSource,
        flutterCommandDataSource: flutterCommandDataSource,
        toolchain: toolchain,
      );

  // Controllers
  CliController get cliController => CliController(projectRepository);
} 