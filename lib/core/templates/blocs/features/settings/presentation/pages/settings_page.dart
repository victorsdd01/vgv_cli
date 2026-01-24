import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../application/generated/l10n.dart';
import '../../../../application/injector.dart';
import '../../../../application/routes/routes.dart';
import '../../../../core/states/tstateless.dart';
import '../../../../shared/widgets/dialogs/app_dialogs.dart';
import '../../../auth/presentation/blocs/auth_bloc/auth_bloc.dart';
import '../blocs/settings_bloc/settings_bloc.dart';

class SettingsPage extends TStateless<SettingsBloc> {
  const SettingsPage({super.key});

  @override
  SettingsBloc get bloc => Injector.get<SettingsBloc>();

  @override
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  ) => Scaffold(
    appBar: AppBar(
      title: Text(translation.settings),
      backgroundColor: theme.colorScheme.inversePrimary,
    ),
    body: BlocBuilder<SettingsBloc, SettingsState>(
      bloc: bloc,
      builder: (BuildContext context, SettingsState state) => ListView(
        children: <Widget>[
          _SectionHeader(title: translation.appearance),
          _ThemeTile(
            themeMode: state.themeMode,
            onThemeSelected: (ThemeMode mode) {
              bloc.add(SettingsEvent.updateTheme(mode));
            },
          ),
          _LanguageTile(
            languageCode: state.languageCode,
            onLanguageSelected: (String code) {
              bloc.add(SettingsEvent.updateLanguage(code));
            },
          ),
          const Divider(),
          _SectionHeader(title: translation.account),
          const _AccountTile(),
          _LogoutTile(onLogout: () => _handleLogout(context)),
          const Divider(),
          _SectionHeader(title: translation.about),
          const _AppInfoTile(),
          _LicensesTile(appName: translation.appTitle),
        ],
      ),
    ),
  );

  Future<void> _handleLogout(BuildContext context) async {
    final bool confirmed = await AppDialogs.showLogoutConfirmation(context: context);
    if (confirmed && context.mounted) {
      Injector.get<AuthBloc>().add(const AuthEvent.logout());
      context.go(Routes.login);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeSelected;

  const _ThemeTile({
    required this.themeMode,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final S translation = S.of(context);

    return ListTile(
      leading: Icon(
        _getIcon(themeMode),
        color: theme.colorScheme.primary,
      ),
      title: Text(translation.theme),
      subtitle: Text(_getThemeModeName(translation, themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeSelector(context, translation),
    );
  }

  IconData _getIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getThemeModeName(S translation, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return translation.darkMode;
      case ThemeMode.light:
        return translation.lightMode;
      case ThemeMode.system:
        return translation.systemDefault;
    }
  }

  Future<void> _showThemeSelector(BuildContext context, S translation) async {
    final ThemeMode? selected = await AppDialogs.showOptionsBottomSheet<ThemeMode>(
      context: context,
      title: translation.selectTheme,
      options: <OptionItem<ThemeMode>>[
        OptionItem<ThemeMode>(
          value: ThemeMode.light,
          title: translation.lightMode,
          icon: Icons.light_mode,
        ),
        OptionItem<ThemeMode>(
          value: ThemeMode.dark,
          title: translation.darkMode,
          icon: Icons.dark_mode,
        ),
        OptionItem<ThemeMode>(
          value: ThemeMode.system,
          title: translation.systemDefault,
          icon: Icons.brightness_auto,
        ),
      ],
    );

    if (selected != null) {
      onThemeSelected(selected);
    }
  }
}

class _LanguageTile extends StatelessWidget {
  final String languageCode;
  final ValueChanged<String> onLanguageSelected;

  const _LanguageTile({
    required this.languageCode,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final S translation = S.of(context);

    return ListTile(
      leading: Icon(Icons.language, color: theme.colorScheme.primary),
      title: Text(translation.language),
      subtitle: Text(_getLanguageName(translation, languageCode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageSelector(context, translation),
    );
  }

  String _getLanguageName(S translation, String code) {
    switch (code) {
      case 'es':
        return translation.spanish;
      case 'en':
      default:
        return translation.english;
    }
  }

  Future<void> _showLanguageSelector(BuildContext context, S translation) async {
    final String? selected = await AppDialogs.showOptionsBottomSheet<String>(
      context: context,
      title: translation.selectLanguage,
      options: <OptionItem<String>>[
        OptionItem<String>(
          value: 'en',
          title: translation.english,
          icon: Icons.language,
        ),
        OptionItem<String>(
          value: 'es',
          title: translation.spanish,
          icon: Icons.language,
        ),
      ],
    );

    if (selected != null) {
      onLanguageSelected(selected);
    }
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final S translation = S.of(context);

    return BlocBuilder<AuthBloc, AuthState>(
      bloc: Injector.get<AuthBloc>(),
      builder: (BuildContext context, AuthState state) => ListTile(
        leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
        title: Text(state.user?.name ?? translation.guest),
        subtitle: Text(state.user?.email ?? ''),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onLogout;

  const _LogoutTile({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final S translation = S.of(context);

    return ListTile(
      leading: Icon(Icons.logout, color: theme.colorScheme.error),
      title: Text(
        translation.logout,
        style: TextStyle(color: theme.colorScheme.error),
      ),
      onTap: onLogout,
    );
  }
}

class _AppInfoTile extends StatelessWidget {
  const _AppInfoTile();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final S translation = S.of(context);

    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        final PackageInfo? info = snapshot.data;
        return ListTile(
          leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
          title: Text(translation.appInfo),
          subtitle: info != null
              ? Text('${translation.version}: ${info.version} (${info.buildNumber})')
              : null,
          onTap: () => _showAppInfo(context, translation, info),
        );
      },
    );
  }

  Future<void> _showAppInfo(
    BuildContext context,
    S translation,
    PackageInfo? info,
  ) async {
    if (info == null) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(translation.appInfo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _InfoRow(label: translation.appName, value: info.appName),
            _InfoRow(label: translation.version, value: info.version),
            _InfoRow(label: translation.buildNumber, value: info.buildNumber),
            _InfoRow(label: translation.packageName, value: info.packageName),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(translation.accept),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _LicensesTile extends StatelessWidget {
  final String appName;

  const _LicensesTile({required this.appName});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final S translation = S.of(context);

    return ListTile(
      leading: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
      title: Text(translation.licenses),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLicensePage(
        context: context,
        applicationName: appName,
      ),
    );
  }
}
