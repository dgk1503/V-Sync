/// One day's mess menu, split by meal.
class MessDayMenu {
  final List<String> breakfast;
  final List<String> lunch;
  final List<String> snacks;
  final List<String> dinner;

  const MessDayMenu({
    this.breakfast = const [],
    this.lunch = const [],
    this.snacks = const [],
    this.dinner = const [],
  });

  List<String> forMeal(int mealIndex) {
    switch (mealIndex) {
      case 0:
        return breakfast;
      case 1:
        return lunch;
      case 2:
        return snacks;
      default:
        return dinner;
    }
  }

  Map<String, dynamic> toJson() => {
    'breakfast': breakfast,
    'lunch': lunch,
    'snacks': snacks,
    'dinner': dinner,
  };

  factory MessDayMenu.fromJson(Map<String, dynamic> json) => MessDayMenu(
    breakfast: _itemsFromJson(json['breakfast']),
    lunch: _itemsFromJson(json['lunch']),
    snacks: _itemsFromJson(json['snacks']),
    dinner: _itemsFromJson(json['dinner']),
  );

  /// Accepts both plain strings ("Pulka") and the older object format
  /// ({"n": "Pulka", ...}) left over from previous app versions.
  static List<String> _itemsFromJson(dynamic json) {
    if (json is! List) return const [];
    return json
        .map((e) {
          if (e is String) return e;
          if (e is Map && e['n'] is String) return e['n'] as String;
          return '';
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

/// One more menu in the same workbook, such as "Special".
///
/// Hostels get more than one mess menu in a month's spreadsheet, one sheet each.
/// They share the month and the layout, so only the days differ.
class MessSheet {
  final String name;

  /// Menu per day of month (1-based).
  final Map<int, MessDayMenu> days;

  const MessSheet({required this.name, required this.days});

  Map<String, dynamic> toJson() => {
    'name': name,
    'days': days.map((key, value) => MapEntry(key.toString(), value.toJson())),
  };

  factory MessSheet.fromJson(Map<String, dynamic> json) => MessSheet(
    name: json['name'] as String,
    days: (json['days'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        int.parse(key),
        MessDayMenu.fromJson(value as Map<String, dynamic>),
      ),
    ),
  );
}

/// A full month of mess menus parsed from the monthly Excel sheet.
class MessMenu {
  final String monthName;
  final int month; // 1-12
  final int year;

  /// Menu per day of month (1-based), for the workbook's first menu sheet.
  final Map<int, MessDayMenu> days;

  /// The name of that first sheet, e.g. "Veg & Non-Veg". Empty for a menu saved
  /// before sheets were kept.
  final String sheetName;

  /// The workbook's other menu sheets, e.g. "Special".
  final List<MessSheet> extraSheets;

  const MessMenu({
    required this.monthName,
    required this.month,
    required this.year,
    required this.days,
    this.sheetName = '',
    this.extraSheets = const [],
  });

  /// A copy carrying the sheet names and the other sheets.
  MessMenu withSheets({
    required String sheetName,
    required List<MessSheet> extraSheets,
  }) => MessMenu(
    monthName: monthName,
    month: month,
    year: year,
    days: days,
    sheetName: sheetName,
    extraSheets: extraSheets,
  );

  /// The names of every menu in the workbook, the first one first.
  List<String> get sheetNames => [
    sheetName.isEmpty ? 'Menu' : sheetName,
    for (final sheet in extraSheets) sheet.name,
  ];

  /// The days of the sheet called [sheet], or of the first when there is no such
  /// sheet. A name saved from another month's workbook never breaks the screen.
  Map<int, MessDayMenu> daysFor(String? sheet) {
    for (final extra in extraSheets) {
      if (extra.name == sheet) return extra.days;
    }
    return days;
  }

  MessDayMenu? menuFor(int day, {String? sheet}) => daysFor(sheet)[day];

  int? get firstDay =>
      days.keys.isEmpty ? null : (days.keys.toList()..sort()).first;

  int? get lastDay =>
      days.keys.isEmpty ? null : (days.keys.toList()..sort()).last;

  Map<String, dynamic> toJson() => {
    'monthName': monthName,
    'month': month,
    'year': year,
    'days': days.map((key, value) => MapEntry(key.toString(), value.toJson())),
    if (sheetName.isNotEmpty) 'sheetName': sheetName,
    if (extraSheets.isNotEmpty)
      'extraSheets': [for (final sheet in extraSheets) sheet.toJson()],
  };

  factory MessMenu.fromJson(Map<String, dynamic> json) => MessMenu(
    monthName: json['monthName'] as String,
    month: json['month'] as int,
    year: json['year'] as int,
    days: (json['days'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        int.parse(key),
        MessDayMenu.fromJson(value as Map<String, dynamic>),
      ),
    ),
    // Absent in a menu saved before sheets were kept.
    sheetName: json['sheetName'] as String? ?? '',
    extraSheets: [
      for (final sheet in (json['extraSheets'] as List<dynamic>? ?? const []))
        MessSheet.fromJson(sheet as Map<String, dynamic>),
    ],
  );
}

/// The file a mess menu came from, kept on the device.
///
/// Hostels send their menus in different layouts, and the reader only
/// understands some of them. Keeping the original spreadsheet means a menu the
/// app cannot read is still one the student can see, instead of an error and
/// nothing.
class MessSource {
  const MessSource({
    required this.path,
    required this.name,
    required this.importedAt,
    required this.readable,
  });

  /// Where the copy lives inside the app's own storage.
  final String path;

  /// The file's name as the student knew it, e.g. `Mess Menu November.xlsx`.
  final String name;

  final DateTime importedAt;

  /// Whether the app read this file into a structured menu. False means the
  /// original is all there is to show.
  final bool readable;

  /// Whether the file was added in a month before [now]'s. A document has no
  /// month the app can read out of it, so this is the best sign it is stale.
  bool isFromEarlierMonth(DateTime now) =>
      importedAt.year < now.year ||
      (importedAt.year == now.year && importedAt.month < now.month);

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'importedAt': importedAt.toIso8601String(),
    'readable': readable,
  };

  factory MessSource.fromJson(Map<String, dynamic> json) => MessSource(
    path: json['path'] as String,
    name: json['name'] as String,
    importedAt: DateTime.parse(json['importedAt'] as String),
    readable: json['readable'] as bool? ?? false,
  );
}

/// Whether a parsed menu can be trusted, and whether its month is over.
extension MessMenuHealth on MessMenu {
  /// A parsed menu is only worth showing when it looks like a real month.
  ///
  /// The reader will accept almost any grid that has a "Breakfast" column, so a
  /// layout it half understands can come back as a handful of days or a menu
  /// with most meals empty. Showing that as the menu is worse than showing the
  /// original file, because it looks authoritative and is not. A real monthly
  /// menu lists breakfast, lunch and dinner for nearly every day.
  bool get isReadable {
    if (days.length < 10) return false;
    final complete = days.values.where((day) {
      final filled = [
        day.breakfast,
        day.lunch,
        day.dinner,
      ].where((meal) => meal.isNotEmpty).length;
      return filled >= 3;
    }).length;
    return complete / days.length >= 0.7;
  }

  /// Whether the month this menu is for has finished by [now].
  bool hasEnded(DateTime now) =>
      now.year > year || (now.year == year && now.month > month);
}
