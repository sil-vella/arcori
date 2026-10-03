import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  for (final name in [
    'KIN_BG_ABSTRACT_COMIC_002.webp',
    'KIN_BG_ABSTRACT_LOW_POLY_009.webp',
  ]) {
    final path =
        '/Users/sil/Documents/Work/reignofplay/arcori/app_dev_fastapi_postgres/assets/lottie/kin/ser001/00backgrounds/$name';
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    final webp = img.decodeWebP(bytes);
    print('$name decodeImage=${decoded?.width}x${decoded?.height} decodeWebP=${webp?.width}x${webp?.height} bytes=${bytes.length}');
  }
}
