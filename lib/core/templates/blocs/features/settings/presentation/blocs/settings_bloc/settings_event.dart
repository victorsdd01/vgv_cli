part of 'settings_bloc.dart';

@freezed
class SettingsEvent with _$SettingsEvent {
  const factory SettingsEvent.updateTheme(ThemeMode themeMode) = _UpdateTheme;
  const factory SettingsEvent.updateLanguage(String languageCode) = _UpdateLanguage;
  const factory SettingsEvent.resetSuccessAndErrorStatus({
    SettingsSuccessStatus? successStatus,
    SettingsErrorStatus? errorStatus,
  }) = _ResetSuccessAndErrorStatus;
}
