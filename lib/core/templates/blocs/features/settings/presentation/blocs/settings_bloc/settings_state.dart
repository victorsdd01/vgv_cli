part of 'settings_bloc.dart';

@freezed
abstract class SettingsStatus with _$SettingsStatus {
  const factory SettingsStatus({
    @Default(false) bool isUpdateTheme,
    @Default(false) bool isUpdateLanguage,
  }) = _SettingsStatus;
}

@freezed
abstract class SettingsSuccessStatus with _$SettingsSuccessStatus {
  const factory SettingsSuccessStatus({
    @Default(false) bool updateTheme,
    @Default(false) bool updateLanguage,
  }) = _SettingsSuccessStatus;
}

@freezed
abstract class SettingsErrorStatus with _$SettingsErrorStatus {
  const factory SettingsErrorStatus({
    @Default(false) bool updateTheme,
    @Default(false) bool updateLanguage,
  }) = _SettingsErrorStatus;
}

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(SettingsStatus()) SettingsStatus status,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(SettingsSuccessStatus()) SettingsSuccessStatus successStatus,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(SettingsErrorStatus()) SettingsErrorStatus errorStatus,
    @JsonKey(includeFromJson: false, includeToJson: false)
    Failure? failure,
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default('en') String languageCode,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, dynamic> json) => _$SettingsStateFromJson(json);
}
