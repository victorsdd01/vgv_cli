import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Needs `web/sqlite3.wasm` (from the release of the resolved `sqlite3`) and
/// `web/drift_worker.js` (compiled from `tool/drift_worker.dart`). vgv sets
/// both up when it creates the project; redo it after upgrading drift or
/// sqlite3 — see https://drift.simonbinder.eu/platforms/web/.
QueryExecutor openConnection() => DatabaseConnection.delayed(
  Future<DatabaseConnection>(() async {
    final WasmDatabaseResult result = await WasmDatabase.open(
      databaseName: 'app',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  }),
);
