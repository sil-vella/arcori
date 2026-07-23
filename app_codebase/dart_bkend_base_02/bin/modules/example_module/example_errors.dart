/// Module-owned error codes for example_module.
library;

import '../../core/errors/contracts/register_module_error_contract.dart';
import '../../core/errors/error_spec.dart';

const exampleUnauthorized = ErrorSpec(
  'example_module/unauthorized',
  'User id required',
  401,
);

void registerExampleModuleErrors(ModuleErrorRegistrar registrar) {
  registrar.registerModule('example_module', [exampleUnauthorized]);
}
