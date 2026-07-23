/// Declarative rules per notification (source, category, subtype).
library;

class NotificationSubtypeSpec {
  const NotificationSubtypeSpec({
    required this.source,
    required this.category,
    required this.subtype,
    this.allowedScreens = const {},
    this.modalPriority = 100,
    this.markReadOnDismiss = true,
    this.interModalDelayMs = kDefaultInterMessageDelayMs,
  });

  final String source;
  final String category;
  final String subtype;
  final Set<String> allowedScreens;
  final int modalPriority;
  final bool markReadOnDismiss;
  final int interModalDelayMs;

  String get key => '$source:$category:$subtype';
}

const kDefaultInterMessageDelayMs = 700;
