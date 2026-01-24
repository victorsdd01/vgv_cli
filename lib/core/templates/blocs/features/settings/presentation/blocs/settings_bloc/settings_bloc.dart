import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../../core/errors/failures.dart';

part 'settings_event.dart';
part 'settings_state.dart';
part 'settings_bloc.freezed.dart';
part 'settings_bloc.g.dart';

class SettingsBloc extends HydratedBloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(const SettingsState()) {
    on<_UpdateTheme>(_onUpdateTheme);
    on<_UpdateLanguage>(_onUpdateLanguage);
    on<_ResetSuccessAndErrorStatus>(_onResetSuccessAndErrorStatus);
  }

  void _onResetSuccessAndErrorStatus(
    _ResetSuccessAndErrorStatus event,
    Emitter<SettingsState> emit,
  ) {
    emit(state.copyWith(
      successStatus: event.successStatus ?? state.successStatus,
      errorStatus: event.errorStatus ?? state.errorStatus,
      failure: null,
    ));
  }

  void _onUpdateTheme(_UpdateTheme event, Emitter<SettingsState> emit) {
    emit(state.copyWith(
      status: state.status.copyWith(isUpdateTheme: true),
      successStatus: state.successStatus.copyWith(updateTheme: false),
      errorStatus: state.errorStatus.copyWith(updateTheme: false),
    ));

    emit(state.copyWith(
      themeMode: event.themeMode,
      status: state.status.copyWith(isUpdateTheme: false),
      successStatus: state.successStatus.copyWith(updateTheme: true),
    ));
  }

  void _onUpdateLanguage(_UpdateLanguage event, Emitter<SettingsState> emit) {
    emit(state.copyWith(
      status: state.status.copyWith(isUpdateLanguage: true),
      successStatus: state.successStatus.copyWith(updateLanguage: false),
      errorStatus: state.errorStatus.copyWith(updateLanguage: false),
    ));

    emit(state.copyWith(
      languageCode: event.languageCode,
      status: state.status.copyWith(isUpdateLanguage: false),
      successStatus: state.successStatus.copyWith(updateLanguage: true),
    ));
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) => SettingsState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(SettingsState state) => state.toJson();
}
