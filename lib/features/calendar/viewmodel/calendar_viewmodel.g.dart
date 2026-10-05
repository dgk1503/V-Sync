// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CalendarViewmodel)
final calendarViewmodelProvider = CalendarViewmodelProvider._();

final class CalendarViewmodelProvider
    extends
        $NotifierProvider<CalendarViewmodel, AsyncValue<List<CalendarMonth>>> {
  CalendarViewmodelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarViewmodelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarViewmodelHash();

  @$internal
  @override
  CalendarViewmodel create() => CalendarViewmodel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<CalendarMonth>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<CalendarMonth>>>(
        value,
      ),
    );
  }
}

String _$calendarViewmodelHash() => r'f7b07cef335d34680636203868c2b2375d4a1648';

abstract class _$CalendarViewmodel
    extends $Notifier<AsyncValue<List<CalendarMonth>>> {
  AsyncValue<List<CalendarMonth>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<CalendarMonth>>,
              AsyncValue<List<CalendarMonth>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<CalendarMonth>>,
                AsyncValue<List<CalendarMonth>>
              >,
              AsyncValue<List<CalendarMonth>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
