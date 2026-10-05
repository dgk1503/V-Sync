import 'package:objectbox/objectbox.dart';

/// A scraper payload kept on disk so a screen can paint something real on the
/// first frame instead of a spinner, then refresh from VTOP behind it.
///
/// The payload is stored **verbatim as the scraper's own JSON** rather than as
/// flattened columns. A calendar day has a variable number of events and a
/// day-wise attendance record has variable fields, so flattening either into
/// columns means a schema migration every time VTOP changes shape. Keeping the
/// raw text means a parser fix needs no migration at all.
@Entity()
class DataCache {
  @Id()
  int? id;

  /// What the payload belongs to, e.g. `calendar` or
  /// `attendance-detail:12345:Lecture`. Unique so a write replaces the row
  /// instead of accumulating one per refresh.
  @Unique()
  String cacheKey;

  /// The scraper's JSON, untouched.
  String payload;

  /// When [payload] was written, in epoch milliseconds.
  int updatedAt;

  DataCache({
    this.id,
    required this.cacheKey,
    required this.payload,
    required this.updatedAt,
  });
}
