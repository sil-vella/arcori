import 'dart:convert';

bool secretsEqual(String provided, String expected) {
  if (expected.isEmpty) return false;
  final providedBytes = utf8.encode(provided);
  final expectedBytes = utf8.encode(expected);
  if (providedBytes.length != expectedBytes.length) return false;
  var diff = 0;
  for (var i = 0; i < providedBytes.length; i++) {
    diff |= providedBytes[i] ^ expectedBytes[i];
  }
  return diff == 0;
}
