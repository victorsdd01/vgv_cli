part of 'auth_bloc.dart';

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
