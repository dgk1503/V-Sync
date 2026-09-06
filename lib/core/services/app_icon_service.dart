import 'package:flutter/services.dart';

/// Launcher icon variants the user can pick in Customization.
///
/// The active variant lives in the Android PackageManager (activity-alias
/// enable states — see MainActivity.kt), so nothing is persisted on the
/// Dart side: [AppIconService.getCurrent] reads the truth from the platform
/// and falls back to the default icon on any error (e.g. non-Android
/// platform or a missing channel).
class AppIconVariant {
  const AppIconVariant._(this.id, this.label, this.previewAsset);

  final String id;
  final String label;

  /// Flutter asset used for the preview in the Customization page.
  final String previewAsset;

  static const AppIconVariant defaultIcon = AppIconVariant._(
    'default',
    'Default',
    // Transparent white-V foreground at the same glyph ratio (0.55) as the
    // other variants, so all preview tiles render at a consistent size.
    // (app_icon_legacy.png is a full-bleed rendered icon and looked
    // oversized next to the others.)
    'assets/images/logo/vsync_foreground_default.png',
  );
  static const AppIconVariant classy = AppIconVariant._(
    'classy',
    'Classy',
    'assets/images/logo/vsync_foreground_classy.png',
  );
  static const AppIconVariant glassy = AppIconVariant._(
    'glassy',
    'Glassy',
    'assets/images/logo/vsync_foreground_glassy.png',
  );
  static const AppIconVariant rainbow = AppIconVariant._(
    'rainbow',
    'Rainbow',
    'assets/images/logo/vsync_foreground_rainbow.png',
  );

  static const List<AppIconVariant> all = [
    defaultIcon,
    classy,
    glassy,
    rainbow,
  ];

  static AppIconVariant fromId(String? id) =>
      all.firstWhere((v) => v.id == id, orElse: () => defaultIcon);
}

class AppIconService {
  AppIconService._();

  static const MethodChannel _channel = MethodChannel('vsync/launcher_icon');

  /// Reads the currently enabled launcher icon from the platform.
  static Future<AppIconVariant> getCurrent() async {
    try {
      final id = await _channel.invokeMethod<String>('getIcon');
      return AppIconVariant.fromId(id);
    } catch (_) {
      // Unsupported platform or channel error: assume the default icon.
      return AppIconVariant.defaultIcon;
    }
  }

  /// Switches the launcher icon. The home screen may take a few seconds to
  /// refresh; some launchers (notably MIUI) can lag behind until reboot.
  static Future<void> setIcon(AppIconVariant variant) async {
    await _channel.invokeMethod<void>('setIcon', {'name': variant.id});
  }
}
