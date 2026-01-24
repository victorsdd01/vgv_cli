import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import '../../application/generated/l10n.dart';

abstract class TStateful<
  T extends StatefulWidget,
  Bloc extends BlocBase<dynamic>?
> extends State<T> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => false;

  Bloc get bloc;

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
