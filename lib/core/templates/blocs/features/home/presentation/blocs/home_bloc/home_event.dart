part of 'home_bloc.dart';

@freezed
class HomeEvent with _$HomeEvent {
  const factory HomeEvent.initialized() = _Initialized;
  const factory HomeEvent.resetSuccessAndErrorStatus({
    HomeSuccessStatus? successStatus,
    HomeErrorStatus? errorStatus,
  }) = _ResetSuccessAndErrorStatus;
}

