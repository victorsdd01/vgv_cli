import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import '../../application/generated/l10n.dart';

/// Base class for stateless widgets with common utilities
/// 
/// Usage:
/// ```dart
/// class MyPage extends TStateless<MyBloc> {
///   const MyPage({super.key});
///   
///   @override
///   MyBloc? get bloc => null; // or context.read<MyBloc>() if needed
///   
///   @override
///   Widget bodyWidget(BuildContext context, ThemeData theme, S translation) {
///     return Scaffold(
///       body: Text(translation.hello),
///     );
///   }
/// }
/// ```
abstract class TStateless<Bloc extends BlocBase<dynamic>?>
    extends StatelessWidget {
  const TStateless({super.key});

  /// Override to provide access to a BLoC instance
  Bloc get bloc;

  /// Build your widget here with access to common utilities
  /// 
  /// - [context] - BuildContext
  /// - [theme] - Current ThemeData
  /// - [translation] - Localization strings
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  );

  @override
  Widget build(BuildContext context) => bodyWidget(
    context,
    Theme.of(context),
    S.of(context),
  );
}

