import 'package:test/test.dart';
import 'package:vgv_cli/core/utils/api_generator.dart';

void main() {
  final gen = ApiGenerator();

  final spec = <String, dynamic>{
    'openapi': '3.0.0',
    'paths': <String, dynamic>{
      '/pets': <String, dynamic>{
        'get': <String, dynamic>{
          'operationId': 'listPets',
          'responses': <String, dynamic>{
            '200': <String, dynamic>{
              'content': <String, dynamic>{
                'application/json': <String, dynamic>{
                  'schema': <String, dynamic>{
                    'type': 'array',
                    'items': <String, dynamic>{r'$ref': '#/components/schemas/Pet'},
                  },
                },
              },
            },
          },
        },
      },
    },
    'components': <String, dynamic>{
      'schemas': <String, dynamic>{
        'Pet': <String, dynamic>{
          'type': 'object',
          'required': <String>['id', 'name'],
          'properties': <String, dynamic>{
            'id': <String, dynamic>{'type': 'integer'},
            'name': <String, dynamic>{'type': 'string'},
            'tag': <String, dynamic>{'type': 'string'},
            'birth_date': <String, dynamic>{'type': 'string', 'format': 'date-time'},
            'owner': <String, dynamic>{r'$ref': '#/components/schemas/Owner'},
          },
        },
        'Owner': <String, dynamic>{
          'type': 'object',
          'properties': <String, dynamic>{
            'id': <String, dynamic>{'type': 'integer'},
          },
        },
      },
    },
  };

  final files = gen.build(name: 'Petstore', spec: spec);
  final models = files['lib/api/petstore/models/petstore_models.dart']!;
  final client = files['lib/api/petstore/datasources/remote/petstore_api.dart']!;

  test('schemas become freezed models with required + nullable fields', () {
    expect(models, contains('abstract class PetModel'));
    expect(models, contains('required int id,'));
    expect(models, contains('required String name,'));
    expect(models, contains('String? tag,'));
  });

  test('date-time maps to DateTime and snake keys get a JsonKey', () {
    expect(models, contains("@JsonKey(name: 'birth_date') DateTime? birthDate,"));
  });

  test('\$ref maps to the referenced model type', () {
    expect(models, contains('OwnerModel? owner,'));
    expect(models, contains('abstract class OwnerModel'));
  });

  test('paths become typed client methods with a resolved return type', () {
    expect(client, contains('class PetstoreApi'));
    expect(client, contains('Future<List<PetModel>> listPets()'));
    expect(client, contains("throw UnimplementedError('TODO: GET /pets')"));
  });
}
