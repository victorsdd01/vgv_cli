import 'package:flutter/foundation.dart';
import 'app_environment.dart';

class AppConfiguration {
  AppConfiguration._();

  static AppEnvironment? _environment;

  static AppEnvironment get environment {
    assert(_environment != null, 'AppConfiguration.init() must be called first');
    return _environment!;
  }

  static bool get isInitialized => _environment != null;

  static String get baseUrl => environment.baseUrl;

  static bool get enableLogging => environment.enableLogging && !kReleaseMode;

  static bool get isProduction => _environment == AppEnvironment.production;

  static bool get isDevelopment => _environment == AppEnvironment.dev;

  static bool get isStaging => _environment == AppEnvironment.staging;

  static void init({required AppEnvironment environment}) {
    assert(_environment == null, 'AppConfiguration.init() should only be called once');
    _environment = environment;
  }
}
