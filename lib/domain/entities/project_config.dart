/// Represents the configuration for a Flutter project
class ProjectConfig {
  final String projectName;
  final String organizationName;
  final StateManagementType stateManagement;
  final ArchitectureType architecture;
  final bool includeGoRouter;
  final bool includeLinterRules;
  final bool includeFreezed;
  final List<PlatformType> platforms;
  final MobilePlatform mobilePlatform;
  final DesktopPlatform desktopPlatform;
  final CustomDesktopPlatforms? customDesktopPlatforms;
  final String? outputDirectory;
  final bool skipGitInit;

  /// Native flavors to generate (dev, staging, production).
  /// Each flavor gets its own applicationId/bundleId, app name and entry point.
  final List<Flavor> flavors;

  const ProjectConfig({
    required this.projectName,
    required this.organizationName,
    required this.stateManagement,
    required this.architecture,
    this.includeGoRouter = false,
    this.includeLinterRules = false,
    this.includeFreezed = false,
    this.platforms = const [PlatformType.mobile],
    this.mobilePlatform = MobilePlatform.both,
    this.desktopPlatform = DesktopPlatform.all,
    this.customDesktopPlatforms,
    this.outputDirectory,
    this.skipGitInit = false,
    this.flavors = const [Flavor.dev, Flavor.staging, Flavor.production],
  });

  /// Validates the project configuration
  bool get isValid {
    return isValidProjectName(projectName) && 
           isValidOrganizationName(organizationName);
  }

  /// Validates project name format
  static bool isValidProjectName(String name) {
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
  }

  /// Validates organization name format (allows underscores for project name compatibility)
  static bool isValidOrganizationName(String name) {
    return RegExp(r'^[a-z][a-z0-9._]*[a-z0-9]$').hasMatch(name);
  }

  @override
  String toString() {
    return 'ProjectConfig(projectName: $projectName, organizationName: $organizationName, stateManagement: $stateManagement, architecture: $architecture, includeGoRouter: $includeGoRouter, includeLinterRules: $includeLinterRules, includeFreezed: $includeFreezed, platforms: $platforms, mobilePlatform: $mobilePlatform, desktopPlatform: $desktopPlatform, customDesktopPlatforms: $customDesktopPlatforms, outputDirectory: $outputDirectory, skipGitInit: $skipGitInit, flavors: $flavors)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProjectConfig &&
        other.projectName == projectName &&
        other.organizationName == organizationName &&
        other.stateManagement == stateManagement &&
        other.architecture == architecture &&
        other.includeGoRouter == includeGoRouter &&
        other.includeLinterRules == includeLinterRules &&
        other.includeFreezed == includeFreezed &&
        other.platforms == platforms &&
        other.mobilePlatform == mobilePlatform &&
        other.desktopPlatform == desktopPlatform &&
        other.customDesktopPlatforms == customDesktopPlatforms &&
        other.outputDirectory == outputDirectory &&
        other.skipGitInit == skipGitInit &&
        other.flavors == flavors;
  }

  @override
  int get hashCode {
    return projectName.hashCode ^
        organizationName.hashCode ^
        stateManagement.hashCode ^
        architecture.hashCode ^
        includeGoRouter.hashCode ^
        includeLinterRules.hashCode ^
        includeFreezed.hashCode ^
        platforms.hashCode ^
        mobilePlatform.hashCode ^
        desktopPlatform.hashCode ^
        customDesktopPlatforms.hashCode ^
        outputDirectory.hashCode ^
        skipGitInit.hashCode ^
        flavors.hashCode;
  }
}

/// Enum representing different architecture types
enum ArchitectureType {
  cleanArchitecture,
  mvvm;

  String get displayName {
    switch (this) {
      case ArchitectureType.cleanArchitecture:
        return 'Clean Architecture';
      case ArchitectureType.mvvm:
        return 'MVVM';
    }
  }
}

/// Enum representing different platform types
enum PlatformType {
  mobile,
  web,
  desktop;

  String get displayName {
    switch (this) {
      case PlatformType.mobile:
        return 'Mobile (Android & iOS)';
      case PlatformType.web:
        return 'Web';
      case PlatformType.desktop:
        return 'Desktop (Windows, macOS, Linux)';
    }
  }

  String get shortName {
    switch (this) {
      case PlatformType.mobile:
        return 'mobile';
      case PlatformType.web:
        return 'web';
      case PlatformType.desktop:
        return 'desktop';
    }
  }
}

/// Enum representing different mobile platforms
enum MobilePlatform {
  android,
  ios,
  both;

  String get displayName {
    switch (this) {
      case MobilePlatform.android:
        return 'Android only';
      case MobilePlatform.ios:
        return 'iOS only';
      case MobilePlatform.both:
        return 'Both Android & iOS';
    }
  }
}

/// Enum representing different desktop platforms
enum DesktopPlatform {
  windows,
  macos,
  linux,
  all,
  custom;

  String get displayName {
    switch (this) {
      case DesktopPlatform.windows:
        return 'Windows only';
      case DesktopPlatform.macos:
        return 'macOS only';
      case DesktopPlatform.linux:
        return 'Linux only';
      case DesktopPlatform.all:
        return 'All platforms (Windows, macOS, Linux)';
      case DesktopPlatform.custom:
        return 'Custom selection';
    }
  }
}

/// Class to hold custom desktop platform selections
class CustomDesktopPlatforms {
  final bool windows;
  final bool macos;
  final bool linux;

  const CustomDesktopPlatforms({
    required this.windows,
    required this.macos,
    required this.linux,
  });

  bool get hasAny => windows || macos || linux;
  
  List<String> get platformList {
    final platforms = <String>[];
    if (windows) platforms.add('windows');
    if (macos) platforms.add('macos');
    if (linux) platforms.add('linux');
    return platforms;
  }
}

/// Enum representing the native build flavors of the generated project.
///
/// Each flavor maps to an Android product flavor + iOS build configuration,
/// a dedicated entry point (`main_<shortName>.dart`) and a distinct
/// applicationId/bundleId so the flavors can be installed side by side.
enum Flavor {
  dev,
  staging,
  production;

  /// Human readable name shown in prompts/summaries.
  String get displayName {
    switch (this) {
      case Flavor.dev:
        return 'Development';
      case Flavor.staging:
        return 'Staging';
      case Flavor.production:
        return 'Production';
    }
  }

  /// Identifier used for entry points, schemes and gradle flavor names.
  String get shortName {
    switch (this) {
      case Flavor.dev:
        return 'dev';
      case Flavor.staging:
        return 'staging';
      case Flavor.production:
        return 'production';
    }
  }

  /// Suffix appended to the base applicationId/bundleId.
  /// Production keeps the base id (no suffix) so store builds stay clean.
  String get applicationIdSuffix {
    switch (this) {
      case Flavor.dev:
        return '.dev';
      case Flavor.staging:
        return '.stg';
      case Flavor.production:
        return '';
    }
  }

  /// Suffix appended to the visible app name (empty for production).
  String get appNameSuffix {
    switch (this) {
      case Flavor.dev:
        return ' Dev';
      case Flavor.staging:
        return ' Stg';
      case Flavor.production:
        return '';
    }
  }

  /// Suffix appended to the versionName on Android (empty for production).
  String get versionNameSuffix {
    switch (this) {
      case Flavor.dev:
        return '-dev';
      case Flavor.staging:
        return '-stg';
      case Flavor.production:
        return '';
    }
  }
}

/// Enum representing different state management types
enum StateManagementType {
  bloc,
  provider,
  none;

  String get displayName {
    switch (this) {
      case StateManagementType.bloc:
        return 'BLoC (Business Logic Component)';
      case StateManagementType.provider:
        return 'Provider';
      case StateManagementType.none:
        return 'None (Basic Flutter project)';
    }
  }

  String get shortName {
    switch (this) {
      case StateManagementType.bloc:
        return 'bloc';
      case StateManagementType.provider:
        return 'provider';
      case StateManagementType.none:
        return 'none';
    }
  }
} 