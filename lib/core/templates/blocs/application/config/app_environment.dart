import 'package:flutter/foundation.dart';

enum Environment { dev, staging, production }

class AppEnvironment {
  const AppEnvironment({
    required this.name,
    required this.baseUrl,
    this.enableLogging = true,
  });

  final String name;
  final String baseUrl;
  final bool enableLogging;

  static const AppEnvironment dev = AppEnvironment(
    name: 'Development',
    baseUrl: 'https://dev-api.example.com/api/v1',
    enableLogging: true,
  );

  static const AppEnvironment staging = AppEnvironment(
    name: 'Staging',
    baseUrl: 'https://staging-api.example.com/api/v1',
    enableLogging: true,
  );

  static const AppEnvironment production = AppEnvironment(
    name: 'Production',
    baseUrl: 'https://api.example.com/api/v1',
    enableLogging: false,
  );

  bool get isDev => this == dev;
  bool get isStaging => this == staging;
  bool get isProduction => this == production;
  bool get isReleaseMode => kReleaseMode;
}
