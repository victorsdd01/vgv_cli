import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/feature_generator.dart';
import 'package:vgv_cli/core/utils/recase.dart';

void main() {
  final gen = FeatureGenerator();

  group('ReCase', () {
    test('handles snake, pascal and camel from any input', () {
      final r = ReCase('user_profile');
      expect(r.snakeCase, 'user_profile');
      expect(r.pascalCase, 'UserProfile');
      expect(r.camelCase, 'userProfile');

      final r2 = ReCase('UserProfilePage');
      expect(r2.snakeCase, 'user_profile_page');
      expect(r2.pascalCase, 'UserProfilePage');
    });
  });

  group('FeatureGenerator full feature', () {
    final files = gen.build(FeatureOptions(featureName: 'home'));

    test('emits the Clean Architecture layers', () {
      expect(files.keys, containsAll(<String>[
        'lib/features/home/domain/repositories/home_repository.dart',
        'lib/features/home/domain/use_cases/home_use_cases.dart',
        'lib/features/home/data/datasources/remote/home_remote_datasource.dart',
        'lib/features/home/data/datasources/local/home_local_datasource.dart',
        'lib/features/home/data/repositories/home_repository_impl.dart',
        'lib/features/home/presentation/blocs/blocs.dart',
        'lib/features/home/presentation/blocs/home_bloc/home_bloc.dart',
        'lib/features/home/presentation/blocs/home_bloc/home_event.dart',
        'lib/features/home/presentation/blocs/home_bloc/home_state.dart',
        'lib/features/home/presentation/pages/home_page.dart',
      ]));
    });

    test('uses vgv conventions (relative imports, TStateless, Injector)', () {
      final page = files['lib/features/home/presentation/pages/home_page.dart']!;
      expect(page, contains('extends TStateless<HomeBloc>'));
      expect(page, contains('Injector.get<HomeBloc>()'));
      expect(page, contains("import '../../../../core/states/tstateless.dart';"));
    });

    test('bloc is a HydratedBloc with freezed parts', () {
      final bloc =
          files['lib/features/home/presentation/blocs/home_bloc/home_bloc.dart']!;
      expect(bloc, contains('extends HydratedBloc<HomeEvent, HomeState>'));
      expect(bloc, contains("part 'home_bloc.freezed.dart';"));
    });
  });

  group('FeatureGenerator options', () {
    test('--no-bloc drops the bloc and page bloc wiring', () {
      final files = gen.build(FeatureOptions(
        featureName: 'reports',
        includeBloc: false,
      ));
      expect(
        files.keys.where((k) => k.contains('/blocs/')),
        isEmpty,
      );
      final page =
          files['lib/features/reports/presentation/pages/reports_page.dart']!;
      expect(page, contains('TStateless<Null>'));
      expect(page, contains('Null get bloc => null;'));
    });

    test('--stateful emits a StatefulWidget page', () {
      final files = gen.build(FeatureOptions(
        featureName: 'reports',
        statelessPage: false,
      ));
      final page =
          files['lib/features/reports/presentation/pages/reports_page.dart']!;
      expect(page, contains('extends StatefulWidget'));
      expect(page, contains('extends TStateful<ReportsPage, ReportsBloc>'));
    });

    test('--no-page omits the page', () {
      final files = gen.build(FeatureOptions(
        featureName: 'reports',
        addPage: false,
      ));
      expect(files.keys.where((k) => k.contains('/pages/')), isEmpty);
    });

    test('custom bloc name is honored and suffix not doubled', () {
      final files = gen.build(FeatureOptions(
        featureName: 'auth',
        blocName: 'SessionBloc',
      ));
      expect(
        files.keys,
        contains(
            'lib/features/auth/presentation/blocs/session_bloc/session_bloc.dart'),
      );
    });
  });
}
