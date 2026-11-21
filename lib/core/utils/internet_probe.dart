import 'dart:async';
import 'dart:io';

/// Answers "does this phone have working internet right now?".
///
/// It exists to tell two failures apart that look identical from inside the
/// app: the phone being offline, and VTOP being down. Both surface as a failed
/// connection to VTOP, and telling a student "no internet connection" while
/// their internet is fine, and VTOP is what is broken, sends them off
/// troubleshooting the wrong thing.
///
/// The probe asks a neutral Google endpoint that exists for exactly this and
/// answers an empty 204. Nothing about the user or the app is sent.
typedef InternetProbe = Future<bool> Function();

/// The real probe. Any answer at all means the network works; only a failure to
/// connect, or silence, means it does not.
Future<bool> probeInternet() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client
        .getUrl(Uri.parse('https://www.gstatic.com/generate_204'))
        .timeout(const Duration(seconds: 4));
    final response = await request.close().timeout(const Duration(seconds: 4));
    await response.drain<void>();
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
