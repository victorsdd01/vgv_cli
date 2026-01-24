import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc/home_bloc.dart';
import '../../../../application/injector.dart';
import '../../../../application/generated/l10n.dart';
import '../../../../core/states/tstateless.dart';
import '../../domain/entities/home_entity.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<HomeBloc>(
    create: (BuildContext context) => Injector.get<HomeBloc>()..add(const HomeEvent.initialized()),
    child: const _HomeView(),
  );
}

class _HomeView extends TStateless<HomeBloc> {
  const _HomeView();

  @override
  HomeBloc get bloc => Injector.get<HomeBloc>();

  @override
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  ) => Scaffold(
    appBar: AppBar(
      title: Text(translation.home),
      backgroundColor: theme.colorScheme.inversePrimary,
      actions: <Widget>[
        BlocBuilder<HomeBloc, HomeState>(
          builder: (BuildContext context, HomeState state) => IconButton(
            onPressed: state.status.isGetItems
                ? null
                : () => bloc.add(const HomeEvent.initialized()),
            icon: state.status.isGetItems
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
      ],
    ),
    body: BlocConsumer<HomeBloc, HomeState>(
      listener: (BuildContext ctx, HomeState state) => _handleStateChanges(ctx, state, translation),
      builder: (BuildContext context, HomeState state) => _buildBody(state, theme, translation),
    ),
  );

  void _handleStateChanges(BuildContext context, HomeState state, S translation) {
    if (state.errorStatus.getItems && state.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.failure!.message),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: translation.retry,
            textColor: Colors.white,
            onPressed: () => bloc.add(const HomeEvent.initialized()),
          ),
        ),
      );
      bloc.add(
        const HomeEvent.resetSuccessAndErrorStatus(
          errorStatus: HomeErrorStatus(getItems: false),
        ),
      );
    }
  }

  Widget _buildBody(HomeState state, ThemeData theme, S translation) {
    if (state.status.isGetItems && state.items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      );
    }

    if (state.items.isEmpty) {
      return _buildEmptyState(state, theme, translation);
    }

    return RefreshIndicator(
      onRefresh: () async => bloc.add(const HomeEvent.initialized()),
      child: ListView.builder(
        itemCount: state.items.length,
        itemBuilder: (BuildContext context, int index) {
          final HomeEntity item = state.items[index];
          return ListTile(
            title: Text(item.title, style: theme.textTheme.titleMedium),
            subtitle: Text(
              item.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(item.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(HomeState state, ThemeData theme, S translation) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.inbox_outlined,
          size: 64,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          translation.noItemsAvailable,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: state.status.isGetItems
              ? null
              : () => bloc.add(const HomeEvent.initialized()),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          icon: state.status.isGetItems
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.refresh),
          label: Text(translation.refresh),
        ),
      ],
    ),
  );
}

