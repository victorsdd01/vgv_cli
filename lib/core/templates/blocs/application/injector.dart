import 'package:get_it/get_it.dart';
import '../core/network/http_client.dart';
import '../core/utils/secure_storage_utils.dart';
import '../core/database/app_database.dart';
import '../features/home/domain/repositories/home_repository.dart';
import '../features/home/domain/use_cases/home_use_cases.dart';
import '../features/home/presentation/blocs/home_bloc/home_bloc.dart';
import '../features/home/data/repositories/home_repository_impl.dart';
import '../features/home/data/datasources/remote/home_remote_datasource.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/use_cases/auth_use_cases.dart';
import '../features/auth/presentation/blocs/auth_bloc/auth_bloc.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/data/datasources/remote/auth_remote_datasource.dart';
import '../features/auth/data/datasources/local/auth_local_datasource.dart';
import '../features/settings/presentation/blocs/settings_bloc/settings_bloc.dart';

class Injector {
  Injector._();

  static final GetIt _locator = GetIt.instance;

  static void init() {
    _other();
    _registerDataSources();
    _registerRepositories();
    _registerUseCases();
    _registerBlocs();
  }

  static T get<T extends Object>() => _locator<T>();

  static void registerSingleton<T extends Object>(T instance) {
    _locator.registerSingleton<T>(instance);
  }

  static void registerLazySingleton<T extends Object>(T Function() factory) {
    _locator.registerLazySingleton<T>(factory);
  }

  static void registerFactory<T extends Object>(T Function() factory) {
    _locator.registerFactory<T>(factory);
  }

  static void reset() {
    _locator.reset();
  }

  static void _other() {
    registerLazySingleton<HttpClient>(
      () => HttpClient('https://api.example.com'),
    );
    registerLazySingleton<SecureStorageUtils>(
      () => SecureStorageUtils(),
    );
    registerLazySingleton<AppDatabase>(
      () => AppDatabase(),
    );
  }

  static void _registerUseCases() {
    registerLazySingleton<HomeUseCases>(
      () => HomeUseCases(repository: get<HomeRepository>()),
    );
    registerLazySingleton<AuthUseCases>(
      () => AuthUseCases(repository: get<AuthRepository>()),
    );
  }

  static void _registerRepositories() {
    registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(homeRemoteDataSource: get<HomeRemoteDataSource>()),
    );
    registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        authRemoteDataSource: get<AuthRemoteDataSource>(),
        authLocalDataSource: get<AuthLocalDataSource>(),
        secureStorageUtils: get<SecureStorageUtils>(),
      ),
    );
  }

  static void _registerDataSources() {
    registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSourceImpl(),
    );
    registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(),
    );
    registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(database: get<AppDatabase>()),
    );
  }

  static void _registerBlocs() {
    registerLazySingleton<HomeBloc>(
      () => HomeBloc(homeUseCases: get<HomeUseCases>()),
    );
    registerLazySingleton<AuthBloc>(
      () => AuthBloc(authUseCases: get<AuthUseCases>()),
    );
    registerLazySingleton<SettingsBloc>(
      () => SettingsBloc(),
    );
  }
}
