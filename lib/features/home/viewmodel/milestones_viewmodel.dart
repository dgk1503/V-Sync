import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/core/services/notification_service.dart';
import 'package:vit_ap_student_app/features/home/model/milestone.dart';

final milestonesProvider =
    NotifierProvider<MilestonesNotifier, List<Milestone>>(
  MilestonesNotifier.new,
);

class MilestonesNotifier extends Notifier<List<Milestone>> {
  static const _storageKey = 'milestones_v1';

  @override
  List<Milestone> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;

      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Milestone.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => a.targetDate.compareTo(b.targetDate));
      state = list;
      // Re-align pending reminders with the freshly loaded list (covers
      // device reboots and any scheduling missed while the app was closed).
      unawaited(NotificationService.syncMilestoneReminders(list));
    } catch (e) {
      debugPrint('Failed to load milestones: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(state.map((m) => m.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Failed to save milestones: $e');
    }
  }

  Future<void> addMilestone({
    required String title,
    String? info,
    required DateTime targetDate,
    bool reminderEnabled = false,
    int reminderMinutesBefore = 30,
  }) async {
    final normalizedInfo = info?.trim();
    final milestone = Milestone(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      info: (normalizedInfo == null || normalizedInfo.isEmpty)
          ? null
          : normalizedInfo,
      targetDate: targetDate,
      reminderEnabled: reminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore,
    );

    final updated = [...state, milestone]
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    state = updated;
    await _persist();

    // Opt-in reminder for this countdown (a no-op when disabled or when
    // the trigger moment already passed).
    await NotificationService.scheduleMilestoneReminder(milestone);
  }

  Future<void> removeMilestone(String id) async {
    state = state.where((m) => m.id != id).toList();
    await _persist();
    // Drop the pending reminder together with the countdown.
    await NotificationService.cancelMilestoneReminder(id);
  }

  /// Drops countdowns that finished more than 10 minutes ago.
  Future<void> removeExpired() async {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    final filtered =
        state.where((m) => m.targetDate.isAfter(cutoff)).toList();
    if (filtered.length == state.length) return;
    state = filtered;
    await _persist();
  }
}
