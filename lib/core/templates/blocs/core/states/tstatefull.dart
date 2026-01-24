import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import '../../application/generated/l10n.dart';

/// Base class for stateful widgets with common utilities
/// 
/// Usage:
/// ```dart
/// class MyPage extends StatefulWidget {
///   const MyPage({super.key});
///   
///   @override
///   State<MyPage> createState() => _MyPageState();
/// }
/// 
/// class _MyPageState extends TStateful<MyPage, MyBloc> {
///   @override
///   MyBloc? get bloc => context.read<MyBloc>();
///   
///   @override
///   Widget bodyWidget(BuildContext context, ThemeData theme, S translation) {
///     return Scaffold(
///       body: Text(translation.hello),
///     );
///   }
/// }
/// ```
abstract class TStateful<
  T extends StatefulWidget,
  Bloc extends BlocBase<dynamic>?
> extends State<T> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => false;

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
  Widget build(BuildContext context) {
    super.build(context);
    return bodyWidget(
      context,
      Theme.of(context),
      S.of(context),
    );
  }
}

