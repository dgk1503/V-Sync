// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detailed_attendance_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DetailedAttendanceViewmodel)
final detailedAttendanceViewmodelProvider =
    DetailedAttendanceViewmodelProvider._();

final class DetailedAttendanceViewmodelProvider
    extends
        $NotifierProvider<
          DetailedAttendanceViewmodel,
          AsyncValue<List<AttendanceDetail>>?
        > {
  DetailedAttendanceViewmodelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'detailedAttendanceViewmodelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$detailedAttendanceViewmodelHash();

  @$internal
  @override
  DetailedAttendanceViewmodel create() => DetailedAttendanceViewmodel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<AttendanceDetail>>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<AttendanceDetail>>?>(
        value,
      ),
    );
  }
}

String _$detailedAttendanceViewmodelHash() =>
    r'e095878ebca1f33220178278bc0b2acc48f43c69';

abstract class _$DetailedAttendanceViewmodel
    extends $Notifier<AsyncValue<List<AttendanceDetail>>?> {
  AsyncValue<List<AttendanceDetail>>? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<AttendanceDetail>>?,
              AsyncValue<List<AttendanceDetail>>?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<AttendanceDetail>>?,
                AsyncValue<List<AttendanceDetail>>?
              >,
              AsyncValue<List<AttendanceDetail>>?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
