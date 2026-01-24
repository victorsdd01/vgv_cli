import 'package:flutter/material.dart';
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
