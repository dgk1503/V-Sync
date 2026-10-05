// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_remote_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(calendarRemoteRepository)
final calendarRemoteRepositoryProvider = CalendarRemoteRepositoryProvider._();

final class CalendarRemoteRepositoryProvider
    extends
        $FunctionalProvider<
          CalendarRemoteRepository,
          CalendarRemoteRepository,
          CalendarRemoteRepository
        >
    with $Provider<CalendarRemoteRepository> {
  CalendarRemoteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarRemoteRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarRemoteRepositoryHash();

  @$internal
  @override
  $ProviderElement<CalendarRemoteRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CalendarRemoteRepository create(Ref ref) {
    return calendarRemoteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarRemoteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarRemoteRepository>(value),
    );
  }
}

String _$calendarRemoteRepositoryHash() =>
    r'82187ba7984e075b3af620d0a14e8a82a408bbac';
