import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:nested/nested.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'application/application.dart';
import 'application/config/config.dart';
import 'features/home/presentation/blocs/home_bloc/home_bloc.dart';
import 'features/auth/presentation/blocs/auth_bloc/auth_bloc.dart';
import 'features/settings/presentation/blocs/settings_bloc/settings_bloc.dart';
import 'core/services/talker_service.dart';

Future<void> main({AppEnvironment? environment}) async {
  environment ??= AppEnvironment.production;

  WidgetsFlutterBinding.ensureInitialized();

  AppConfiguration.init(environment: environment);

  if (kReleaseMode) {
    debugPrintRebuildDirtyWidgets = false;
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory((await getTemporaryDirectory()).path),
  );

  if (AppConfiguration.enableLogging) {
    TalkerService.init();
  }

  Injector.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) => true;

  runApp(
    MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<AuthBloc>(
          create: (BuildContext _) => Injector.get<AuthBloc>(),
        ),
        BlocProvider<HomeBloc>(
          create: (BuildContext _) => Injector.get<HomeBloc>(),
        ),
        BlocProvider<SettingsBloc>(
          create: (BuildContext _) => Injector.get<SettingsBloc>(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    builder: (BuildContext context, SettingsState state) => MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: state.themeMode,
      routerConfig: AppRoutes.router,
      locale: Locale(state.languageCode),
      localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
      supportedLocales: AppLocalizationsSetup.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) {
        if (kReleaseMode) return child ?? const SizedBox.shrink();
        
        return Banner(
          message: _getBannerText(),
          location: BannerLocation.topEnd,
          color: _getBannerColor(),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );

  static String _getBannerText() {
    if (AppConfiguration.isDevelopment) return 'DEV';
    if (AppConfiguration.isStaging) return 'STAGE';
    return 'PROD';
  }

  static Color _getBannerColor() {
    if (AppConfiguration.isDevelopment) return const Color(0xFF4CAF50);
    if (AppConfiguration.isStaging) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}
