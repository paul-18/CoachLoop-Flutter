/// Local SQLite database (drift). Everything stays on the device:
/// no accounts, no sync, no backend.
///
/// Workouts are stored as versioned JSON rows (schema v1) — simple, robust,
/// and faithful to the PWA's whole-log model without migration complexity
/// in phase 1. The `status` and `date` columns exist so history queries stay
/// cheap without parsing every payload.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Workouts extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  TextColumn get status => text()();
  TextColumn get date => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Workouts, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test constructor: pass any [QueryExecutor], e.g. an in-memory database.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() => driftDatabase(
      name: 'coach_loop',
      // Required on web: without these, driftDatabase() throws and the app
      // never starts (blank page). The two files live in web/ and are copied
      // into the build output by `flutter build web`.
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
