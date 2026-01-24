class TemplateContents {
  TemplateContents._();

  static const String _core_database_app_database_dart = r'''import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text()();
  TextColumn get name => text().nullable()();
  TextColumn get token => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: <Type>[Users])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<User?> getUserByEmail(String email) async {
    final SimpleSelectStatement<$UsersTable, User> query = select(users)..where((Users u) => u.email.equals(email));
    return await query.getSingleOrNull();
  }

  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  Future<bool> updateUser(User user) async {
    await (update(users)..where((Users u) => u.id.equals(user.id))).replace(user);
    return true;
  }

  Future<bool> deleteUser(int id) async {
    final int deleted = await (delete(users)..where((Users u) => u.id.equals(id))).go();
    return deleted > 0;
  }

  Future<void> clearUsers() => delete(users).go();

  Future<List<User>> getAllUsers() => select(users).get();
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final Directory dbFolder = await getApplicationDocumentsDirectory();
  final File file = File(p.join(dbFolder.path, 'app.db'));
  return NativeDatabase(file);
});

''';
  static const String _core_core_dart = r'''export 'errors/failures.dart';
export 'utils/helpers/number_helper.dart';
export 'utils/secure_storage_utils.dart';
export 'utils/toast_util.dart';
export 'network/http_client.dart';
export 'states/tstatefull.dart';
export 'states/tstateless.dart';
export 'enums/server_status.dart';
export 'services/talker_service.dart';

''';
  static const String _core_network_http_client_dart = r'''import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../application/injector.dart';
import '../services/talker_service.dart';
import '../utils/secure_storage_utils.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

enum RequestType { GET, POST, PUT, DELETE, PATCH }

class RefreshTokenAuthException implements Exception {
  final String message;
  RefreshTokenAuthException(this.message);
  
  @override
  String toString() => 'RefreshTokenAuthException: $message';
}

class HttpClient {
  final Dio _dio;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = <_PendingRequest>[];

  HttpClient(String? baseUrl, {Map<String, String>? defaultHeaders})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? '',
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ) {
    _dio.interceptors.addAll(<Interceptor>[
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: true,
        ),
      TalkerDioLogger(
        talker: TalkerService.instance,
        settings: const TalkerDioLoggerSettings(
          printRequestHeaders: false,
          printRequestData: false,
          printResponseHeaders: false,
          printResponseData: false,
          printResponseMessage: false,
        ),
      ),
      _buildInterceptor(),
    ]);
  }

  Interceptor _buildInterceptor() => InterceptorsWrapper(
    onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
      final String? token = await getToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onResponse: (Response<dynamic> response, ResponseInterceptorHandler handler) {
      handler.next(response);
    },
    onError: (DioException error, ErrorInterceptorHandler handler) async {
      if (error.response?.statusCode == 401) {
        final RequestOptions options = error.requestOptions;
        
        if (options.path.contains('/auth/login') || options.path.contains('/auth/refresh')) {
          return handler.next(error);
        }
        
        if (options.headers['retry'] == true) {
          return handler.next(error);
        }

        if (_isRefreshing) {
          final Completer<Response<dynamic>> completer = Completer<Response<dynamic>>();
          _pendingRequests.add(_PendingRequest(
            options: options,
            handler: handler,
            completer: completer,
          ));
          return completer.future.then((Response<dynamic> response) {
            handler.resolve(response);
          }).catchError((dynamic e) {
            handler.next(e as DioException);
          });
        }
        
        _isRefreshing = true;
        try {
          final String? newToken = await refreshToken();
          
          if (newToken != null && newToken.isNotEmpty) {
            options.headers['retry'] = true;
            options.headers['Authorization'] = 'Bearer $newToken';
            
            try {
              final Response<dynamic> response = await _dio.request(
                options.path,
                options: Options(
                  method: options.method,
                  headers: options.headers,
                ),
                data: options.data,
                queryParameters: options.queryParameters,
              );
              
              for (final _PendingRequest pendingRequest in _pendingRequests) {
                try {
                  pendingRequest.options.headers['retry'] = true;
                  pendingRequest.options.headers['Authorization'] = 'Bearer $newToken';
                  
                  final Response<dynamic> pendingResponse = await _dio.request(
                    pendingRequest.options.path,
                    options: Options(
                      method: pendingRequest.options.method,
                      headers: pendingRequest.options.headers,
                    ),
                    data: pendingRequest.options.data,
                    queryParameters: pendingRequest.options.queryParameters,
                  );
                  pendingRequest.completer.complete(pendingResponse);
                } catch (e) {
                  pendingRequest.completer.completeError(e);
                }
              }
              _pendingRequests.clear();
              
              return handler.resolve(response);
            } on DioException catch (retryError) {
              for (final _PendingRequest pendingRequest in _pendingRequests) {
                pendingRequest.completer.completeError(retryError);
              }
              _pendingRequests.clear();
              
              return handler.next(retryError);
            }
          } else {
            for (final _PendingRequest pendingRequest in _pendingRequests) {
              pendingRequest.completer.completeError(error);
            }
            _pendingRequests.clear();
            
            return handler.next(error);
          }
        } on RefreshTokenAuthException {
          for (final _PendingRequest pendingRequest in _pendingRequests) {
            pendingRequest.completer.completeError(error);
          }
          _pendingRequests.clear();
          
          return handler.next(error);
        } catch (e) {
          for (final _PendingRequest pendingRequest in _pendingRequests) {
            pendingRequest.completer.completeError(error);
          }
          _pendingRequests.clear();
          
          return handler.next(error);
        } finally {
          _isRefreshing = false;
        }
      }
      
      handler.next(error);
    },
  );

  Future<Response<dynamic>> request({
    required String endpoint,
    required RequestType method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool asMultipart = false,
    bool asFormUrlEncoded = false,
    ResponseType responseType = ResponseType.json,
  }) async {
    try {
      Object? payload = data;
      if (asMultipart && data is! FormData) {
        if (data is Map<String, dynamic>) {
          payload = FormData.fromMap(data);
        }
      }
      String? contentTypeFromHeaders = headers?['Content-Type'] as String?;
      final bool isMultipart = payload is FormData;
      final String computedContentType =
          contentTypeFromHeaders ??
          (isMultipart
              ? 'multipart/form-data'
              : (asFormUrlEncoded
                    ? Headers.formUrlEncodedContentType
                    : Headers.jsonContentType));

      final Options opts = Options(
        headers: headers,
        responseType: responseType,
        contentType: computedContentType,
      );
      late final Response<dynamic> response;
      switch (method) {
        case RequestType.GET:
          response = await _dio.get(
            endpoint,
            queryParameters: queryParameters,
            options: opts,
          );
          break;
        case RequestType.POST:
          response = await _dio.post(
            endpoint,
            data: payload,
            queryParameters: queryParameters,
            options: opts,
          );
          break;
        case RequestType.PUT:
          response = await _dio.put(
            endpoint,
            data: payload,
            queryParameters: queryParameters,
            options: opts,
          );
          break;
        case RequestType.DELETE:
          response = await _dio.delete(
            endpoint,
            data: payload,
            queryParameters: queryParameters,
            options: opts,
          );
          break;
        case RequestType.PATCH:
          response = await _dio.patch(
            endpoint,
            data: payload,
            queryParameters: queryParameters,
            options: opts,
          );
          break;
      }
      return response;
    } on DioException {
      rethrow;
    }
  }

  Future<String?> getToken() async => await Injector.get<SecureStorageUtils>().read('accessToken');

  Future<String?> refreshToken() async {
    final String? currentRefreshToken = await Injector.get<SecureStorageUtils>().read('refreshToken');
    
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      throw RefreshTokenAuthException('No refresh token available');
    }

    final Dio refreshDio = Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    try {
      final Response<dynamic> response = await refreshDio.post(
        '/auth/refresh',
        data: <String, dynamic>{
          'refreshToken': currentRefreshToken,
        },
      );
      
      if (response.data?['data'] == null) {
        return null;
      }
      
      final Map<String, dynamic> responseData = response.data['data'] as Map<String, dynamic>;
      final String? newAccessToken = responseData['accessToken'] as String?;
      final String? newRefreshToken = responseData['refreshToken'] as String?;
      
      if (newAccessToken == null || newAccessToken.isEmpty) {
        return null;
      }

      await Injector.get<SecureStorageUtils>().write('accessToken', newAccessToken);
      
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await Injector.get<SecureStorageUtils>().write('refreshToken', newRefreshToken);
      }

      return newAccessToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw RefreshTokenAuthException('Refresh token expired or invalid');
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class _PendingRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  final Completer<Response<dynamic>> completer;

  _PendingRequest({
    required this.options,
    required this.handler,
    required this.completer,
  });
}

''';
  static const String _core_enums_server_status_dart = r'''enum ServerStatus {
  none,
  conection_refused,
  available,
  unavailable;
}

''';
  static const String _core_utils_secure_storage_utils_dart = r'''import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageUtils {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();

  Future<Map<String, String>> readAll() => _storage.readAll();
}

''';
  static const String _core_utils_toast_util_dart = r'''import 'package:flutter/material.dart';

class ToastUtil {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

''';
  static const String _core_utils_helpers_number_helper_dart = r'''class NumberHelper {
  static String formatNumber(num value) => value.toStringAsFixed(2);
}

''';
  static const String _core_states_tstateless_dart = r'''import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import '../../application/generated/l10n.dart';

/// Base class for stateless widgets with common utilities
/// 
/// Usage:
/// ```dart
/// class MyPage extends TStateless<MyBloc> {
///   const MyPage({super.key});
///   
///   @override
///   MyBloc? get bloc => null; // or context.read<MyBloc>() if needed
///   
///   @override
///   Widget bodyWidget(BuildContext context, ThemeData theme, S translation) {
///     return Scaffold(
///       body: Text(translation.hello),
///     );
///   }
/// }
/// ```
abstract class TStateless<Bloc extends BlocBase<dynamic>?>
    extends StatelessWidget {
  const TStateless({super.key});

  /// Override to provide access to a BLoC instance
  Bloc get bloc;

  /// Build your widget here with access to common utilities
  /// 
  /// - [context] - BuildContext
  /// - [theme] - Current ThemeData
  /// - [translation] - Localization strings
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  );

  @override
  Widget build(BuildContext context) => bodyWidget(
    context,
    Theme.of(context),
    S.of(context),
  );
}

''';
  static const String _core_states_tstatefull_dart = r'''import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import '../../application/generated/l10n.dart';

/// Base class for stateful widgets with common utilities
/// 
/// Usage:
/// ```dart
/// class MyPage extends StatefulWidget {
///   const MyPage({super.key});
///   
///   @override
///   State<MyPage> createState() => _MyPageState();
/// }
/// 
/// class _MyPageState extends TStateful<MyPage, MyBloc> {
///   @override
///   MyBloc? get bloc => context.read<MyBloc>();
///   
///   @override
///   Widget bodyWidget(BuildContext context, ThemeData theme, S translation) {
///     return Scaffold(
///       body: Text(translation.hello),
///     );
///   }
/// }
/// ```
abstract class TStateful<
  T extends StatefulWidget,
  Bloc extends BlocBase<dynamic>?
> extends State<T> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => false;

  /// Override to provide access to a BLoC instance
  Bloc get bloc;

  /// Build your widget here with access to common utilities
  /// 
  /// - [context] - BuildContext
  /// - [theme] - Current ThemeData
  /// - [translation] - Localization strings
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return bodyWidget(
      context,
      Theme.of(context),
      S.of(context),
    );
  }
}

''';
  static const String _core_errors_failures_dart = r'''import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure({required this.message});

  @override
  List<Object?> get props => <Object?>[message];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

''';
  static const String _core_services_talker_service_dart = r'''import 'package:talker_flutter/talker_flutter.dart';

class TalkerService {
  TalkerService._();
  
  static Talker? _instance;
  
  static Talker init() {
    if (_instance != null) {
      return _instance!;
    }

    _instance = TalkerFlutter.init(
      settings: TalkerSettings(
        enabled: true,
        useHistory: true,
        useConsoleLogs: false,
        maxHistoryItems: 1000,
      ),
    );

    return _instance!;
  }

  static Talker get instance {
    if (_instance == null) {
      return init();
    }
    return _instance!;
  }

  static void dispose() {
    _instance = null;
  }
}

''';
  static const String _features_home_data_datasources_remote_home_remote_datasource_dart = r'''import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../models/home_model.dart';

abstract interface class HomeRemoteDataSource {
  Future<Either<Failure, List<HomeModel>>> fetchData();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  @override
  Future<Either<Failure, List<HomeModel>>> fetchData() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      final List<HomeModel> models = <HomeModel>[
        const HomeModel(id: '1', title: 'Home Item 1', description: 'Description 1'),
        const HomeModel(id: '2', title: 'Home Item 2', description: 'Description 2'),
      ];
      return Right<Failure, List<HomeModel>>(models);
    } catch (e) {
      return Left<Failure, List<HomeModel>>(ServerFailure(message: 'Failed to fetch data: $e'));
    }
  }
}

''';
  static const String _features_home_data_repositories_home_repository_impl_dart = r'''import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/remote/home_remote_datasource.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/entities/home_entity.dart';
import '../models/home_model.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({
    required this.homeRemoteDataSource,
  });

  final HomeRemoteDataSource homeRemoteDataSource;

  @override
  Future<Either<Failure, List<HomeEntity>>> fetchData() async {
    final Either<Failure, List<HomeModel>> result = await homeRemoteDataSource.fetchData();
    return result.fold(
      (Failure failure) => Left<Failure, List<HomeEntity>>(failure),
      (List<HomeModel> models) => Right<Failure, List<HomeEntity>>(models.map((HomeModel model) => HomeEntity.fromModel(model)).toList()),
    );
  }
}

''';
  static const String _features_home_data_models_home_model_dart = r'''import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_model.freezed.dart';
part 'home_model.g.dart';

@freezed
abstract class HomeModel with _$HomeModel {
  const factory HomeModel({
    required String id,
    required String title,
    required String description,
  }) = _HomeModel;

  factory HomeModel.fromJson(Map<String, dynamic> json) => _$HomeModelFromJson(json);
}

''';
  static const String _features_home_domain_repositories_home_repository_dart = r'''import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/home_entity.dart';

abstract interface class HomeRepository {
  Future<Either<Failure, List<HomeEntity>>> fetchData();
}

''';
  static const String _features_home_domain_use_cases_home_use_cases_dart = r'''import 'package:dartz/dartz.dart';
import '../repositories/home_repository.dart';
import '../entities/home_entity.dart';
import '../../../../core/errors/failures.dart';

class HomeUseCases {
  const HomeUseCases({
    required HomeRepository repository,
  }) : _homeRepository = repository;

  final HomeRepository _homeRepository;

  Future<Either<Failure, List<HomeEntity>>> fetchData() async => await _homeRepository.fetchData();
}

''';
  static const String _features_home_domain_entities_home_entity_dart = r'''import 'package:freezed_annotation/freezed_annotation.dart';
import '../../data/models/home_model.dart';

part 'home_entity.freezed.dart';
part 'home_entity.g.dart';

@freezed
abstract class HomeEntity with _$HomeEntity {
  const factory HomeEntity({
    required String id,
    required String title,
    required String description,
  }) = _HomeEntity;

  factory HomeEntity.fromJson(Map<String, dynamic> json) => _$HomeEntityFromJson(json);

  factory HomeEntity.fromModel(HomeModel model) => HomeEntity(
    id: model.id,
    title: model.title,
    description: model.description,
  );
}

''';
  static const String _features_home_presentation_blocs_home_bloc_home_state_dart = r'''part of 'home_bloc.dart';

@freezed
abstract class HomeStatus with _$HomeStatus {
  const factory HomeStatus({
    @Default(false) bool isGetItems,
  }) = _HomeStatus;
}

@freezed
abstract class HomeSuccessStatus with _$HomeSuccessStatus {
  const factory HomeSuccessStatus({
    @Default(false) bool getItems,
  }) = _HomeSuccessStatus;
}

@freezed
abstract class HomeErrorStatus with _$HomeErrorStatus {
  const factory HomeErrorStatus({
    @Default(false) bool getItems,
  }) = _HomeErrorStatus;
}

@freezed
abstract class HomeState with _$HomeState {
  const factory HomeState({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(HomeStatus()) HomeStatus status,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(HomeSuccessStatus()) HomeSuccessStatus successStatus,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(HomeErrorStatus()) HomeErrorStatus errorStatus,
    @JsonKey(includeFromJson: false, includeToJson: false)
    Failure? failure,
    @Default(<HomeEntity>[]) List<HomeEntity> items,
  }) = _HomeState;
}

''';
  static const String _features_home_presentation_blocs_home_bloc_home_bloc_dart = r'''import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../domain/use_cases/home_use_cases.dart';
import '../../../domain/entities/home_entity.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends HydratedBloc<HomeEvent, HomeState> {
  final HomeUseCases _homeUseCases;

  HomeBloc({
    required HomeUseCases homeUseCases,
  }) : _homeUseCases = homeUseCases,
       super(const HomeState()) {
    on<_Initialized>(_onInitialized);
    on<_ResetSuccessAndErrorStatus>(_onResetSuccessAndErrorStatus);
  }

  void _onResetSuccessAndErrorStatus(
    _ResetSuccessAndErrorStatus event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      successStatus: event.successStatus ?? state.successStatus,
      errorStatus: event.errorStatus ?? state.errorStatus,
      failure: null,
    ));
  }

  Future<void> _onInitialized(_Initialized event, Emitter<HomeState> emit) async {
    emit(state.copyWith(
      status: state.status.copyWith(isGetItems: true),
      successStatus: state.successStatus.copyWith(getItems: false),
      errorStatus: state.errorStatus.copyWith(getItems: false),
      failure: null,
    ));
    
    final Either<Failure, List<HomeEntity>> result = await _homeUseCases.fetchData();
    
    result.fold(
      (Failure failure) {
        emit(state.copyWith(
          status: state.status.copyWith(isGetItems: false),
          errorStatus: state.errorStatus.copyWith(getItems: true),
          failure: failure,
        ));
      },
      (List<HomeEntity> entities) {
        emit(state.copyWith(
          items: entities,
          status: state.status.copyWith(isGetItems: false),
          successStatus: state.successStatus.copyWith(getItems: true),
          failure: null,
        ));
      },
    );
  }

  @override
  HomeState? fromJson(Map<String, dynamic> json) => null;

  @override
  Map<String, dynamic>? toJson(HomeState state) => null;
}

''';
  static const String _features_home_presentation_blocs_home_bloc_home_event_dart = r'''part of 'home_bloc.dart';

@freezed
class HomeEvent with _$HomeEvent {
  const factory HomeEvent.initialized() = _Initialized;
  const factory HomeEvent.resetSuccessAndErrorStatus({
    HomeSuccessStatus? successStatus,
    HomeErrorStatus? errorStatus,
  }) = _ResetSuccessAndErrorStatus;
}

''';
  static const String _features_home_presentation_pages_home_page_dart = r'''import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc/home_bloc.dart';
import '../../../../application/injector.dart';
import '../../../../application/generated/l10n.dart';
import '../../../../core/states/tstateless.dart';
import '../../domain/entities/home_entity.dart';

class HomePage extends TStateless<HomeBloc> {
  const HomePage({super.key});

  @override
  HomeBloc get bloc => Injector.get<HomeBloc>();

  @override
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  ) => Scaffold(
    appBar: AppBar(
      title: Text(translation.home),
      backgroundColor: theme.colorScheme.inversePrimary,
      actions: <Widget>[
        BlocBuilder<HomeBloc, HomeState>(
          bloc: bloc,
          builder: (BuildContext context, HomeState state) => IconButton(
            onPressed: state.status.isGetItems
                ? null
                : () => bloc.add(const HomeEvent.initialized()),
            icon: state.status.isGetItems
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
      ],
    ),
    body: BlocConsumer<HomeBloc, HomeState>(
      bloc: bloc,
      listener: (BuildContext ctx, HomeState state) => _handleStateChanges(ctx, state, translation),
      builder: (BuildContext context, HomeState state) => _buildBody(state, theme, translation),
    ),
  );

  void _handleStateChanges(BuildContext context, HomeState state, S translation) {
    if (state.errorStatus.getItems && state.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.failure!.message),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: translation.retry,
            textColor: Colors.white,
            onPressed: () => bloc.add(const HomeEvent.initialized()),
          ),
        ),
      );
      bloc.add(
        const HomeEvent.resetSuccessAndErrorStatus(
          errorStatus: HomeErrorStatus(getItems: false),
        ),
      );
    }
  }

  Widget _buildBody(HomeState state, ThemeData theme, S translation) {
    if (state.status.isGetItems && state.items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      );
    }

    if (state.items.isEmpty) {
      return _buildEmptyState(state, theme, translation);
    }

    return RefreshIndicator(
      onRefresh: () async => bloc.add(const HomeEvent.initialized()),
      child: ListView.builder(
        itemCount: state.items.length,
        itemBuilder: (BuildContext context, int index) {
          final HomeEntity item = state.items[index];
          return ListTile(
            title: Text(item.title, style: theme.textTheme.titleMedium),
            subtitle: Text(
              item.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(item.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(HomeState state, ThemeData theme, S translation) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.inbox_outlined,
          size: 64,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          translation.noItemsAvailable,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: state.status.isGetItems
              ? null
              : () => bloc.add(const HomeEvent.initialized()),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          icon: state.status.isGetItems
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.refresh),
          label: Text(translation.refresh),
        ),
      ],
    ),
  );
}
''';
  static const String _features_auth_data_datasources_local_auth_local_datasource_dart = r'''import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/database/app_database.dart';
import '../../models/user_model.dart';
import 'package:drift/drift.dart';

abstract interface class AuthLocalDataSource {
  Future<Either<Failure, UserModel?>> getUserByEmail(String email);
  Future<Either<Failure, List<UserModel>>> getAllUsers();
  Future<Either<Failure, void>> saveUser(UserModel user);
  Future<Either<Failure, void>> deleteUser(String userId);
  Future<Either<Failure, void>> clearUsers();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final AppDatabase _database;

  AuthLocalDataSourceImpl({
    required AppDatabase database,
  }) : _database = database;

  @override
  Future<Either<Failure, UserModel?>> getUserByEmail(String email) async {
    try {
      final User? user = await _database.getUserByEmail(email);
      if (user == null) {
        return const Right<Failure, UserModel?>(null);
      }
      final UserModel model = UserModel(
        id: user.id.toString(),
        email: user.email,
        name: user.name,
        token: user.token,
        createdAt: user.createdAt,
      );
      return Right<Failure, UserModel?>(model);
    } catch (e) {
      return Left<Failure, UserModel?>(CacheFailure(message: 'Failed to get user: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveUser(UserModel user) async {
    try {
      final User? existingUser = await _database.getUserByEmail(user.email);
      if (existingUser != null) {
        await _database.updateUser(
          User(
            id: existingUser.id,
            email: user.email,
            name: user.name,
            token: user.token,
            createdAt: existingUser.createdAt,
          ),
        );
      } else {
        await _database.insertUser(
          UsersCompanion(
            email: Value<String>(user.email),
            name: Value<String?>(user.name),
            token: Value<String?>(user.token),
          ),
        );
      }
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(CacheFailure(message: 'Failed to save user: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(String userId) async {
    try {
      await _database.deleteUser(int.parse(userId));
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(CacheFailure(message: 'Failed to delete user: $e'));
    }
  }

  @override
  Future<Either<Failure, List<UserModel>>> getAllUsers() async {
    try {
      final List<User> users = await _database.getAllUsers();
      final List<UserModel> models = users.map((User user) => UserModel(
        id: user.id.toString(),
        email: user.email,
        name: user.name,
        token: user.token,
        createdAt: user.createdAt,
      )).toList();
      return Right<Failure, List<UserModel>>(models);
    } catch (e) {
      return Left<Failure, List<UserModel>>(CacheFailure(message: 'Failed to get users: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearUsers() async {
    try {
      await _database.clearUsers();
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(CacheFailure(message: 'Failed to clear users: $e'));
    }
  }
}

''';
  static const String _features_auth_data_datasources_remote_auth_remote_datasource_dart = r'''import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<Either<Failure, UserModel>> login(String email, String password);
  Future<Either<Failure, UserModel>> register(String email, String password, String? name);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl();

  @override
  Future<Either<Failure, UserModel>> login(String email, String password) async {
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      
      final UserModel mockUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        name: email.split('@').first,
        token: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      
      return Right<Failure, UserModel>(mockUser);
    } catch (e) {
      return Left<Failure, UserModel>(
        ServerFailure(message: 'Login failed: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, UserModel>> register(String email, String password, String? name) async {
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      
      final UserModel mockUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        name: name ?? email.split('@').first,
        token: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      
      return Right<Failure, UserModel>(mockUser);
    } catch (e) {
      return Left<Failure, UserModel>(
        ServerFailure(message: 'Registration failed: $e'),
      );
    }
  }
}

''';
  static const String _features_auth_data_repositories_auth_repository_impl_dart = r'''import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../datasources/local/auth_local_datasource.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import '../../../../core/utils/secure_storage_utils.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.authRemoteDataSource,
    required this.authLocalDataSource,
    required this.secureStorageUtils,
  });

  final AuthRemoteDataSource authRemoteDataSource;
  final AuthLocalDataSource authLocalDataSource;
  final SecureStorageUtils secureStorageUtils;

  @override
  Future<Either<Failure, UserEntity>> login(String email, String password) async {
    final Either<Failure, UserModel> result = await authRemoteDataSource.login(email, password);
    return result.fold(
      (Failure failure) => Left<Failure, UserEntity>(failure),
      (UserModel model) async {
        await authLocalDataSource.saveUser(model);
        if (model.token != null) {
          await secureStorageUtils.write('token', model.token!);
        }
        return Right<Failure, UserEntity>(UserEntity.fromModel(model));
      },
    );
  }

  @override
  Future<Either<Failure, UserEntity>> register(String email, String password, String? name) async {
    final Either<Failure, UserModel> result = await authRemoteDataSource.register(email, password, name);
    return result.fold(
      (Failure failure) => Left<Failure, UserEntity>(failure),
      (UserModel model) async {
        await authLocalDataSource.saveUser(model);
        if (model.token != null) {
          await secureStorageUtils.write('token', model.token!);
        }
        return Right<Failure, UserEntity>(UserEntity.fromModel(model));
      },
    );
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final String? token = await secureStorageUtils.read('token');
      if (token != null) {
        await secureStorageUtils.delete('token');
      }
      await authLocalDataSource.clearUsers();
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(CacheFailure(message: 'Logout failed: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final String? token = await secureStorageUtils.read('token');
      if (token == null) {
        return const Right<Failure, UserEntity?>(null);
      }
      
      final Either<Failure, List<UserModel>> allUsers = await authLocalDataSource.getAllUsers();
      return allUsers.fold(
        (Failure failure) => Left<Failure, UserEntity?>(failure),
        (List<UserModel> users) {
          if (users.isEmpty) {
            return const Right<Failure, UserEntity?>(null);
          }
          try {
            final UserModel user = users.firstWhere(
              (UserModel u) => u.token == token,
            );
            return Right<Failure, UserEntity?>(UserEntity.fromModel(user));
          } catch (e) {
            return const Right<Failure, UserEntity?>(null);
          }
        },
      );
    } catch (e) {
      return Left<Failure, UserEntity?>(CacheFailure(message: 'Failed to get current user: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isAuthenticated() async {
    try {
      final String? token = await secureStorageUtils.read('token');
      return Right<Failure, bool>(token != null && token.isNotEmpty);
    } catch (e) {
      return Left<Failure, bool>(CacheFailure(message: 'Failed to check authentication: $e'));
    }
  }
}

''';
  static const String _features_auth_data_models_user_model_dart = r'''import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    String? name,
    String? token,
    DateTime? createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}

''';
  static const String _features_auth_domain_repositories_auth_repository_dart = r'''import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, UserEntity>> login(String email, String password);
  Future<Either<Failure, UserEntity>> register(String email, String password, String? name);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserEntity?>> getCurrentUser();
  Future<Either<Failure, bool>> isAuthenticated();
}

''';
  static const String _features_auth_domain_use_cases_auth_use_cases_dart = r'''import 'package:dartz/dartz.dart';
import '../repositories/auth_repository.dart';
import '../entities/user_entity.dart';
import '../../../../core/errors/failures.dart';

class AuthUseCases {
  const AuthUseCases({
    required AuthRepository repository,
  }) : _authRepository = repository;

  final AuthRepository _authRepository;

  Future<Either<Failure, UserEntity>> login(String email, String password) => _authRepository.login(email, password);

  Future<Either<Failure, UserEntity>> register(String email, String password, String? name) => _authRepository.register(email, password, name);

  Future<Either<Failure, void>> logout() => _authRepository.logout();

  Future<Either<Failure, UserEntity?>> getCurrentUser() => _authRepository.getCurrentUser();

  Future<Either<Failure, bool>> isAuthenticated() => _authRepository.isAuthenticated();
}

''';
  static const String _features_auth_domain_entities_user_entity_dart = r'''import 'package:freezed_annotation/freezed_annotation.dart';
import '../../data/models/user_model.dart';

part 'user_entity.freezed.dart';
part 'user_entity.g.dart';

@freezed
abstract class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String id,
    required String email,
    String? name,
    String? token,
    DateTime? createdAt,
  }) = _UserEntity;

  factory UserEntity.fromJson(Map<String, dynamic> json) => _$UserEntityFromJson(json);

  factory UserEntity.fromModel(UserModel model) => UserEntity(
    id: model.id,
    email: model.email,
    name: model.name,
    token: model.token,
    createdAt: model.createdAt,
  );
}

''';
  static const String _features_auth_presentation_blocs_auth_bloc_auth_event_dart = r'''part of 'auth_bloc.dart';

@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.login(String email, String password) = _Login;
  const factory AuthEvent.register(String email, String password, String? name) = _Register;
  const factory AuthEvent.logout() = _Logout;
  const factory AuthEvent.checkAuth() = _CheckAuth;
  const factory AuthEvent.resetSuccessAndErrorStatus({
    AuthSuccessStatus? successStatus,
    AuthErrorStatus? errorStatus,
  }) = _ResetSuccessAndErrorStatus;
}

''';
  static const String _features_auth_presentation_blocs_auth_bloc_auth_bloc_dart = r'''import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../domain/use_cases/auth_use_cases.dart';
import '../../../domain/entities/user_entity.dart';

part 'auth_bloc.freezed.dart';
part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends HydratedBloc<AuthEvent, AuthState> {
  final AuthUseCases _authUseCases;

  AuthBloc({
    required AuthUseCases authUseCases,
  }) : _authUseCases = authUseCases,
       super(const AuthState()) {
    on<_Login>(_onLogin);
    on<_Register>(_onRegister);
    on<_Logout>(_onLogout);
    on<_CheckAuth>(_onCheckAuth);
    on<_ResetSuccessAndErrorStatus>(_onResetSuccessAndErrorStatus);
  }

  void _onResetSuccessAndErrorStatus(
    _ResetSuccessAndErrorStatus event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(
      successStatus: event.successStatus ?? state.successStatus,
      errorStatus: event.errorStatus ?? state.errorStatus,
      failure: null,
    ));
  }

  Future<void> _onLogin(_Login event, Emitter<AuthState> emit) async {
    emit(state.copyWith(
      status: state.status.copyWith(isLogin: true),
      successStatus: state.successStatus.copyWith(login: false),
      errorStatus: state.errorStatus.copyWith(login: false),
      failure: null,
    ));
    
    final Either<Failure, UserEntity> result = await _authUseCases.login(event.email, event.password);
    
    result.fold(
      (Failure failure) {
        emit(state.copyWith(
          status: state.status.copyWith(isLogin: false),
          errorStatus: state.errorStatus.copyWith(login: true),
          failure: failure,
          isAuthenticated: false,
        ));
      },
      (UserEntity user) {
        emit(state.copyWith(
          user: user,
          status: state.status.copyWith(isLogin: false),
          successStatus: state.successStatus.copyWith(login: true),
          failure: null,
          isAuthenticated: true,
        ));
      },
    );
  }

  Future<void> _onRegister(_Register event, Emitter<AuthState> emit) async {
    emit(state.copyWith(
      status: state.status.copyWith(isRegister: true),
      successStatus: state.successStatus.copyWith(register: false),
      errorStatus: state.errorStatus.copyWith(register: false),
      failure: null,
    ));
    
    final Either<Failure, UserEntity> result = await _authUseCases.register(event.email, event.password, event.name);
    
    result.fold(
      (Failure failure) {
        emit(state.copyWith(
          status: state.status.copyWith(isRegister: false),
          errorStatus: state.errorStatus.copyWith(register: true),
          failure: failure,
          isAuthenticated: false,
        ));
      },
      (UserEntity user) {
        emit(state.copyWith(
          user: user,
          status: state.status.copyWith(isRegister: false),
          successStatus: state.successStatus.copyWith(register: true),
          failure: null,
          isAuthenticated: true,
        ));
      },
    );
  }

  Future<void> _onLogout(_Logout event, Emitter<AuthState> emit) async {
    emit(state.copyWith(
      status: state.status.copyWith(isLogout: true),
      successStatus: state.successStatus.copyWith(logout: false),
      errorStatus: state.errorStatus.copyWith(logout: false),
      failure: null,
    ));
    
    final Either<Failure, void> result = await _authUseCases.logout();
    
    result.fold(
      (Failure failure) {
        emit(state.copyWith(
          status: state.status.copyWith(isLogout: false),
          errorStatus: state.errorStatus.copyWith(logout: true),
          failure: failure,
        ));
      },
      (void _) {
        emit(state.copyWith(
          user: null,
          status: state.status.copyWith(isLogout: false),
          successStatus: state.successStatus.copyWith(logout: true),
          failure: null,
          isAuthenticated: false,
        ));
      },
    );
  }

  Future<void> _onCheckAuth(_CheckAuth event, Emitter<AuthState> emit) async {
    emit(state.copyWith(
      status: state.status.copyWith(isCheckAuth: true),
      successStatus: state.successStatus.copyWith(checkAuth: false),
      errorStatus: state.errorStatus.copyWith(checkAuth: false),
      failure: null,
    ));
    
    final Either<Failure, bool> result = await _authUseCases.isAuthenticated();
    
    if (result.isLeft()) {
      final Failure failure = result.fold((Failure l) => l, (bool r) => throw Exception());
      emit(state.copyWith(
        status: state.status.copyWith(isCheckAuth: false),
        errorStatus: state.errorStatus.copyWith(checkAuth: true),
        failure: failure,
        isAuthenticated: false,
      ));
      return;
    }
    
    final bool isAuth = result.fold((Failure l) => throw Exception(), (bool r) => r);
    
    if (!isAuth) {
      emit(state.copyWith(
        status: state.status.copyWith(isCheckAuth: false),
        failure: null,
        isAuthenticated: false,
      ));
      return;
    }
    
    final Either<Failure, UserEntity?> userResult = await _authUseCases.getCurrentUser();
    
    userResult.fold(
      (Failure failure) {
        emit(state.copyWith(
          status: state.status.copyWith(isCheckAuth: false),
          errorStatus: state.errorStatus.copyWith(checkAuth: true),
          failure: failure,
          isAuthenticated: false,
        ));
      },
      (UserEntity? user) {
        emit(state.copyWith(
          user: user,
          status: state.status.copyWith(isCheckAuth: false),
          successStatus: state.successStatus.copyWith(checkAuth: true),
          failure: null,
          isAuthenticated: user != null,
        ));
      },
    );
  }

  @override
  AuthState? fromJson(Map<String, dynamic> json) => null;

  @override
  Map<String, dynamic>? toJson(AuthState state) => null;
}

''';
  static const String _features_auth_presentation_blocs_auth_bloc_auth_state_dart = r'''part of 'auth_bloc.dart';

@freezed
abstract class AuthStatus with _$AuthStatus {
  const factory AuthStatus({
    @Default(false) bool isLogin,
    @Default(false) bool isRegister,
    @Default(false) bool isLogout,
    @Default(false) bool isCheckAuth,
  }) = _AuthStatus;
}

@freezed
abstract class AuthSuccessStatus with _$AuthSuccessStatus {
  const factory AuthSuccessStatus({
    @Default(false) bool login,
    @Default(false) bool register,
    @Default(false) bool logout,
    @Default(false) bool checkAuth,
  }) = _AuthSuccessStatus;
}

@freezed
abstract class AuthErrorStatus with _$AuthErrorStatus {
  const factory AuthErrorStatus({
    @Default(false) bool login,
    @Default(false) bool register,
    @Default(false) bool logout,
    @Default(false) bool checkAuth,
  }) = _AuthErrorStatus;
}

@freezed
abstract class AuthState with _$AuthState {
  const factory AuthState({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(AuthStatus()) AuthStatus status,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(AuthSuccessStatus()) AuthSuccessStatus successStatus,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(AuthErrorStatus()) AuthErrorStatus errorStatus,
    @JsonKey(includeFromJson: false, includeToJson: false)
    Failure? failure,
    @Default(false) bool isAuthenticated,
    UserEntity? user,
  }) = _AuthState;
}

''';
  static const String _features_auth_presentation_pages_login_page_dart = r'''import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth_bloc/auth_bloc.dart';
import '../../../../application/injector.dart';
import '../../../../application/routes/routes.dart';
import '../../../../application/generated/l10n.dart';
import '../../../../core/states/tstateless.dart';

class LoginPage extends TStateless<AuthBloc> {
  const LoginPage({super.key});

  @override
  AuthBloc get bloc => Injector.get<AuthBloc>();

  final GlobalKey<FormBuilderState> formKey = GlobalKey<FormBuilderState>();

  @override
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  ) => Scaffold(
      appBar: AppBar(
        title: Text(translation.login),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        bloc: bloc,
        listener: (BuildContext ctx, AuthState state) => _handleStateChanges(ctx, state),
        builder: (BuildContext context, AuthState state) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: FormBuilder(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 32),
                Text(
                  translation.welcomeBack,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  translation.pleaseSignInToContinue,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                FormBuilderTextField(
                  name: 'email',
                  decoration: InputDecoration(
                    labelText: translation.email,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: FormBuilderValidators.compose(<String? Function(String?)>[
                    FormBuilderValidators.required(),
                    FormBuilderValidators.email(),
                  ]),
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'password',
                  decoration: InputDecoration(
                    labelText: translation.password,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: FormBuilderValidators.compose(<String? Function(String?)>[
                    FormBuilderValidators.required(),
                    FormBuilderValidators.minLength(6),
                  ]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: state.status.isLogin
                        ? null
                        : () {
                            if (formKey.currentState?.saveAndValidate() ?? false) {
                              final String email = formKey.currentState?.value['email'] as String;
                              final String password = formKey.currentState?.value['password'] as String;
                              bloc.add(AuthEvent.login(email, password));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.6),
                    ),
                    child: state.status.isLogin
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : Text(translation.login),
                  ),
                );
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Navigate to register page if needed
                  },
                  child: Text(translation.dontHaveAccount),
                ),
              ],
            ),
          ),
        ),
    ),
  );

  void _handleStateChanges(BuildContext context, AuthState state) {
    if (state.isAuthenticated && state.user != null) {
      context.go(Routes.home);
    }
    if (state.errorStatus.login && state.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.failure!.message),
          backgroundColor: Colors.red,
        ),
      );
      bloc.add(
        const AuthEvent.resetSuccessAndErrorStatus(
          errorStatus: AuthErrorStatus(login: false),
        ),
      );
    }
    if (state.successStatus.login) {
      bloc.add(
        const AuthEvent.resetSuccessAndErrorStatus(
          successStatus: AuthSuccessStatus(login: false),
        ),
      );
    }
  }

}
''';
  static const String _shared_shared_dart = r'''export 'widgets/widgets.dart';

''';
  static const String _shared_widgets_widgets_dart = r'''export 'app_header.dart';

''';
  static const String _shared_widgets_app_header_dart = r'''import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  const AppHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) => AppBar(
      title: Text(title),
    );
}

''';
  static const String _main_dart = r'''import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:nested/nested.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'application/application.dart';
import 'features/home/presentation/blocs/home_bloc/home_bloc.dart';
import 'features/auth/presentation/blocs/auth_bloc/auth_bloc.dart';
import 'core/services/talker_service.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (kReleaseMode) {
      debugPrintRebuildDirtyWidgets = false;
      debugPrint = (String? message, {int? wrapWidth}) {};
    }
  } finally {
    await runMainApp();
  }
}

Future<void> runMainApp() async {
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: !kIsWeb
        ? HydratedStorageDirectory((await getTemporaryDirectory()).path)
        : HydratedStorageDirectory.web,
  );

  TalkerService.init();

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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: AppRoutes.router,
    locale: AppLocalizationsSetup.supportedLocales.last,
    localizationsDelegates: AppLocalizationsSetup.localizationsDelegates,
    supportedLocales: AppLocalizationsSetup.supportedLocales,
    debugShowCheckedModeBanner: kDebugMode,
  );
} ''';
  static const String _application_application_dart = r'''export 'injector.dart';
export 'routes/routes.dart';
export 'theme/theme.dart';
export 'theme/app_colors.dart';
export 'l10n/app_localization_setup.dart';
export 'constants/assets.dart';

''';
  static const String _application_l10n_intl_es_arb = r'''{
  "@@locale": "es",
  "appTitle": "{{project_name}}",
  "@appTitle": {
    "description": "El título de la aplicación"
  },
  "login": "Iniciar Sesión",
  "@login": {
    "description": "Botón y título de inicio de sesión"
  },
  "welcomeBack": "Bienvenido de nuevo",
  "@welcomeBack": {
    "description": "Mensaje de bienvenida en la página de inicio de sesión"
  },
  "pleaseSignInToContinue": "Por favor inicia sesión para continuar",
  "@pleaseSignInToContinue": {
    "description": "Subtítulo en la página de inicio de sesión"
  },
  "email": "Correo electrónico",
  "@email": {
    "description": "Etiqueta del campo de correo"
  },
  "password": "Contraseña",
  "@password": {
    "description": "Etiqueta del campo de contraseña"
  },
  "dontHaveAccount": "¿No tienes cuenta? Regístrate",
  "@dontHaveAccount": {
    "description": "Texto del enlace de registro"
  },
  "home": "Inicio",
  "@home": {
    "description": "Título de la página de inicio"
  },
  "noItemsAvailable": "No hay elementos disponibles",
  "@noItemsAvailable": {
    "description": "Mensaje de estado vacío"
  },
  "refresh": "Actualizar",
  "@refresh": {
    "description": "Texto del botón actualizar"
  },
  "retry": "Reintentar",
  "@retry": {
    "description": "Texto del botón reintentar"
  },
  "logout": "Cerrar sesión",
  "@logout": {
    "description": "Texto del botón cerrar sesión"
  },
  "register": "Registrarse",
  "@register": {
    "description": "Texto del botón registrarse"
  },
  "loading": "Cargando...",
  "@loading": {
    "description": "Texto del indicador de carga"
  },
  "error": "Error",
  "@error": {
    "description": "Título de error"
  },
  "success": "Éxito",
  "@success": {
    "description": "Título de éxito"
  }
}

''';
  static const String _application_l10n_app_localization_setup_dart = r'''import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../generated/l10n.dart';

class AppLocalizationsSetup {
  static final List<Locale> supportedLocales = S.delegate.supportedLocales;

  static final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    S.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}

''';
  static const String _application_l10n_intl_en_arb = r'''{
  "@@locale": "en",
  "appTitle": "{{project_name}}",
  "@appTitle": {
    "description": "The application title"
  },
  "login": "Login",
  "@login": {
    "description": "Login button and page title"
  },
  "welcomeBack": "Welcome Back",
  "@welcomeBack": {
    "description": "Welcome message on login page"
  },
  "pleaseSignInToContinue": "Please sign in to continue",
  "@pleaseSignInToContinue": {
    "description": "Subtitle on login page"
  },
  "email": "Email",
  "@email": {
    "description": "Email field label"
  },
  "password": "Password",
  "@password": {
    "description": "Password field label"
  },
  "dontHaveAccount": "Don't have an account? Register",
  "@dontHaveAccount": {
    "description": "Register link text"
  },
  "home": "Home",
  "@home": {
    "description": "Home page title"
  },
  "noItemsAvailable": "No items available",
  "@noItemsAvailable": {
    "description": "Empty state message"
  },
  "refresh": "Refresh",
  "@refresh": {
    "description": "Refresh button text"
  },
  "retry": "Retry",
  "@retry": {
    "description": "Retry button text"
  },
  "logout": "Logout",
  "@logout": {
    "description": "Logout button text"
  },
  "register": "Register",
  "@register": {
    "description": "Register button text"
  },
  "loading": "Loading...",
  "@loading": {
    "description": "Loading indicator text"
  },
  "error": "Error",
  "@error": {
    "description": "Error title"
  },
  "success": "Success",
  "@success": {
    "description": "Success title"
  }
}

''';
  static const String _application_injector_dart = r'''import 'package:get_it/get_it.dart';
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
  }
}

''';
  static const String _application_constants_assets_dart = r'''class Assets {
  static const String imagesPath = 'assets/images/';
  static const String iconsPath = 'assets/icons/';
}

''';
  static const String _application_theme_app_colors_dart = r'''import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color blue = Color(0xFF4B60AA);
  static const Color lightBlue = Color(0xFF50A2FF);
  static const Color darkBlue = Color(0xFF4F3273);
}

''';
  static const String _application_theme_theme_dart = r'''import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  );
}

''';
  static const String _application_routes_routes_dart = r'''import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';

class Routes {
  const Routes._();
  static const String login = '/login';
  static const String home = '/home';
}

class AppRoutes {
  AppRoutes._();

  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get globalContext => _navigatorKey.currentContext;

  static final GoRouter router = GoRouter(
    errorBuilder: (BuildContext context, GoRouterState state) {
      debugPrint('Error en ruta: ${state.error}');
      return Scaffold(
        body: Center(
          child: Text('Error en la ruta: ${state.error}', style: const TextStyle(fontSize: 20)),
        ),
      );
    },
    navigatorKey: _navigatorKey,
    debugLogDiagnostics: true,
    initialLocation: Routes.login,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.login,
        builder: (BuildContext context, GoRouterState state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (BuildContext context, GoRouterState state) => const HomePage(),
      ),
    ],
  );
}

''';

  static Map<String, String> get templates => {
    'core/database/app_database.dart': _core_database_app_database_dart,
    'core/core.dart': _core_core_dart,
    'core/network/http_client.dart': _core_network_http_client_dart,
    'core/enums/server_status.dart': _core_enums_server_status_dart,
    'core/utils/secure_storage_utils.dart': _core_utils_secure_storage_utils_dart,
    'core/utils/toast_util.dart': _core_utils_toast_util_dart,
    'core/utils/helpers/number_helper.dart': _core_utils_helpers_number_helper_dart,
    'core/states/tstateless.dart': _core_states_tstateless_dart,
    'core/states/tstatefull.dart': _core_states_tstatefull_dart,
    'core/errors/failures.dart': _core_errors_failures_dart,
    'core/services/talker_service.dart': _core_services_talker_service_dart,
    'features/home/data/datasources/remote/home_remote_datasource.dart': _features_home_data_datasources_remote_home_remote_datasource_dart,
    'features/home/data/repositories/home_repository_impl.dart': _features_home_data_repositories_home_repository_impl_dart,
    'features/home/data/models/home_model.dart': _features_home_data_models_home_model_dart,
    'features/home/domain/repositories/home_repository.dart': _features_home_domain_repositories_home_repository_dart,
    'features/home/domain/use_cases/home_use_cases.dart': _features_home_domain_use_cases_home_use_cases_dart,
    'features/home/domain/entities/home_entity.dart': _features_home_domain_entities_home_entity_dart,
    'features/home/presentation/blocs/home_bloc/home_state.dart': _features_home_presentation_blocs_home_bloc_home_state_dart,
    'features/home/presentation/blocs/home_bloc/home_bloc.dart': _features_home_presentation_blocs_home_bloc_home_bloc_dart,
    'features/home/presentation/blocs/home_bloc/home_event.dart': _features_home_presentation_blocs_home_bloc_home_event_dart,
    'features/home/presentation/pages/home_page.dart': _features_home_presentation_pages_home_page_dart,
    'features/auth/data/datasources/local/auth_local_datasource.dart': _features_auth_data_datasources_local_auth_local_datasource_dart,
    'features/auth/data/datasources/remote/auth_remote_datasource.dart': _features_auth_data_datasources_remote_auth_remote_datasource_dart,
    'features/auth/data/repositories/auth_repository_impl.dart': _features_auth_data_repositories_auth_repository_impl_dart,
    'features/auth/data/models/user_model.dart': _features_auth_data_models_user_model_dart,
    'features/auth/domain/repositories/auth_repository.dart': _features_auth_domain_repositories_auth_repository_dart,
    'features/auth/domain/use_cases/auth_use_cases.dart': _features_auth_domain_use_cases_auth_use_cases_dart,
    'features/auth/domain/entities/user_entity.dart': _features_auth_domain_entities_user_entity_dart,
    'features/auth/presentation/blocs/auth_bloc/auth_event.dart': _features_auth_presentation_blocs_auth_bloc_auth_event_dart,
    'features/auth/presentation/blocs/auth_bloc/auth_bloc.dart': _features_auth_presentation_blocs_auth_bloc_auth_bloc_dart,
    'features/auth/presentation/blocs/auth_bloc/auth_state.dart': _features_auth_presentation_blocs_auth_bloc_auth_state_dart,
    'features/auth/presentation/pages/login_page.dart': _features_auth_presentation_pages_login_page_dart,
    'shared/shared.dart': _shared_shared_dart,
    'shared/widgets/widgets.dart': _shared_widgets_widgets_dart,
    'shared/widgets/app_header.dart': _shared_widgets_app_header_dart,
    'main.dart': _main_dart,
    'application/application.dart': _application_application_dart,
    'application/l10n/intl_es.arb': _application_l10n_intl_es_arb,
    'application/l10n/app_localization_setup.dart': _application_l10n_app_localization_setup_dart,
    'application/l10n/intl_en.arb': _application_l10n_intl_en_arb,
    'application/injector.dart': _application_injector_dart,
    'application/constants/assets.dart': _application_constants_assets_dart,
    'application/theme/app_colors.dart': _application_theme_app_colors_dart,
    'application/theme/theme.dart': _application_theme_theme_dart,
    'application/routes/routes.dart': _application_routes_routes_dart,
  };

  static String _processTemplate(String content, String projectName) {
    return content
        .replaceAll('{{project_name}}', projectName)
        .replaceAll('template_project', projectName);
  }

  static Map<String, String> getProcessedTemplates(String projectName) {
    return templates.map((key, value) => MapEntry(key, _processTemplate(value, projectName)));
  }
}
