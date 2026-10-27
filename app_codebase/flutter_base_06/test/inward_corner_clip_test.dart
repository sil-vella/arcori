import 'dart:ui' as ui;

import 'package:arcori/core/theme/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inward corners are holes, and the face stays filled', () {
    const border = InwardCornerBorder();
    final rect = Rect.fromLTWH(0, 0, 220, 48);
    final path = border.getOuterPath(rect);
    final radius = 48 * 0.115;

    expect(path.contains(const Offset(110, 24)), isTrue);
    expect(path.contains(Offset(radius * 0.4, radius * 0.4)), isFalse);
    expect(path.contains(const Offset(219, 1)), isFalse);
    expect(
      path.contains(Offset(220 - radius - 2, 24)),
      isTrue,
    );
  });

  test('shine border sits inside the face', () async {
    const border = InwardCornerBorder(
      side: BorderSide(color: Color(0xFFFFFFFF), width: 1),
    );
    final rect = Rect.fromLTWH(0, 0, 220, 48);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawPath(border.getOuterPath(rect), Paint()..color = const Color(0xFF000000));
    border.paint(canvas, rect);
    final image = recorder.endRecording().toImageSync(220, 48);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    final data = bytes.buffer.asUint8List();

    int argb(int x, int y) {
      final i = (y * 220 + x) * 4;
      return data[i + 3] << 24 | data[i] << 16 | data[i + 1] << 8 | data[i + 2];
    }

    bool nearWhite(int color) {
      final r = (color >> 16) & 255;
      final g = (color >> 8) & 255;
      final b = color & 255;
      return r > 140 && g > 140 && b > 140;
    }

    expect(argb(0, 0) & 0xFF000000, 0, reason: 'cut corner stays empty');
    expect(nearWhite(argb(110, 0)), isFalse, reason: 'line sits in from the edge');
    final onLine = List<bool>.generate(5, (i) => nearWhite(argb(110, i + 1)));
    expect(onLine.contains(true), isTrue, reason: 'top line is the shine');
  });
}
