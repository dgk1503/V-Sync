/// Faculty names scraped from VTOP carry an honorific prefix — "Dr. John
/// Doe", "Prof. A B", "MS. Jane Doe". Only the name itself should be shown,
/// so the prefix (and any punctuation it leaves behind) is stripped.
///
/// Purely presentational: the raw scraped value is untouched, this only
/// shapes what the UI prints.
library;

/// Honorifics VTOP uses, lower-cased, with the period optional.
const _titles = <String>{
  'dr',
  'prof',
  'mr',
  'mrs',
  'ms',
  'miss',
  'er',
  'smt',
  'engr',
  'eng',
};

/// Returns [raw] without any leading honorific ("Dr. John Doe" -> "John Doe").
///
/// Strips repeatedly, so stacked forms like "Dr. Prof. John Doe" and
/// bracketed ones like "(Dr.) John Doe" also come out clean. Returns an
/// empty string when the whole value was a title, so callers never render
/// stray punctuation.
String stripFacultyTitle(String raw) {
  var name = raw.trim();

  // Drop leading honorifics, one at a time, until none match.
  var matched = true;
  while (matched) {
    matched = false;
    final lower = name.toLowerCase();
    for (final title in _titles) {
      // "dr john" and "dr. john" both start with the title as a whole word.
      if (lower.length <= title.length) {
        if (lower.replaceAll('.', '') == title) {
          return '';
        }
        continue;
      }
      final prefix = lower.substring(0, title.length);
      final rest = lower.substring(title.length);
      if (prefix.replaceAll('.', '') == title &&
          (rest.startsWith(' ') || rest.startsWith('.'))) {
        name = name.substring(title.length).trim();
        matched = true;
        break;
      }
    }
  }

  // Whatever punctuation survived the prefixes: "(Dr.) - John", "Dr.. John".
  return name.replaceFirst(RegExp(r'^[\s\.\,\)\-–—:]+'), '').trim();
}
