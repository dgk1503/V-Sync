import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vit_ap_student_app/init_dependencies.dart';

/// The Gmail address and app password the OTP reader signs in with.
class GmailOtpAccount {
  const GmailOtpAccount({required this.email, required this.appPassword});

  final String email;
  final String appPassword;
}

/// Keeps the Gmail address and app password on this phone, encrypted by the
/// system's keystore (through `flutter_secure_storage`), and nowhere else.
///
/// The password is a Google *app password* made for this one purpose, which can
/// be revoked in the Google account at any time. It is never written to a log
/// and never leaves the phone except to sign in to Gmail.
class GmailOtpStore {
  GmailOtpStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _emailKey = 'gmail_otp_email_v1';
  static const _passwordKey = 'gmail_otp_app_password_v1';
  static const _enabledKey = 'gmail_otp_enabled_v1';

  Future<GmailOtpAccount?> read() async {
    try {
      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);
      if (email == null || password == null) return null;
      if (email.isEmpty || password.isEmpty) return null;
      return GmailOtpAccount(email: email, appPassword: password);
    } catch (_) {
      // Unreadable storage (a restore onto another phone, a reset keystore) is
      // the same as nothing saved: the student connects again.
      return null;
    }
  }

  /// Saves the account and switches the reader on.
  Future<void> save(GmailOtpAccount account) async {
    await _storage.write(key: _emailKey, value: account.email);
    await _storage.write(key: _passwordKey, value: account.appPassword);
    await _storage.write(key: _enabledKey, value: 'true');
  }

  /// Forgets the account.
  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _enabledKey);
  }

  Future<bool> isEnabled() async {
    try {
      return await _storage.read(key: _enabledKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool value) =>
      _storage.write(key: _enabledKey, value: value ? 'true' : 'false');

  /// The app password as Google shows it ("abcd efgh ijkl mnop") reduced to its
  /// sixteen letters, or null when it is not one.
  static String? normalisePassword(String raw) {
    final letters = raw.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return RegExp(r'^[a-z]{16}$').hasMatch(letters) ? letters : null;
  }

  static bool isValidEmail(String raw) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(raw.trim());
}

final gmailOtpStoreProvider = Provider<GmailOtpStore>(
  (ref) => GmailOtpStore(serviceLocator<FlutterSecureStorage>()),
);

/// What the settings tile and page show.
class GmailOtpSettings {
  const GmailOtpSettings({
    this.loaded = false,
    this.email,
    this.enabled = false,
  });

  final bool loaded;

  /// Null when nothing is connected.
  final String? email;
  final bool enabled;

  bool get isConnected => email != null;
}

final gmailOtpSettingsProvider =
    NotifierProvider<GmailOtpSettingsNotifier, GmailOtpSettings>(
      GmailOtpSettingsNotifier.new,
    );

class GmailOtpSettingsNotifier extends Notifier<GmailOtpSettings> {
  @override
  GmailOtpSettings build() {
    _load();
    return const GmailOtpSettings();
  }

  Future<void> _load() async {
    final store = ref.read(gmailOtpStoreProvider);
    final account = await store.read();
    final enabled = account != null && await store.isEnabled();
    if (!ref.mounted) return;
    state = GmailOtpSettings(
      loaded: true,
      email: account?.email,
      enabled: enabled,
    );
  }

  Future<void> connect(GmailOtpAccount account) async {
    await ref.read(gmailOtpStoreProvider).save(account);
    state = GmailOtpSettings(loaded: true, email: account.email, enabled: true);
  }

  Future<void> setEnabled(bool value) async {
    if (!state.isConnected) return;
    await ref.read(gmailOtpStoreProvider).setEnabled(value);
    state = GmailOtpSettings(loaded: true, email: state.email, enabled: value);
  }

  Future<void> disconnect() async {
    await ref.read(gmailOtpStoreProvider).clear();
    state = const GmailOtpSettings(loaded: true);
  }
}
