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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends TStateful<RegisterPage, AuthBloc> {
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
      title: Text(translation.register),
      backgroundColor: theme.colorScheme.inversePrimary,
    ),
    body: BlocConsumer<AuthBloc, AuthState>(
      bloc: bloc,
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
                translation.createAccount,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                translation.fillInYourDetails,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FormBuilderTextField(
                name: 'name',
                decoration: InputDecoration(
                  labelText: translation.name,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: FormBuilderValidators.compose(<String? Function(String?)>[
                  FormBuilderValidators.required(),
                  FormBuilderValidators.minLength(2),
                ]),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              FormBuilderTextField(
                name: 'confirmPassword',
                decoration: InputDecoration(
                  labelText: translation.confirmPassword,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: FormBuilderValidators.compose(<String? Function(String?)>[
                  FormBuilderValidators.required(),
                  (String? value) {
                    if (value != _formKey.currentState?.fields['password']?.value) {
                      return translation.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: state.status.isRegister ? null : _onRegisterPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  child: state.status.isRegister
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
                      : Text(translation.register),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(translation.alreadyHaveAccount),
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
    if (state.errorStatus.register && state.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.failure!.message),
          backgroundColor: Colors.red,
        ),
      );
      bloc.add(
        const AuthEvent.resetSuccessAndErrorStatus(
          errorStatus: AuthErrorStatus(register: false),
        ),
      );
    }
    if (state.successStatus.register) {
      bloc.add(
        const AuthEvent.resetSuccessAndErrorStatus(
          successStatus: AuthSuccessStatus(register: false),
        ),
      );
    }
  }

  void _onRegisterPressed() {
    if (_formKey.currentState?.saveAndValidate() != false) {
      final String name = _formKey.currentState?.value['name'] as String;
      final String email = _formKey.currentState?.value['email'] as String;
      final String password = _formKey.currentState?.value['password'] as String;
      bloc.add(AuthEvent.register(email, password, name));
    }
  }
}
