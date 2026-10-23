import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:vgv_cli/domain/entities/project_config.dart';
import 'package:vgv_cli/domain/repositories/project_repository.dart';
import 'package:vgv_cli/presentation/controllers/cli_controller.dart';

class _FakeRepository implements ProjectRepository {
  _FakeRepository({this.flutterInstalled = true, this.fail = false});

  final bool flutterInstalled;
  final bool fail;
  ProjectConfig? created;

  @override
  Future<List<String>> createProject(ProjectConfig config) async {
    if (fail) throw StateError('boom');
    created = config;
    return const <String>[];
  }

  @override
  Future<bool> isFlutterInstalled() async => flutterInstalled;

  @override
  Future<void> addStateManagement(String p, StateManagementType s) async {}

  @override
  Future<void> addGoRouter(String p) async {}

  @override
  Future<void> addCleanArchitecture(String p) async {}
}

void main() {
  CliController controller(ProjectRepository repo) =>
      CliController(repo, logger: Logger(level: Level.quiet));

  group('runWithFlags exit codes', () {
    test('invalid project name → 1, nothing created', () async {
      final repo = _FakeRepository();
      final code = await controller(
        repo,
      ).runWithFlags(projectName: 'Bad-Name', quickMode: true);
      expect(code, 1);
      expect(repo.created, isNull);
    });

    test('invalid organization → 1, nothing created', () async {
      final repo = _FakeRepository();
      final code = await controller(repo).runWithFlags(
        projectName: 'ok_app',
        organization: 'com..x',
        quickMode: true,
      );
      expect(code, 1);
      expect(repo.created, isNull);
    });

    test('valid flags → 0 and the config reaches the repository', () async {
      final repo = _FakeRepository();
      final code = await controller(repo).runWithFlags(
        projectName: 'ok_app',
        organization: 'com.acme',
        quickMode: true,
        flavors: const [Flavor.dev, Flavor.production],
      );
      expect(code, 0);
      expect(repo.created?.baseBundleId, 'com.acme.ok_app');
      expect(repo.created?.flavors, [Flavor.dev, Flavor.production]);
    });

    test('-n without a terminal proceeds instead of prompting', () async {
      final repo = _FakeRepository();
      final code = await controller(repo).runWithFlags(projectName: 'ok_app');
      expect(code, 0);
      expect(repo.created, isNotNull);
    }, skip: CliController.hasTerminal ? 'needs a non-TTY run' : false);

    test('Flutter missing → 1', () async {
      final code = await controller(
        _FakeRepository(flutterInstalled: false),
      ).runWithFlags(projectName: 'ok_app', quickMode: true);
      expect(code, 1);
    });

    test('generation failure → 1', () async {
      final code = await controller(
        _FakeRepository(fail: true),
      ).runWithFlags(projectName: 'ok_app', quickMode: true);
      expect(code, 1);
    });
  });
}
