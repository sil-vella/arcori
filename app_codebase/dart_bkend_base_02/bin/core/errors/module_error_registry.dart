/// Runtime registry for module-owned namespaced error codes.
library;

import 'contracts/register_module_error_contract.dart';
import 'error_codes.dart';
import 'error_spec.dart';

class ModuleErrorRegistry implements ModuleErrorRegistrar {
  ModuleErrorRegistry();

  final Map<String, ErrorSpec> _specs = {};

  void clear() => _specs.clear();

  @override
  void registerModule(String moduleName, Iterable<ErrorSpec> specs) {
    final prefix = '$moduleName/';
    for (final spec in specs) {
      if (coreCodes.contains(spec.code)) {
        throw ArgumentError('Module code collides with core catalog: ${spec.code}');
      }
      if (!spec.isModuleCode) {
        throw ArgumentError(
          'Module error code must be namespaced (module/reason): ${spec.code}',
        );
      }
      if (!spec.code.startsWith(prefix)) {
        throw ArgumentError(
          "Module '$moduleName' code must start with '$prefix': ${spec.code}",
        );
      }
      if (_specs.containsKey(spec.code)) {
        throw ArgumentError('Duplicate module error code: ${spec.code}');
      }
      _specs[spec.code] = spec;
    }
  }

  ErrorSpec? lookup(String code) => _specs[code];
}

final moduleErrorRegistrar = ModuleErrorRegistry();

void resetModuleErrorRegistry() => moduleErrorRegistrar.clear();

ErrorSpec? lookupModuleError(String code) => moduleErrorRegistrar.lookup(code);
