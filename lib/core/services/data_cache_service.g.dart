// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_cache_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads and writes [DataCache] rows.
///
/// Deliberately synchronous: ObjectBox is an embedded store, so a cache read is
/// a memory/disk hit rather than network. That is what lets a screen render its
/// cached copy on the very first frame instead of showing a loader for the
/// length of a VTOP round-trip.

@ProviderFor(dataCacheService)
final dataCacheServiceProvider = DataCacheServiceProvider._();

/// Reads and writes [DataCache] rows.
///
/// Deliberately synchronous: ObjectBox is an embedded store, so a cache read is
/// a memory/disk hit rather than network. That is what lets a screen render its
/// cached copy on the very first frame instead of showing a loader for the
/// length of a VTOP round-trip.

final class DataCacheServiceProvider
    extends
        $FunctionalProvider<
          DataCacheService,
          DataCacheService,
          DataCacheService
        >
    with $Provider<DataCacheService> {
  /// Reads and writes [DataCache] rows.
  ///
  /// Deliberately synchronous: ObjectBox is an embedded store, so a cache read is
  /// a memory/disk hit rather than network. That is what lets a screen render its
  /// cached copy on the very first frame instead of showing a loader for the
  /// length of a VTOP round-trip.
  DataCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataCacheServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataCacheServiceHash();

  @$internal
  @override
  $ProviderElement<DataCacheService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DataCacheService create(Ref ref) {
    return dataCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataCacheService>(value),
    );
  }
}

String _$dataCacheServiceHash() => r'81eb2c8dc30084143326d95da6c1a04b148e2c6c';
