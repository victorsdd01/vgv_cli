import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import '../../application/generated/l10n.dart';

abstract class TStateless<Bloc extends BlocBase<dynamic>?>
    extends StatelessWidget {
  const TStateless({super.key});

  Bloc get bloc;

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
