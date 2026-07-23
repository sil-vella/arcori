/// Metadata for core and module error codes.
library;

class ErrorSpec {
  const ErrorSpec(
    this.code,
    this.message,
    this.httpStatus, {
    this.fatalWs = false,
  });

  final String code;
  final String message;
  final int httpStatus;
  final bool fatalWs;

  bool get isModuleCode => code.contains('/');
}
