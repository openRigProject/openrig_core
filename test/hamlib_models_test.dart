import 'package:openrig_core/openrig_core.dart';
import 'package:test/test.dart';

void main() {
  test('kCommonHamlibModels is non-empty', () {
    expect(kCommonHamlibModels, isNotEmpty);
  });

  test('contains at least 50 entries', () {
    expect(kCommonHamlibModels.length, greaterThanOrEqualTo(50));
  });

  test('all entries have positive IDs', () {
    for (final model in kCommonHamlibModels) {
      expect(model.id, greaterThan(0), reason: '${model.name} has invalid id');
    }
  });

  test('all entries have non-empty name and manufacturer', () {
    for (final model in kCommonHamlibModels) {
      expect(model.name, isNotEmpty, reason: 'id ${model.id} has empty name');
      expect(model.manufacturer, isNotEmpty,
          reason: '${model.name} has empty manufacturer');
    }
  });

  test('IDs are unique', () {
    final ids = kCommonHamlibModels.map((m) => m.id).toSet();
    expect(ids.length, equals(kCommonHamlibModels.length));
  });

  test('contains known models', () {
    final ids = kCommonHamlibModels.map((m) => m.id).toSet();
    expect(ids, contains(1)); // Dummy
    expect(ids, contains(2)); // NET rigctl
    expect(ids, contains(3085)); // IC-705
    expect(ids, contains(3073)); // IC-7300
    expect(ids, contains(1035)); // FT-991A
  });

  test('IC-705 has correct fields', () {
    final ic705 = kCommonHamlibModels.firstWhere((m) => m.id == 3085);
    expect(ic705.name, equals('IC-705'));
    expect(ic705.manufacturer, equals('Icom'));
  });
}
