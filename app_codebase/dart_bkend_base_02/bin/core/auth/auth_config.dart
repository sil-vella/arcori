import 'dart:io';

const _placeholderMarkers = ['change-me', 'REPLACE_WITH'];

String wfEnv() => Platform.environment['ARCORI_ENV'] ?? 'local';

bool isProduction() => wfEnv().toLowerCase() == 'production';

bool devLoginAllowed() {
  final value = Platform.environment['ARCORI_ALLOW_DEV_LOGIN'] ?? 'false';
  return value.toLowerCase() == 'true' || value == '1' || value == 'yes';
}

String jwtSecret() => Platform.environment['JWT_SECRET'] ?? '';

String jwtRefreshSecret() => Platform.environment['JWT_REFRESH_SECRET'] ?? '';

int jwtAccessExpiresSeconds() =>
    int.tryParse(Platform.environment['JWT_ACCESS_EXPIRES_SECONDS'] ?? '') ??
    3600;

int jwtRefreshExpiresSeconds() =>
    int.tryParse(Platform.environment['JWT_REFRESH_EXPIRES_SECONDS'] ?? '') ??
    604800;

String serviceKey() => Platform.environment['SERVICE_KEY'] ?? '';

bool _looksLikePlaceholder(String value) {
  final lowered = value.toLowerCase();
  return _placeholderMarkers.any(lowered.contains);
}

void _requireNonEmpty(String name, String value) {
  if (value.isEmpty || _looksLikePlaceholder(value)) {
    throw StateError(
      '$name must be set to a strong secret when ARCORI_ENV=production',
    );
  }
}

void requireSecretsForProduction() {
  if (!isProduction()) return;
  _requireNonEmpty('JWT_SECRET', jwtSecret());
  _requireNonEmpty('JWT_REFRESH_SECRET', jwtRefreshSecret());
  _requireNonEmpty('SERVICE_KEY', serviceKey());
}
