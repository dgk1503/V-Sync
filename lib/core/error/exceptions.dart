import 'package:flutter/foundation.dart';
import 'package:vit_ap_student_app/core/utils/internet_probe.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/vtop_errors.dart';

class ServerException implements Exception {
  final String message;
  const ServerException(this.message);

  @override
  String toString() => 'ServerException: $message';
}

class SecureStorageException implements Exception {
  final String message;
  SecureStorageException(this.message);

  @override
  String toString() => 'SecureStorageException: $message';
}

/// Wrapper class to provide consistent error handling for VTOP errors
/// This converts VtopError (from Rust) into a standard Dart Exception
class VtopException implements Exception {
  final VtopError _error;
  String? _cachedMessage;
  String? _cachedErrorType;

  VtopException(this._error);

  /// Get user-friendly error message (cached after first call)
  Future<String> get message async {
    _cachedMessage ??= await _error.message();
    return _cachedMessage!;
  }

  /// Get error type for programmatic handling (cached after first call)
  Future<String> get errorType async {
    _cachedErrorType ??= await _error.errorType();
    return _cachedErrorType!;
  }

  /// Get debug message for logging (not cached)
  Future<String> get debugMessage async {
    return await _error.debugMessage();
  }

  /// Access the original VtopError for pattern matching
  VtopError get originalError => _error;

  /// Synchronous toString for logging (uses cached message if available)
  @override
  String toString() {
    if (_cachedMessage != null) {
      return 'VtopException: $_cachedMessage';
    }
    return 'VtopException: ${_error.runtimeType}';
  }

  /// Convenience method to create VtopException from VtopError
  static VtopException from(VtopError error) => VtopException(error);

  /// Decides whether the phone has internet when a connection failure needs
  /// explaining. A field so tests can answer without a network.
  @visibleForTesting
  static InternetProbe internetProbe = probeInternet;

  /// Errors that look the same whether the phone is offline or VTOP is down.
  static const _ambiguousConnectionErrors = {
    'NetworkError',
    'TimeoutError',
    'DnsError',
    'ConnectionRefused',
  };

  /// Static method to handle VtopError and convert to appropriate Failure message
  static Future<String> getFailureMessage(VtopError error) async {
    final vtopException = VtopException.from(error);
    final errorType = await vtopException.errorType;

    // Log for debugging purposes (not shown to user)
    final debugMessage = await vtopException.debugMessage;
    debugPrint('VTOP Error [$errorType]: $debugMessage');

    // Only a connection failure needs the extra question: is it the phone, or
    // is it VTOP? Everything else already says what happened.
    final online = _ambiguousConnectionErrors.contains(errorType)
        ? await internetProbe()
        : true;

    return failureMessageFor(errorType, debugMessage, online: online);
  }

  /// Check if this error indicates session expiry or authentication issues
  static Future<bool> isSessionRelatedError(VtopError error) async {
    final vtopException = VtopException.from(error);
    final errorType = await vtopException.errorType;

    return errorType == 'SessionExpired' ||
        errorType == 'AuthenticationFailed' ||
        errorType == 'InvalidCredentials';
  }

  /// Check if this error should trigger a retry with a fresh session
  static Future<bool> isRetryableError(VtopError error) async {
    final vtopException = VtopException.from(error);
    final errorType = await vtopException.errorType;

    // These errors can be resolved by creating a fresh session or retrying
    return errorType == 'SessionExpired' ||
        errorType == 'AuthenticationFailed' ||
        errorType == 'InvalidCredentials' ||
        errorType ==
            'VtopServerError' || // Sometimes server errors are transient
        errorType == 'TimeoutError' || // Timeouts may succeed on retry
        errorType ==
            'ResponseReadError'; // Response read errors may be transient
  }

  /// Check if this is a network-related error that might resolve itself
  static Future<bool> isNetworkRelatedError(VtopError error) async {
    final vtopException = VtopException.from(error);
    final errorType = await vtopException.errorType;

    return errorType == 'NetworkError' ||
        errorType == 'TimeoutError' ||
        errorType == 'SslError' ||
        errorType == 'DnsError' ||
        errorType == 'ConnectionRefused' ||
        errorType == 'ResponseReadError';
  }

  /// The message shown to the student for a failure of [errorType].
  ///
  /// [online] says whether the phone itself can reach the internet. It decides
  /// the one distinction a student cares about when a connection fails: "your
  /// connection is the problem" versus "VTOP is the problem".
  @visibleForTesting
  static String failureMessageFor(
    String errorType,
    String message, {
    bool online = true,
  }) {
    if (message.contains('Number Of Maximum Fail Attempts Reached')) {
      return message;
    }
    switch (errorType) {
      case 'NetworkError':
      case 'DnsError':
        return online
            ? "VTOP isn't reachable right now. Your internet is working, so "
                  "VIT-AP's servers are most likely down or busy. Try again in "
                  'a few minutes.'
            : 'No internet connection. Check your Wi-Fi or mobile data and '
                  'try again.';

      case 'TimeoutError':
        return online
            ? 'VTOP is responding very slowly right now. Your internet is '
                  "fine, so it's most likely overloaded. Try again in a few "
                  'minutes.'
            : 'Your connection is too slow or unstable to reach VTOP. Check '
                  'your Wi-Fi or mobile data and try again.';

      case 'ConnectionRefused':
        return online
            ? 'VTOP is refusing connections, which usually means it is down '
                  'for maintenance. Your internet is fine. Try again later.'
            : 'No internet connection. Check your Wi-Fi or mobile data and '
                  'try again.';

      case 'VtopServerError':
        return 'VTOP is having problems on its side and returned an error. '
            'Nothing is wrong with your account or your phone. Try again in a '
            'few minutes.';

      case 'MenuUnavailable':
        return 'VTOP is not serving this page right now. It may be switched '
            'off or under maintenance. Your saved data is still here. Try '
            'again later.';

      case 'SslError':
        return "Secure connection to VTOP failed. This is usually a problem "
            "with VTOP's certificate or a network that is intercepting the "
            'connection. Try another network, or try again later.';

      case 'ResponseReadError':
        return 'The connection dropped while VTOP was replying. Please try '
            'again.';

      case 'AuthenticationFailed':
      case 'InvalidCredentials':
        return 'Invalid username or password. Please check your credentials and try again.';

      case 'SessionExpired':
        return 'Your session has expired. The app will automatically retry with a fresh session.';

      case 'CaptchaRequired':
        return 'Captcha verification is required. Please complete the captcha and try again.';

      case 'RegistrationParsingError':
        return 'Invalid registration number format. Please check your registration number.';

      case 'ParseError':
      case 'InvalidResponse':
        return 'VTOP sent a page the app could not read. This can happen when '
            'VTOP changes its layout or sends an error page. Your saved data '
            'is unchanged. Please try again later.';

      case 'InvalidSemesterId':
        return 'That semester could not be recognised. Please pick one from the '
            'semester list.';

      case 'ConfigurationError':
        return 'App configuration error. Please restart the app and try again.';

      case 'LoginOtpRequired':
        return 'OTP verification is required for login.';

      case 'LoginOtpIncorrect':
        return 'Incorrect OTP entered for login. Please try again.';

      case 'LoginOtpExpired':
        return 'OTP for login has expired. Please request a new OTP and try again.';

      default:
        // For any unknown error types, return the user-friendly message from Rust
        return message;
    }
  }

  /// Check if this is a specific error type without async
  bool isErrorType(String type) {
    return _cachedErrorType == type;
  }

  /// Quick checks for common error types (requires errorType to be cached)
  bool get isNetworkError => _cachedErrorType == 'NetworkError';
  bool get isTimeoutError => _cachedErrorType == 'TimeoutError';
  bool get isSslError => _cachedErrorType == 'SslError';
  bool get isDnsError => _cachedErrorType == 'DnsError';
  bool get isConnectionRefused => _cachedErrorType == 'ConnectionRefused';
  bool get isResponseReadError => _cachedErrorType == 'ResponseReadError';
  bool get isAuthenticationError => _cachedErrorType == 'AuthenticationFailed';
  bool get isSessionExpired => _cachedErrorType == 'SessionExpired';
  bool get isCaptchaRequired => _cachedErrorType == 'CaptchaRequired';
  bool get isInvalidCredentials => _cachedErrorType == 'InvalidCredentials';
  bool get isVtopServerError => _cachedErrorType == 'VtopServerError';

  /// Check if this is any kind of connectivity issue
  bool get isConnectivityIssue =>
      isNetworkError ||
      isTimeoutError ||
      isSslError ||
      isDnsError ||
      isConnectionRefused ||
      isResponseReadError;
}

/// Exception thrown when a live VTOP operation is attempted while the app is
/// running in demo mode. Demo sessions never contact VTOP; this acts as a
/// safety net so any un-gated code path fails fast with a friendly message
/// instead of trying to authenticate with placeholder demo credentials.
class DemoModeException implements Exception {
  final String message;
  const DemoModeException([
    this.message = 'This feature is not available in the demo account.',
  ]);

  @override
  String toString() => 'DemoModeException: $message';
}

/// Exception for general app errors
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'AppException($code): $message';
    }
    return 'AppException: $message';
  }
}

/// Exception for network-related errors
class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  const NetworkException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode != null) {
      return 'NetworkException($statusCode): $message';
    }
    return 'NetworkException: $message';
  }
}

/// Exception for validation errors
class ValidationException implements Exception {
  final String message;
  final Map<String, List<String>>? fieldErrors;

  const ValidationException(this.message, {this.fieldErrors});

  @override
  String toString() => 'ValidationException: $message';
}
