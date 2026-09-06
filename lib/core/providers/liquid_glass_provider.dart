import 'dart:ui' show FragmentProgram;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'liquid_glass_provider.g.dart';

/// Loads the Liquid Glass fragment shader once and keeps it alive for the
/// app session. Returns null when the asset can't be loaded — the navbar
/// then silently falls back to the plain frosted blur capsule.
@Riverpod(keepAlive: true)
Future<FragmentProgram?> liquidGlassProgram(Ref ref) async {
  try {
    return await FragmentProgram.fromAsset('shaders/liquid_glass.frag');
  } catch (_) {
    return null;
  }
}
