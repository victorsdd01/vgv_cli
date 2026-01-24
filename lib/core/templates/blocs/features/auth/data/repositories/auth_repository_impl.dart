import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../datasources/local/auth_local_datasource.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import '../../../../core/utils/secure_storage_utils.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.authRemoteDataSource,
    required this.authLocalDataSource,
    required this.secureStorageUtils,
  });

  final AuthRemoteDataSource authRemoteDataSource;
  final AuthLocalDataSource authLocalDataSource;
  final SecureStorageUtils secureStorageUtils;

  @override
  Future<Either<Failure, UserEntity>> login(String email, String password) async {
    final Either<Failure, UserModel> result = await authRemoteDataSource.login(email, password);

    return result.fold(
      Left.new,
      (UserModel model) async {
        await authLocalDataSource.saveUser(model);
        if (model.token != null) {
          await secureStorageUtils.write('token', model.token!);
        }
        return Right<Failure, UserEntity>(UserEntity.fromModel(model));
      },
    );
  }

  @override
  Future<Either<Failure, UserEntity>> register(String email, String password, String? name) async {
    final Either<Failure, UserModel> result = await authRemoteDataSource.register(email, password, name);

    return result.fold(
      Left.new,
      (UserModel model) async {
        await authLocalDataSource.saveUser(model);
        if (model.token != null) {
          await secureStorageUtils.write('token', model.token!);
        }
        return Right<Failure, UserEntity>(UserEntity.fromModel(model));
      },
    );
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final String? token = await secureStorageUtils.read('token');
      if (token != null) {
        await secureStorageUtils.delete('token');
      }
      await authLocalDataSource.clearUsers();
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(CacheFailure(message: 'Logout failed: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final String? token = await secureStorageUtils.read('token');
      if (token == null) {
        return const Right<Failure, UserEntity?>(null);
      }

      final Either<Failure, List<UserModel>> allUsers = await authLocalDataSource.getAllUsers();

      return allUsers.fold(
        Left.new,
        (List<UserModel> users) {
          if (users.isEmpty) {
            return const Right<Failure, UserEntity?>(null);
          }

          final int index = users.indexWhere((UserModel u) => u.token == token);
          if (index == -1) {
            return const Right<Failure, UserEntity?>(null);
          }

          return Right<Failure, UserEntity?>(UserEntity.fromModel(users[index]));
        },
      );
    } catch (e) {
      return Left<Failure, UserEntity?>(CacheFailure(message: 'Failed to get current user: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isAuthenticated() async {
    try {
      final String? token = await secureStorageUtils.read('token');
      return Right<Failure, bool>(token != null && token.isNotEmpty);
    } catch (e) {
      return Left<Failure, bool>(CacheFailure(message: 'Failed to check authentication: $e'));
    }
  }
}
