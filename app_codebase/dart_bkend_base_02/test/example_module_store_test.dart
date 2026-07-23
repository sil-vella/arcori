import 'package:test/test.dart';

import '../bin/modules/example_module/example_store.dart';

void main() {
  group('ExampleModuleStore', () {
    test('applyPatch bumps revision', () {
      final store = ExampleModuleStore();
      final first = store.applyPatch({'message': 'hello'});
      expect(first.revision, 1);
      expect(first.message, 'hello');

      final second = store.applyPatch({'message': 'world'});
      expect(second.revision, 2);
      expect(second.message, 'world');
    });
  });
}
