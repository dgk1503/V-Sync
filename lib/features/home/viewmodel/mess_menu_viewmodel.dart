import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:vit_ap_student_app/features/home/services/mess_menu_service.dart';

/// What importing a file ended up as.
enum MessImportResult {
  /// Read into a structured menu the app can browse by day and meal.
  menu,

  /// Could not be read as a menu, so the original spreadsheet is shown.
  document,

  /// The file could not even be saved.
  failed,
}

final messMenuProvider = NotifierProvider<MessMenuNotifier, MessMenu?>(
  MessMenuNotifier.new,
);

/// The original file behind the menu, when there is one.
final messSourceProvider = NotifierProvider<MessSourceNotifier, MessSource?>(
  MessSourceNotifier.new,
);

class MessSourceNotifier extends Notifier<MessSource?> {
  @override
  MessSource? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    state = await MessMenuService().loadSource();
  }

  void set(MessSource? source) => state = source;
}

class MessMenuNotifier extends Notifier<MessMenu?> {
  final _service = MessMenuService();

  @override
  MessMenu? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final menu = await _service.load();
    state = menu;
  }

  /// Imports a menu spreadsheet.
  ///
  /// An `.xlsx` is read into a structured menu when it reads as one. One whose
  /// layout the reader does not understand is kept as it is and shown as the
  /// spreadsheet it came as: hostels send their menus in different layouts, and
  /// a menu that cannot be read should still be visible.
  Future<MessImportResult> importFile(Uint8List bytes, String name) async {
    try {
      try {
        final menu = await compute(MessMenuService.parseXlsx, bytes);
        if (menu.isReadable) {
          await _service.save(menu);
          final source = await _service.saveSource(bytes, name, readable: true);
          state = menu;
          ref.read(messSourceProvider.notifier).set(source);
          return MessImportResult.menu;
        }
      } catch (e) {
        debugPrint('Mess menu not readable as a menu: $e');
      }

      // The original is all there is to show, and it replaces any older menu.
      final source = await _service.saveSource(bytes, name, readable: false);
      await _service.clear();
      state = null;
      ref.read(messSourceProvider.notifier).set(source);
      return MessImportResult.document;
    } catch (e) {
      debugPrint('Failed to import mess menu: $e');
      return MessImportResult.failed;
    }
  }

  Future<void> delete() async {
    await _service.clear();
    await _service.clearSource();
    state = null;
    ref.read(messSourceProvider.notifier).set(null);
  }
}

/// Which of the workbook's menus the student is on ("Veg & Non-Veg", "Special"),
/// remembered between launches. Null means the first.
final messSheetProvider = NotifierProvider<MessSheetNotifier, String?>(
  MessSheetNotifier.new,
);

class MessSheetNotifier extends Notifier<String?> {
  static const _key = 'mess_menu_sheet_v1';

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_key);
    } catch (e) {
      debugPrint('Failed to load the chosen mess sheet: $e');
    }
  }

  Future<void> choose(String sheet) async {
    state = sheet;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, sheet);
    } catch (e) {
      debugPrint('Failed to save the chosen mess sheet: $e');
    }
  }
}
