import '../entities/project_config.dart';

/// Repository interface for project creation operations
abstract class ProjectRepository {
  /// Creates a Flutter project with the given configuration.
  /// Returns a list of non-fatal warnings (e.g. a post-generation step such
  /// as build_runner or intl_utils failed); empty means fully successful.
  Future<List<String>> createProject(ProjectConfig config);
  
  /// Adds state management dependencies and templates to the project
  Future<void> addStateManagement(String projectName, StateManagementType stateManagement);
  
  /// Adds Go Router dependencies and templates to the project
  Future<void> addGoRouter(String projectName);
  
  /// Adds Clean Architecture structure and dependencies to the project
  Future<void> addCleanArchitecture(String projectName);
  
  /// Validates if Flutter is installed and available
  Future<bool> isFlutterInstalled();
} 