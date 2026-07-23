/// Let feature modules register domain error codes without touching the core catalog.
library;

import '../error_spec.dart';

abstract class ModuleErrorRegistrar {
  void registerModule(String moduleName, Iterable<ErrorSpec> specs);
}
