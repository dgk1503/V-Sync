// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liquid_glass_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads the Liquid Glass fragment shader once and keeps it alive for the
/// app session. Returns null when the asset can't be loaded — the navbar
/// then silently falls back to the plain frosted blur capsule.

@ProviderFor(liquidGlassProgram)
final liquidGlassProgramProvider = LiquidGlassProgramProvider._();

/// Loads the Liquid Glass fragment shader once and keeps it alive for the
/// app session. Returns null when the asset can't be loaded — the navbar
/// then silently falls back to the plain frosted blur capsule.

final class LiquidGlassProgramProvider
    extends
        $FunctionalProvider<
          AsyncValue<FragmentProgram?>,
          FragmentProgram?,
          FutureOr<FragmentProgram?>
        >
    with $FutureModifier<FragmentProgram?>, $FutureProvider<FragmentProgram?> {
  /// Loads the Liquid Glass fragment shader once and keeps it alive for the
  /// app session. Returns null when the asset can't be loaded — the navbar
  /// then silently falls back to the plain frosted blur capsule.
  LiquidGlassProgramProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liquidGlassProgramProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liquidGlassProgramHash();

  @$internal
  @override
  $FutureProviderElement<FragmentProgram?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FragmentProgram?> create(Ref ref) {
    return liquidGlassProgram(ref);
  }
}

String _$liquidGlassProgramHash() =>
    r'b04aa7ecc166f647d6cef6a884b7627bf5a50edf';
