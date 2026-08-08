import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/model_generator.dart';

void main() {
  final gen = ModelGenerator();

  test('infers primitive types and marks nulls nullable', () {
    final files = gen.build(name: 'User', json: <String, dynamic>{
      'id': 'x',
      'age': 3,
      'score': 1.5,
      'active': true,
      'nickname': null,
    });
    final model = files['lib/models/user_model.dart']!;
    expect(model, contains('required String id,'));
    expect(model, contains('required int age,'));
    expect(model, contains('required double score,'));
    expect(model, contains('required bool active,'));
    expect(model, contains('dynamic nickname,'));
    expect(model, contains('factory UserModel.fromJson'));
  });

  test('nested object becomes a nested class with fromModel wiring', () {
    final files = gen.build(name: 'User', json: <String, dynamic>{
      'address': <String, dynamic>{'street': 'Main', 'zip': '1000'},
    });
    final model = files['lib/models/user_model.dart']!;
    final entity = files['lib/models/user_entity.dart']!;
    expect(model, contains('abstract class AddressModel'));
    expect(model, contains('required AddressModel address,'));
    expect(entity, contains('address: AddressEntity.fromModel(model.address),'));
  });

  test('list of objects becomes List<ElementModel> + .map(fromModel)', () {
    final files = gen.build(name: 'Cart', json: <String, dynamic>{
      'orders': <dynamic>[
        <String, dynamic>{'orderId': 'o1', 'total': 12.5},
      ],
    });
    final model = files['lib/models/cart_model.dart']!;
    final entity = files['lib/models/cart_entity.dart']!;
    // "orders" -> singularized element class "Order".
    expect(model, contains('abstract class OrderModel'));
    expect(model, contains('required List<OrderModel> orders,'));
    expect(entity,
        contains('orders: model.orders.map(OrderEntity.fromModel).toList(),'));
  });

  test('list of primitives stays List<primitive>', () {
    final files = gen.build(name: 'User', json: <String, dynamic>{
      'roles': <dynamic>['admin', 'user'],
    });
    final model = files['lib/models/user_model.dart']!;
    expect(model, contains('required List<String> roles,'));
  });

  test('feature placement puts files under lib/features/<f>/', () {
    final files = gen.build(
      name: 'User',
      feature: 'account',
      json: <String, dynamic>{'id': 'x'},
    );
    expect(files.keys, contains('lib/features/account/data/models/user_model.dart'));
    expect(
        files.keys, contains('lib/features/account/domain/entities/user_entity.dart'));
  });

  test('rejects a non-object top-level JSON', () {
    expect(
      () => gen.build(name: 'X', json: <dynamic>[1, 2, 3]),
      throwsA(isA<FormatException>()),
    );
  });
}
