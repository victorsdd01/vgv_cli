import 'recase.dart';

/// Options for `vgv gen feature`.
class FeatureOptions {
  FeatureOptions({
    required String featureName,
    this.includeBloc = true,
    String? blocName,
    this.addPage = true,
    String? pageName,
    this.statelessPage = true,
    this.addBlocToPage = true,
  })  : feature = ReCase(featureName),
        // Bloc/page names default to the feature name; strip a trailing
        // "bloc"/"page" so we don't emit auth_bloc_bloc.dart etc.
        bloc = ReCase(_stripSuffix(blocName ?? featureName, 'bloc')),
        page = ReCase(_stripSuffix(pageName ?? featureName, 'page'));

  final ReCase feature;
  final ReCase bloc;
  final ReCase page;
  final bool includeBloc;
  final bool addPage;
  final bool statelessPage;
  final bool addBlocToPage;

  static String _stripSuffix(String input, String suffix) {
    final r = ReCase(input);
    final words = r.snakeCase.split('_');
    if (words.length > 1 && words.last == suffix) {
      words.removeLast();
      return words.join('_');
    }
    return input;
  }
}

/// Builds the file map for a Clean Architecture feature, matching the
/// conventions of a vgv-generated project (relative imports, `TStateless`/
/// `TStateful`, `HydratedBloc` + freezed, `Injector`, `dartz` `Either/Failure`).
class FeatureGenerator {
  /// Returns a map of `<relative path under the project root>` -> file content.
  Map<String, String> build(FeatureOptions o) {
    final f = o.feature.snakeCase;
    final root = 'lib/features/$f';
    final files = <String, String>{
      '$root/domain/repositories/${f}_repository.dart': _repository(o),
      '$root/domain/use_cases/${f}_use_cases.dart': _useCases(o),
      '$root/data/datasources/remote/${f}_remote_datasource.dart': _remote(o),
      '$root/data/datasources/local/${f}_local_datasource.dart': _local(o),
      '$root/data/repositories/${f}_repository_impl.dart': _repositoryImpl(o),
    };

    if (o.includeBloc) {
      final b = o.bloc.snakeCase;
      final dir = '$root/presentation/blocs/${b}_bloc';
      files['$root/presentation/blocs/blocs.dart'] =
          "export '${b}_bloc/${b}_bloc.dart';\n";
      files['$dir/${b}_bloc.dart'] = _bloc(o);
      files['$dir/${b}_event.dart'] = _event(o);
      files['$dir/${b}_state.dart'] = _state(o);
    }

    if (o.addPage) {
      files['$root/presentation/pages/${o.page.snakeCase}_page.dart'] = _page(o);
    }

    return files;
  }

  // ---- domain -------------------------------------------------------------

  String _repository(FeatureOptions o) {
    final F = o.feature.pascalCase;
    return '''import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract interface class ${F}Repository {
  Future<Either<Failure, void>> fetchData();
}
''';
  }

  String _useCases(FeatureOptions o) {
    final F = o.feature.pascalCase;
    final c = o.feature.camelCase;
    return '''import 'package:dartz/dartz.dart';
import '../repositories/${o.feature.snakeCase}_repository.dart';
import '../../../../core/errors/failures.dart';

class ${F}UseCases {
  const ${F}UseCases({required ${F}Repository repository}) : _${c}Repository = repository;

  final ${F}Repository _${c}Repository;

  Future<Either<Failure, void>> fetchData() => _${c}Repository.fetchData();
}
''';
  }

  // ---- data ---------------------------------------------------------------

  String _remote(FeatureOptions o) {
    final F = o.feature.pascalCase;
    return '''import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';

abstract interface class ${F}RemoteDataSource {
  Future<Either<Failure, void>> fetchData();
}

class ${F}RemoteDataSourceImpl implements ${F}RemoteDataSource {
  ${F}RemoteDataSourceImpl();

  @override
  Future<Either<Failure, void>> fetchData() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(ServerFailure(message: 'Failed to fetch data: \$e'));
    }
  }
}
''';
  }

  String _local(FeatureOptions o) {
    final F = o.feature.pascalCase;
    return '''import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';

abstract interface class ${F}LocalDataSource {
  Future<Either<Failure, void>> saveData();
}

class ${F}LocalDataSourceImpl implements ${F}LocalDataSource {
  const ${F}LocalDataSourceImpl();

  @override
  Future<Either<Failure, void>> saveData() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(CacheFailure(message: 'Failed to save data: \$e'));
    }
  }
}
''';
  }

  String _repositoryImpl(FeatureOptions o) {
    final F = o.feature.pascalCase;
    final c = o.feature.camelCase;
    final snake = o.feature.snakeCase;
    return '''import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/remote/${snake}_remote_datasource.dart';
import '../../domain/repositories/${snake}_repository.dart';

class ${F}RepositoryImpl implements ${F}Repository {
  const ${F}RepositoryImpl({required this.${c}RemoteDataSource});

  final ${F}RemoteDataSource ${c}RemoteDataSource;

  @override
  Future<Either<Failure, void>> fetchData() => ${c}RemoteDataSource.fetchData();
}
''';
  }

  // ---- presentation: bloc -------------------------------------------------

  String _bloc(FeatureOptions o) {
    final B = o.bloc.pascalCase;
    final b = o.bloc.snakeCase;
    final F = o.feature.pascalCase;
    final c = o.feature.camelCase;
    return '''import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../domain/use_cases/${o.feature.snakeCase}_use_cases.dart';

part '${b}_bloc.freezed.dart';
part '${b}_event.dart';
part '${b}_state.dart';

class ${B}Bloc extends HydratedBloc<${B}Event, ${B}State> {
  final ${F}UseCases _${c}UseCases;

  ${B}Bloc({required ${F}UseCases ${c}UseCases})
      : _${c}UseCases = ${c}UseCases,
        super(const ${B}State()) {
    on<_Started>(_onStarted);
  }

  Future<void> _onStarted(_Started event, Emitter<${B}State> emit) async {
    emit(state.copyWith(
      status: state.status.copyWith(isLoading: true),
      successStatus: state.successStatus.copyWith(load: false),
      errorStatus: state.errorStatus.copyWith(load: false),
      failure: null,
    ));

    final Either<Failure, void> result = await _${c}UseCases.fetchData();

    result.fold(
      (Failure failure) => emit(state.copyWith(
        status: state.status.copyWith(isLoading: false),
        errorStatus: state.errorStatus.copyWith(load: true),
        failure: failure,
      )),
      (_) => emit(state.copyWith(
        status: state.status.copyWith(isLoading: false),
        successStatus: state.successStatus.copyWith(load: true),
      )),
    );
  }

  @override
  ${B}State? fromJson(Map<String, dynamic> json) => null;

  @override
  Map<String, dynamic>? toJson(${B}State state) => null;
}
''';
  }

  String _event(FeatureOptions o) {
    final B = o.bloc.pascalCase;
    final b = o.bloc.snakeCase;
    return '''part of '${b}_bloc.dart';

@freezed
class ${B}Event with _\$${B}Event {
  const factory ${B}Event.started() = _Started;
}
''';
  }

  String _state(FeatureOptions o) {
    final B = o.bloc.pascalCase;
    final b = o.bloc.snakeCase;
    return '''part of '${b}_bloc.dart';

@freezed
abstract class ${B}Status with _\$${B}Status {
  const factory ${B}Status({@Default(false) bool isLoading}) = _${B}Status;
}

@freezed
abstract class ${B}SuccessStatus with _\$${B}SuccessStatus {
  const factory ${B}SuccessStatus({@Default(false) bool load}) = _${B}SuccessStatus;
}

@freezed
abstract class ${B}ErrorStatus with _\$${B}ErrorStatus {
  const factory ${B}ErrorStatus({@Default(false) bool load}) = _${B}ErrorStatus;
}

@freezed
abstract class ${B}State with _\$${B}State {
  const factory ${B}State({
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(${B}Status()) ${B}Status status,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(${B}SuccessStatus()) ${B}SuccessStatus successStatus,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(${B}ErrorStatus()) ${B}ErrorStatus errorStatus,
    @JsonKey(includeFromJson: false, includeToJson: false)
    Failure? failure,
  }) = _${B}State;
}
''';
  }

  // ---- presentation: page -------------------------------------------------

  String _page(FeatureOptions o) {
    final P = o.page.pascalCase;
    final withBloc = o.includeBloc && o.addBlocToPage;
    final B = o.bloc.pascalCase;
    final blocSnake = o.bloc.snakeCase;
    final blocType = withBloc ? '${B}Bloc' : 'Null';
    final blocGetter = withBloc
        ? '${B}Bloc get bloc => Injector.get<${B}Bloc>();'
        : 'Null get bloc => null;';
    final blocImport = withBloc
        ? "import '../blocs/${blocSnake}_bloc/${blocSnake}_bloc.dart';\n"
        : '';

    if (o.statelessPage) {
      return '''import 'package:flutter/material.dart';
import '../../../../application/generated/l10n.dart';
import '../../../../application/injector.dart';
import '../../../../core/states/tstateless.dart';
$blocImport
class ${P}Page extends TStateless<$blocType> {
  const ${P}Page({super.key});

  @override
  $blocGetter

  @override
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  ) => Scaffold(
    appBar: AppBar(
      title: const Text('$P'),
      backgroundColor: theme.colorScheme.inversePrimary,
    ),
    body: Center(
      child: Text('$P', style: theme.textTheme.titleLarge),
    ),
  );
}
''';
    }

    return '''import 'package:flutter/material.dart';
import '../../../../application/generated/l10n.dart';
import '../../../../application/injector.dart';
import '../../../../core/states/tstatefull.dart';
$blocImport
class ${P}Page extends StatefulWidget {
  const ${P}Page({super.key});

  @override
  State<${P}Page> createState() => _${P}PageState();
}

class _${P}PageState extends TStateful<${P}Page, $blocType> {
  @override
  $blocGetter

  @override
  Widget bodyWidget(
    BuildContext context,
    ThemeData theme,
    S translation,
  ) => Scaffold(
    appBar: AppBar(
      title: const Text('$P'),
      backgroundColor: theme.colorScheme.inversePrimary,
    ),
    body: Center(
      child: Text('$P', style: theme.textTheme.titleLarge),
    ),
  );
}
''';
  }
}
