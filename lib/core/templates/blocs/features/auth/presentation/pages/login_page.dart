import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth_bloc/auth_bloc.dart';
import '../../../../application/injector.dart';
import '../../../../application/routes/routes.dart';
import '../../../../application/generated/l10n.dart';
import '../../../../core/states/tstatefull.dart';

/// Login page container - provides BlocProvider
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<AuthBloc>(
    create: (BuildContext context) => Injector.get<AuthBloc>()..add(const AuthEvent.checkAuth()),
    child: const _LoginView(),
  );
}

/// Login view - StatefulWidget for form state management
class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends TStateful<_LoginView, AuthBloc> {
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

  @override
  AuthBloc get bloc => Injector.get<AuthBloc>();

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
      listener: _handleStateChanges,
      builder: (BuildContext context, AuthState state) => SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: FormBuilder(
          key: _formKey,
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
              _buildLoginButton(state, theme, translation),
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
      Injector.get<AuthBloc>().add(
        const AuthEvent.resetSuccessAndErrorStatus(
          errorStatus: AuthErrorStatus(login: false),
        ),
      );
    }
    if (state.successStatus.login) {
      Injector.get<AuthBloc>().add(
        const AuthEvent.resetSuccessAndErrorStatus(
          successStatus: AuthSuccessStatus(login: false),
        ),
      );
    }
  }

  Widget _buildLoginButton(AuthState state, ThemeData theme, S translation) => SizedBox(
    height: 50,
    child: ElevatedButton(
      onPressed: state.status.isLogin ? null : _onLoginPressed,
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

  void _onLoginPressed() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final String email = _formKey.currentState?.value['email'] as String;
      final String password = _formKey.currentState?.value['password'] as String;
      bloc.add(AuthEvent.login(email, password));
    }
  }
}

