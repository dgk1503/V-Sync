/// What VTOP's login email looks like, and how to read the code out of it.
///
/// The mail comes from `noreply.sdc@vitap.ac.in`, subject "VTOP Login ...", as
/// an HTML page ("Your one-time password", the six digits in a box, "Expires in
/// 3 minutes"). The code is the one standalone six-digit number in it; the page
/// spaces the digits apart for the eye, which may be real spaces in the text, so
/// those are read too.
abstract final class VtopOtpEmail {
  /// The only sender whose mail is ever read.
  static const sender = 'noreply.sdc@vitap.ac.in';

  /// Whether [address] is VTOP's sender, however it is capitalised.
  static bool isFromVtop(String? address) =>
      (address ?? '').trim().toLowerCase() == sender;

  /// The code in [body] (HTML or plain text), or null when there is none.
  static String? extractCode(String body) {
    final text = toText(body);

    // The ordinary case: six digits standing alone. Longer runs of digits (a
    // reference or phone number) are not a code.
    final plain = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(text);
    if (plain != null) return plain.group(0);

    // The digits spaced out one by one: "4 8 8 2 4 5".
    final spaced = RegExp(
      r'(?<!\d)(\d)(?:[ \t ]+(\d)){5}(?!\d)',
    ).firstMatch(text);
    if (spaced != null) {
      return spaced.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
    }
    return null;
  }

  /// [html] as the text a person would read: no tags, styles, scripts or
  /// comments, and the common entities decoded.
  static String toText(String html) {
    var text = html;
    text = text.replaceAll(
      RegExp(
        r'<(style|script)\b[^>]*>.*?</\1\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      ' ',
    );
    text = text.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return text;
  }
}
