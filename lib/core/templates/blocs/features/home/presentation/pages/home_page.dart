import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../application/injector.dart';
import '../../../../application/generated/l10n.dart';
import '../../../../application/routes/routes.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/states/tstateless.dart';
import '../../../../shared/widgets/dialogs/app_dialogs.dart';
import '../../../auth/presentation/blocs/auth_bloc/auth_bloc.dart';

class HomePage extends TStateless<AuthBloc> {
  const HomePage({super.key});

  @override
  AuthBloc get bloc => Injector.get<AuthBloc>();

  @override
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  ) => BlocConsumer<AuthBloc, AuthState>(
    bloc: bloc,
    listener: (BuildContext ctx, AuthState state) {
      if (state.successStatus.logout && !state.isAuthenticated) {
        context.go(Routes.login);
      }
    },
    builder: (BuildContext context, AuthState state) {
      final String userEmail = state.user?.email ?? '';
      final String userName = state.user?.name ?? userEmail;
      final String initials = userEmail.initials;

      return Scaffold(
        appBar: AppBar(
          title: Text(translation.home),
          backgroundColor: theme.colorScheme.inversePrimary,
          actions: <Widget>[
            PopupMenuButton<String>(
              offset: const Offset(0, 50),
              onSelected: (String value) {
                switch (value) {
                  case 'settings':
                    context.push(Routes.settings);
                  case 'logout':
                    _showLogoutConfirmation(context);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        userName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        userEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.settings,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(translation.settings),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.logout,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        translation.logout,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  radius: 18,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                radius: 50,
                child: Text(
                  initials,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                userName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                userEmail,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                '${translation.welcomeBack}!',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final bool confirmed = await AppDialogs.showLogoutConfirmation(context: context);
    if (confirmed) {
      bloc.add(const AuthEvent.logout());
    }
  }
}
