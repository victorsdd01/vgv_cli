import 'package:drift/drift.dart';

import 'connection/connection.dart';

part 'app_database.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text()();
  TextColumn get name => text().nullable()();
  TextColumn get token => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: <Type>[Users])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 1;

  Future<User?> getUserByEmail(String email) async {
    final SimpleSelectStatement<$UsersTable, User> query = select(users)..where((Users u) => u.email.equals(email));
    return await query.getSingleOrNull();
  }

  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);

  Future<bool> updateUser(User user) async {
    await (update(users)..where((Users u) => u.id.equals(user.id))).replace(user);
    return true;
  }

  Future<bool> deleteUser(int id) async {
    final int deleted = await (delete(users)..where((Users u) => u.id.equals(id))).go();
    return deleted > 0;
  }

  Future<void> clearUsers() => delete(users).go();

  Future<List<User>> getAllUsers() => select(users).get();
}

