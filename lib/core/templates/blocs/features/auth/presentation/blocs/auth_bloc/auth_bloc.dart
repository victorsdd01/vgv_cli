import 'package:hydrated_bloc/hydrated_bloc.dart';
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

