/// Module contract for registering notification subtype specs.
library;

import '../notification_subtype_spec.dart';

abstract class NotificationSubtypeSink {
  void registerSubtypes(List<NotificationSubtypeSpec> specs);
}
