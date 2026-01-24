part of 'auth_bloc.dart';

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

