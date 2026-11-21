import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the user chose for the Thumb Dock.
///
/// Kept in SharedPreferences rather than the ObjectBox preferences row: it is a
/// small, self-contained beta feature, and adding columns to the entity would
/// mean regenerating the database code for every install.
class ThumbDockSettings {
  const ThumbDockSettings({
    this.enabled = false,
    this.rightSide = true,
    this.y = 0.55,
    this.shortcuts = defaultShortcuts,
    this.glass = true,
  });

  /// Off until the user turns it on: it is a beta.
  final bool enabled;
  final bool rightSide;

  /// Handle height as a fraction (0 top, 1 bottom) of the usable screen height.
  final double y;

  /// Ids from `DockShortcuts`, in the order they appear in the Academics row.
  /// Always starts with [lockedShortcuts].
  final List<String> shortcuts;

  /// Liquid Glass look (the navbar's material). On by default; slower phones
  /// can switch it off for plain solid panels.
  final bool glass;

  /// Always in the row and cannot be taken out: the two pages used most.
  static const lockedShortcuts = ['attendance', 'marks'];

  static const defaultShortcuts = ['attendance', 'marks', 'exams'];

  /// [ids] with the locked shortcuts first, once each, and no more than
  /// [maxShortcuts] in all. Whatever was saved, the row is always valid.
  static List<String> normalise(List<String> ids) {
    final rest = <String>[
      for (final id in ids)
        if (!lockedShortcuts.contains(id)) id,
    ];
    final unique = <String>[...lockedShortcuts];
    for (final id in rest) {
      if (!unique.contains(id) && unique.length < maxShortcuts) unique.add(id);
    }
    return unique;
  }

  /// The most shortcuts the row can hold (see `DockLayout.maxSubs`).
  static const maxShortcuts = 5;

  /// How many of them the user may choose freely.
  static int get customSlots => maxShortcuts - lockedShortcuts.length;

  ThumbDockSettings copyWith({
    bool? enabled,
    bool? rightSide,
    double? y,
    List<String>? shortcuts,
    bool? glass,
  }) => ThumbDockSettings(
    enabled: enabled ?? this.enabled,
    rightSide: rightSide ?? this.rightSide,
    y: y ?? this.y,
    shortcuts: shortcuts ?? this.shortcuts,
    glass: glass ?? this.glass,
  );
}

final thumbDockProvider =
    NotifierProvider<ThumbDockNotifier, ThumbDockSettings>(
      ThumbDockNotifier.new,
    );

class ThumbDockNotifier extends Notifier<ThumbDockSettings> {
  static const _enabledKey = 'thumb_dock_enabled_v1';
  static const _rightKey = 'thumb_dock_right_v1';
  static const _yKey = 'thumb_dock_y_v1';
  static const _shortcutsKey = 'thumb_dock_shortcuts_v1';
  static const _glassKey = 'thumb_dock_glass_v1';

  static const maxShortcuts = ThumbDockSettings.maxShortcuts;

  /// A choice made before the saved values finished loading wins over them.
  bool _changed = false;

  @override
  ThumbDockSettings build() {
    _load();
    return const ThumbDockSettings();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (_changed) return;
      state = ThumbDockSettings(
        enabled: p.getBool(_enabledKey) ?? false,
        rightSide: p.getBool(_rightKey) ?? true,
        y: (p.getDouble(_yKey) ?? 0.55).clamp(0.0, 1.0),
        shortcuts: ThumbDockSettings.normalise(
          p.getStringList(_shortcutsKey) ?? ThumbDockSettings.defaultShortcuts,
        ),
        glass: p.getBool(_glassKey) ?? true,
      );
    } catch (_) {
      // Unreadable storage leaves the defaults, which is the dock switched off.
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_enabledKey, state.enabled);
      await p.setBool(_rightKey, state.rightSide);
      await p.setDouble(_yKey, state.y);
      await p.setStringList(_shortcutsKey, state.shortcuts);
      await p.setBool(_glassKey, state.glass);
    } catch (_) {
      // The choice still holds for this session.
    }
  }

  void _set(ThumbDockSettings next) {
    _changed = true;
    state = next;
    _save();
  }

  void setEnabled(bool value) => _set(state.copyWith(enabled: value));

  void setGlass(bool value) => _set(state.copyWith(glass: value));

  void setPosition({required bool rightSide, required double y}) =>
      _set(state.copyWith(rightSide: rightSide, y: y.clamp(0.0, 1.0)));

  /// Adds the shortcut if it is missing, removes it if it is there. The locked
  /// ones (Attendance, Marks) never leave, and a full row refuses a new one.
  void toggleShortcut(String id) {
    if (ThumbDockSettings.lockedShortcuts.contains(id)) return;
    final current = [...state.shortcuts];
    if (current.remove(id)) {
      _set(state.copyWith(shortcuts: ThumbDockSettings.normalise(current)));
    } else if (current.length < maxShortcuts) {
      _set(
        state.copyWith(
          shortcuts: ThumbDockSettings.normalise([...current, id]),
        ),
      );
    }
  }
}
