/// Shared Kin Lottie bake size caps (disc faces are small).
///
/// Full-composition addition / background PNGs must **not** be independently
/// downscaled before insert — transparent padding holds position relative to
/// Kin layers. Claim bake applies one uniform scale via the Python optimizer.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Legacy helper max edge (prefer uniform composition scale instead).
const int kKinBakeMaxAssetEdge = 384;

/// Max composition edge written into saved / claimed Lottie JSON (server).
const int kKinBakeMaxCompEdge = 384;

/// Max edge for claim-background rasters before insert.
///
/// Tall Entelair square-pad can exceed authored size; baking at full size OOMs
/// `package:image` and can fail mid-claim (solid gray fallback). Cap the PNG
/// and compensate with layer `ks.s` so every template covers the full canvas.
const int kKinBgBakeMaxEdge = 384;

/// Downscale [bytes] so max(w,h) ≤ [maxEdge]; re-encode optimized PNG.
///
/// Do **not** use on Kin addition embeds or claim backgrounds that share the
/// composition canvas — that desyncs layout from layer transforms.
Uint8List shrinkKinPngBytes(
  Uint8List bytes, {
  int maxEdge = kKinBakeMaxAssetEdge,
}) {
  if (bytes.isEmpty || maxEdge < 1) return bytes;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final edge = decoded.width > decoded.height ? decoded.width : decoded.height;
  img.Image out = decoded;
  if (edge > maxEdge) {
    final scale = maxEdge / edge;
    final nw = (decoded.width * scale).round().clamp(1, maxEdge);
    final nh = (decoded.height * scale).round().clamp(1, maxEdge);
    out = img.copyResize(
      decoded,
      width: nw,
      height: nh,
      interpolation: img.Interpolation.linear,
    );
  }
  return Uint8List.fromList(img.encodePng(out));
}
