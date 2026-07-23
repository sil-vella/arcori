/// Module-owned WebSocket demo error codes.
library;

import '../../core/errors/contracts/register_module_error_contract.dart';
import '../../core/errors/error_spec.dart';

const demoRoomNotImplemented = ErrorSpec(
  'ws/demo_room/not_implemented',
  'Room subscribe not implemented',
  501,
);

void registerDemoErrors(ModuleErrorRegistrar registrar) {
  registrar.registerModule('ws', [demoRoomNotImplemented]);
}
