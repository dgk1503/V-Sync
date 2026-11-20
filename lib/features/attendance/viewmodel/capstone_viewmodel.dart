import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:vit_ap_student_app/core/models/credentials.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/core/services/data_cache_service.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/features/attendance/model/capstone_attendance.dart';
import 'package:vit_ap_student_app/features/attendance/repository/capstone_repository.dart';

/// What the capstone page shows.
class CapstoneState {
  const CapstoneState({
    this.loaded = false,
    this.capstone,
    this.refreshing = false,
    this.error,
    this.updatedAt,
  });

  /// Whether we know the answer yet (from the saved copy or from VTOP).
  final bool loaded;

  /// Null once [loaded] means the student has no capstone registration.
  final CapstoneAttendance? capstone;
  final bool refreshing;

  /// Why the last refresh failed, shown quietly beside what is saved.
  final String? error;
  final DateTime? updatedAt;

  CapstoneState copyWith({
    bool? loaded,
    CapstoneAttendance? capstone,
    bool clearCapstone = false,
    bool? refreshing,
    String? error,
    bool clearError = false,
    DateTime? updatedAt,
  }) => CapstoneState(
    loaded: loaded ?? this.loaded,
    capstone: clearCapstone ? null : (capstone ?? this.capstone),
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : (error ?? this.error),
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Capstone / SDP attendance, saved on the phone and refreshed from VTOP when it
/// is stale or when asked.
///
/// A capstone that VTOP reports as missing never overwrites one that is saved:
/// the scraper turns a failed capstone request into "none", so a missing
/// capstone right after a saved one is more likely a hiccup than a withdrawn
/// registration.
final capstoneViewModelProvider =
    NotifierProvider.autoDispose<CapstoneViewModel, CapstoneState>(
      CapstoneViewModel.new,
    );

class CapstoneViewModel extends Notifier<CapstoneState> {
  /// How old the saved copy may be before the page refreshes it by itself.
  static const staleAfter = Duration(hours: 12);

  static String cacheKey(String semesterId) => 'capstone:$semesterId';

  @override
  CapstoneState build() {
    scheduleMicrotask(_start);
    return const CapstoneState();
  }

  Future<void> _start() async {
    if (DemoService.isDemoMode) {
      state = state.copyWith(loaded: true, clearCapstone: true);
      return;
    }
    final credentials = await ref
        .read(currentUserProvider.notifier)
        .getSavedCredentials();
    if (!ref.mounted) return;
    if (credentials == null) {
      state = state.copyWith(
        loaded: true,
        error: 'User not found. Please log out and log in.',
      );
      return;
    }

    final saved = ref
        .read(dataCacheServiceProvider)
        .readEntry(cacheKey(credentials.semSubId));
    if (saved != null) {
      try {
        final cached = CapstoneAttendance.fromResponse(saved.payload);
        state = state.copyWith(
          loaded: true,
          capstone: cached,
          clearCapstone: cached == null,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(saved.updatedAt),
        );
      } catch (_) {
        // An unreadable copy is as good as none: fetch.
      }
    }
    if (saved == null || saved.isOlderThan(staleAfter) || !state.loaded) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    if (DemoService.isDemoMode || state.refreshing) return;
    final Credentials? credentials = await ref
        .read(currentUserProvider.notifier)
        .getSavedCredentials();
    if (!ref.mounted) return;
    if (credentials == null) return;

    state = state.copyWith(refreshing: true, clearError: true);
    final res = await ref.read(capstoneRepositoryProvider).fetch(credentials);
    if (!ref.mounted) return;

    switch (res) {
      case Left(value: final failure):
        state = state.copyWith(
          loaded: true,
          refreshing: false,
          error: failure.message,
        );
      case Right(value: final fetched):
        if (fetched.capstone == null && state.capstone != null) {
          // See the class note: keep what is saved.
          state = state.copyWith(
            refreshing: false,
            error: 'Could not refresh your capstone right now.',
          );
          return;
        }
        final now = DateTime.now();
        ref
            .read(dataCacheServiceProvider)
            .write(
              cacheKey(credentials.semSubId),
              jsonEncode({'capstone': fetched.capstone?.toJson()}),
            );
        state = state.copyWith(
          loaded: true,
          refreshing: false,
          capstone: fetched.capstone,
          clearCapstone: fetched.capstone == null,
          updatedAt: now,
        );
    }
  }
}
