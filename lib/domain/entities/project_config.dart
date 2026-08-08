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

  /// Whether to scaffold a full Fastlane setup (Gemfile + android/ios lanes +
  /// store metadata + fastlane-config.md).
  final bool includeFastlane;

  /// Whether to scaffold lefthook git hooks (pre-commit: format/analyze/test).
  final bool includeLefthook;

  /// Brand seed color as a 6-digit hex (no leading #), e.g. `4B60AA`. When set,
  /// the generated Material 3 theme uses `ColorScheme.fromSeed` with it. Null =
  /// keep the default blue.
  final String? seedColorHex;

  /// Path to a 1024×1024 master app icon. When set, a full launcher icon set is
  /// generated for the selected platforms. Null = keep the default Flutter icon.
  final String? iconMasterPath;

  /// Whether to configure a native splash screen (flutter_native_splash).
  final bool includeSplash;

  /// Whether to set a sensible min window size + title on desktop
  /// (window_manager). Only meaningful for desktop targets.
  final bool desktopWindow;

  /// AI agents to generate a coding-rules file for (BLoC+freezed,
  /// TStateless/TStatefull, no setState, Clean Architecture…). Empty = none.
  final List<AiAgent> aiAgents;

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
    this.includeFastlane = false,
    this.includeLefthook = false,
    this.seedColorHex,
    this.iconMasterPath,
    this.includeSplash = false,
    this.desktopWindow = false,
    this.aiAgents = const [],
  });

  /// Validates the project configuration
  bool get isValid {
    return isValidProjectName(projectName) &&
           isValidOrganizationName(organizationName);
  }

  /// Whether native flavors (Android product flavors / iOS schemes) apply.
  /// Flavors are only wired natively for mobile; web and (Windows/Linux)
  /// desktop do not support `flutter run --flavor`.
  bool get usesNativeFlavors => platforms.contains(PlatformType.mobile);

  /// Production base bundle id (`flutter create` appends the project name to
  /// `--org`). If the org already ends with the project name we avoid the
  /// duplicated tail — e.g. org `com.test2` + project `test2` → `com.test2`,
  /// not `com.test2.test2`. Otherwise → `<org>.<projectName>`.
  String get baseBundleId => organizationName.endsWith('.$projectName')
      ? organizationName
      : '$organizationName.$projectName';

  /// The value to pass to `flutter create --org` so the resulting
  /// applicationId/bundleId equals [baseBundleId] (flutter appends the project
  /// name, so we strip the trailing `.<projectName>`).
  String get organizationForCreate =>
      baseBundleId.substring(0, baseBundleId.length - projectName.length - 1);

  /// Validates project name format
  static bool isValidProjectName(String name) {
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
  }

  /// Validates organization name format: dot-separated segments, each starting
  /// with a letter (e.g. `com.example`). Rejects consecutive/trailing dots,
  /// which would produce an invalid applicationId/bundleId.
  static bool isValidOrganizationName(String name) {
    if (name.length < 2) return false;
    return RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$').hasMatch(name);
  }

  @override
  String toString() {
    return 'ProjectConfig(projectName: $projectName, organizationName: $organizationName, stateManagement: $stateManagement, architecture: $architecture, includeGoRouter: $includeGoRouter, includeLinterRules: $includeLinterRules, includeFreezed: $includeFreezed, platforms: $platforms, mobilePlatform: $mobilePlatform, desktopPlatform: $desktopPlatform, customDesktopPlatforms: $customDesktopPlatforms, outputDirectory: $outputDirectory, skipGitInit: $skipGitInit, flavors: $flavors, includeFastlane: $includeFastlane, includeLefthook: $includeLefthook, seedColorHex: $seedColorHex, iconMasterPath: $iconMasterPath, includeSplash: $includeSplash, desktopWindow: $desktopWindow, aiAgents: $aiAgents)';
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
        other.flavors == flavors &&
        other.includeFastlane == includeFastlane &&
        other.includeLefthook == includeLefthook &&
        other.seedColorHex == seedColorHex &&
        other.iconMasterPath == iconMasterPath &&
        other.includeSplash == includeSplash &&
        other.desktopWindow == desktopWindow &&
        other.aiAgents == aiAgents;
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
        flavors.hashCode ^
        includeFastlane.hashCode ^
        includeLefthook.hashCode ^
        seedColorHex.hashCode ^
        iconMasterPath.hashCode ^
        includeSplash.hashCode ^
        desktopWindow.hashCode ^
        aiAgents.hashCode;
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
/// Each flavor maps to an Android product flavor + iOS build configuration and
/// scheme, a dedicated Dart entry point (`main_<entryPoint>.dart`) and a
/// distinct bundleId so the flavors can be installed side by side.
///
/// The bundleId the user enters is treated as **production** (the clean base);
/// dev/staging derive their id by appending a suffix. e.g. base `com.test.app`:
///   production -> com.test.app        (no suffix)
///   dev        -> com.test.app.dev
///   staging    -> com.test.app.stage
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

  /// Name used for `flutter --flavor`, the Android product flavor and the iOS
  /// scheme / build configuration (matches the JornaDay reference: dev/prod).
  String get flavorName {
    switch (this) {
      case Flavor.dev:
        return 'dev';
      case Flavor.staging:
        return 'staging';
      case Flavor.production:
        return 'prod';
    }
  }

  /// Dart entry point file name: `lib/main_<entryPoint>.dart`.
  String get entryPoint {
    switch (this) {
      case Flavor.dev:
        return 'dev';
      case Flavor.staging:
        return 'staging';
      case Flavor.production:
        return 'production';
    }
  }

  /// `AppEnvironment.<environment>` used inside the entry point.
  String get environment {
    switch (this) {
      case Flavor.dev:
        return 'dev';
      case Flavor.staging:
        return 'staging';
      case Flavor.production:
        return 'production';
    }
  }

  /// Suffix appended to the base bundleId/applicationId.
  /// Production keeps the base id the user typed (no suffix).
  String get bundleIdSuffix {
    switch (this) {
      case Flavor.dev:
        return '.dev';
      case Flavor.staging:
        return '.stage';
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
        return ' Stage';
      case Flavor.production:
        return '';
    }
  }

  /// Full bundleId for this flavor given the [baseId] the user entered
  /// (the base id is the production id).
  String bundleId(String baseId) => '$baseId$bundleIdSuffix';

  /// Parses a user-supplied flavor token (case-insensitive, lenient aliases).
  /// Returns null if it doesn't match any flavor.
  static Flavor? tryParse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'dev':
      case 'develop':
      case 'development':
        return Flavor.dev;
      case 'stg':
      case 'stage':
      case 'staging':
        return Flavor.staging;
      case 'prod':
      case 'production':
        return Flavor.production;
      default:
        return null;
    }
  }
}

/// AI coding agents the CLI can generate a rules/conventions file for.
/// The rule content is identical; only the file the tool reads differs.
enum AiAgent {
  claude,
  cursor,
  copilot,
  gemini,
  windsurf,
  agentsMd;

  /// Human readable name shown in the prompt.
  String get displayName {
    switch (this) {
      case AiAgent.claude:
        return 'Claude Code (CLAUDE.md)';
      case AiAgent.cursor:
        return 'Cursor (.cursorrules)';
      case AiAgent.copilot:
        return 'GitHub Copilot (.github/copilot-instructions.md)';
      case AiAgent.gemini:
        return 'Gemini (GEMINI.md)';
      case AiAgent.windsurf:
        return 'Windsurf (.windsurfrules)';
      case AiAgent.agentsMd:
        return 'Generic (AGENTS.md)';
    }
  }

  /// Path (relative to the project root) of the rules file for this agent.
  String get rulesFilePath {
    switch (this) {
      case AiAgent.claude:
        return 'CLAUDE.md';
      case AiAgent.cursor:
        return '.cursorrules';
      case AiAgent.copilot:
        return '.github/copilot-instructions.md';
      case AiAgent.gemini:
        return 'GEMINI.md';
      case AiAgent.windsurf:
        return '.windsurfrules';
      case AiAgent.agentsMd:
        return 'AGENTS.md';
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