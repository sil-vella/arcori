/// Ops module errors (drain / maintenance).
library;

import '../../core/errors/contracts/register_module_error_contract.dart';
import '../../core/errors/error_spec.dart';

/// HTTP/service drain rejection.
const drainModeError = ErrorSpec(
  'ops/drain_mode',
  'Server is in drain / maintenance mode',
  503,
  fatalWs: true,
);

/// WS close/reject code (Dutch-compatible name).
const serverMaintenance = ErrorSpec(
  'server_maintenance',
  'Server is in drain / maintenance mode',
  503,
  fatalWs: true,
);

void registerOpsErrors(ModuleErrorRegistrar registrar) {
  registrar.registerModule('ops', [drainModeError]);
}
