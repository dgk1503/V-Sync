import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vit_ap_student_app/core/models/data_cache.dart';
import 'package:vit_ap_student_app/init_dependencies.dart';
import 'package:vit_ap_student_app/objectbox.g.dart';

part 'data_cache_service.g.dart';

/// A cached payload together with when it was written.
class CacheEntry {
  const CacheEntry({required this.payload, required this.updatedAt});

  final String payload;
  final int updatedAt;

  /// How long ago this was written.
  Duration get age =>
      Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - updatedAt);

  bool isOlderThan(Duration limit) => age > limit;
}

/// Reads and writes [DataCache] rows.
///
/// Deliberately synchronous: ObjectBox is an embedded store, so a cache read is
/// a memory/disk hit rather than network. That is what lets a screen render its
/// cached copy on the very first frame instead of showing a loader for the
/// length of a VTOP round-trip.
@riverpod
DataCacheService dataCacheService(Ref ref) =>
    DataCacheService(serviceLocator<Store>());

class DataCacheService {
  DataCacheService(this.store);

  final Store store;

  Box<DataCache> get _box => store.box<DataCache>();

  /// The cached row for [key], or null when nothing has been stored yet.
  CacheEntry? readEntry(String key) {
    final row = _box
        .query(DataCache_.cacheKey.equals(key))
        .build()
        .findFirst();
    if (row == null) return null;
    return CacheEntry(payload: row.payload, updatedAt: row.updatedAt);
  }

  /// The cached payload for [key], or null when nothing has been stored yet.
  String? read(String key) => readEntry(key)?.payload;

  /// Replaces whatever is stored under [key] with [payload].
  void write(String key, String payload) {
    final existing = _box
        .query(DataCache_.cacheKey.equals(key))
        .build()
        .findFirst();
    _box.put(
      DataCache(
        id: existing?.id,
        cacheKey: key,
        payload: payload,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void remove(String key) {
    final id = _box
        .query(DataCache_.cacheKey.equals(key))
        .build()
        .findFirst()
        ?.id;
    if (id != null) _box.remove(id);
  }

  /// Wipes every cached payload. Called on logout so one account never sees
  /// another's calendar.
  void clear() => _box.removeAll();
}
