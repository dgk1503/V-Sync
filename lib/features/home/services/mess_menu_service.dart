import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:xml/xml.dart';

/// Parses the monthly VIT-AP mess menu Excel sheet and persists it locally.
///
/// The .xlsx format is a ZIP of XML files; this reader walks
/// `xl/workbook.xml`, `xl/sharedStrings.xml` and the worksheet XML directly
/// so no extra dependencies are needed.
class MessMenuService {
  static const _storageKey = 'mess_menu_v1';

  // ---------------------------------------------------------------- storage

  Future<MessMenu?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;
      return MessMenu.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to load mess menu: $e');
      return null;
    }
  }

  Future<void> save(MessMenu menu) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(menu.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ----------------------------------------------------------- original file

  static const _sourceKey = 'mess_menu_source_v1';

  /// The file the current menu came from, or null when there is none or it has
  /// gone missing from storage.
  Future<MessSource?> loadSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sourceKey);
      if (raw == null || raw.isEmpty) return null;
      final source = MessSource.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return await File(source.path).exists() ? source : null;
    } catch (e) {
      debugPrint('Failed to load mess menu source: $e');
      return null;
    }
  }

  /// Keeps a copy of the imported file in the app's own storage.
  Future<MessSource> saveSource(
    Uint8List bytes,
    String name, {
    required bool readable,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final dot = name.lastIndexOf('.');
    final extension = dot == -1 ? 'bin' : name.substring(dot + 1).toLowerCase();
    final file = File('${dir.path}/mess_menu_source.$extension');
    await file.writeAsBytes(bytes, flush: true);

    final source = MessSource(
      path: file.path,
      name: name,
      importedAt: DateTime.now(),
      readable: readable,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceKey, jsonEncode(source.toJson()));
    return source;
  }

  Future<void> clearSource() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sourceKey);
    if (raw != null) {
      try {
        final source = MessSource.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        final file = File(source.path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await prefs.remove(_sourceKey);
  }

  /// The year a menu for [month] belongs to, given today's date.
  ///
  /// The sheets name a month but not a year, so the year is inferred as the one
  /// that puts that month closest to now. A January sheet read in December is
  /// next year's; an October sheet read in November is this year's, and over. It
  /// used to assume any earlier month meant next year, which made a late upload
  /// of last month's menu look like it belonged to the future and never
  /// expired.
  static int yearFor(int month, DateTime now) {
    if (month - now.month > 6) return now.year - 1;
    if (now.month - month > 6) return now.year + 1;
    return now.year;
  }

  // ----------------------------------------------------------------- parse

  /// Parses the raw bytes of an .xlsx file into a [MessMenu].
  static MessMenu parseXlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? findFile(String name) {
      for (final file in archive) {
        if (file.name.endsWith(name)) return file;
      }
      return null;
    }

    // Shared strings
    final sharedStrings = <String>[];
    final sharedStringsFile = findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      final doc = XmlDocument.parse(utf8.decode(sharedStringsFile.content));
      for (final si in doc.findAllElements('si', namespaceUri: '*')) {
        // Concatenate all text runs inside the shared string.
        final text = si.descendantElements
            .where((e) => e.name.local == 't')
            .map((e) => e.innerText)
            .join();
        sharedStrings.add(text);
      }
    }

    // Month hint: scan every XML part of the workbook for the explicit
    // "MONTH OF <name>" phrase (the title row of the monthly sheets).
    var monthHint = -1;
    final monthOfRegex = RegExp(
      'month of\\s*[:\\- ]*([a-z]+)',
      caseSensitive: false,
    );
    for (final file in archive) {
      if (!file.name.endsWith('.xml')) continue;
      final match = monthOfRegex.firstMatch(
        utf8.decode(file.content).toLowerCase(),
      );
      if (match != null) {
        final idx = _monthIndexFromName(match.group(1)!);
        if (idx != -1) {
          monthHint = idx;
          break;
        }
      }
    }

    // Workbook: sheet name -> r:id
    final workbookFile = findFile('xl/workbook.xml');
    if (workbookFile == null) {
      throw const FormatException('Not a valid Excel workbook');
    }
    final workbook = XmlDocument.parse(utf8.decode(workbookFile.content));
    final sheetEntries = <({String name, String rid})>[];
    for (final sheet in workbook.findAllElements('sheet', namespaceUri: '*')) {
      final name = sheet.getAttribute('name', namespaceUri: '*') ?? '';
      String? rid;
      for (final attr in sheet.attributes) {
        if (attr.name.local == 'id') rid = attr.value;
      }
      if (rid != null) sheetEntries.add((name: name, rid: rid));
    }

    // Relationships: r:id -> target path
    final relsFile = findFile('xl/_rels/workbook.xml.rels');
    if (relsFile == null) {
      throw const FormatException('Workbook relationships missing');
    }
    final rels = XmlDocument.parse(utf8.decode(relsFile.content));
    final ridToTarget = <String, String>{};
    for (final rel in rels.findAllElements('Relationship', namespaceUri: '*')) {
      final id = rel.getAttribute('Id', namespaceUri: '*');
      final target = rel.getAttribute('Target', namespaceUri: '*');
      if (id != null && target != null) {
        ridToTarget[id] = target.startsWith('/xl/')
            ? target.substring(1)
            : 'xl/${target.replaceFirst(RegExp(r'^xl/'), '')}';
      }
    }

    // Pick the sheet: prefer the regular "Veg & Non-Veg" menu, fall back to
    // the first sheet that parses.
    sheetEntries.sort((a, b) {
      const preferred = 'veg & non-veg';
      final aPreferred = a.name.toLowerCase().contains(preferred) ? 0 : 1;
      final bPreferred = b.name.toLowerCase().contains(preferred) ? 0 : 1;
      return aPreferred.compareTo(bPreferred);
    });

    // Every sheet that reads as a menu is kept, not just the first: a month's
    // workbook carries one sheet per mess menu ("Veg & Non-Veg", "Special"), and
    // a student is on one of them. The first stays the main menu.
    Object? lastError;
    final found = <({String name, MessMenu menu})>[];
    for (final entry in sheetEntries) {
      final target = ridToTarget[entry.rid];
      if (target == null) continue;
      final sheetFile = findFile(target);
      if (sheetFile == null) continue;
      try {
        final sheet = _readSheet(utf8.decode(sheetFile.content), sharedStrings);
        final menu = _menuFromGrid(sheet.grid, sheet.dayBlockRanges, monthHint);
        if (menu != null) found.add((name: entry.name.trim(), menu: menu));
      } catch (e) {
        lastError = e;
      }
    }
    if (found.isEmpty) {
      throw FormatException(
        'Could not find a mess menu table in this file. $lastError',
      );
    }
    return found.first.menu.withSheets(
      sheetName: found.first.name,
      extraSheets: [
        for (final other in found.skip(1))
          MessSheet(name: other.name, days: other.menu.days),
      ],
    );
  }

  /// Reads the first worksheet that has any text into a plain grid of strings.
  ///
  /// This is for showing a spreadsheet the menu reader does not understand, as
  /// the table it came as. Empty rows and trailing empty columns are dropped.
  static List<List<String>> rawGrid(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? findFile(String name) {
      for (final file in archive) {
        if (file.name.endsWith(name)) return file;
      }
      return null;
    }

    final sharedStrings = <String>[];
    final sharedStringsFile = findFile('xl/sharedStrings.xml');
    if (sharedStringsFile != null) {
      final doc = XmlDocument.parse(utf8.decode(sharedStringsFile.content));
      for (final si in doc.findAllElements('si', namespaceUri: '*')) {
        sharedStrings.add(
          si.descendantElements
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join(),
        );
      }
    }

    final workbookFile = findFile('xl/workbook.xml');
    final relsFile = findFile('xl/_rels/workbook.xml.rels');
    if (workbookFile == null || relsFile == null) {
      throw const FormatException('Not a valid Excel workbook');
    }

    final ridToTarget = <String, String>{};
    final rels = XmlDocument.parse(utf8.decode(relsFile.content));
    for (final rel in rels.findAllElements('Relationship', namespaceUri: '*')) {
      final id = rel.getAttribute('Id', namespaceUri: '*');
      final target = rel.getAttribute('Target', namespaceUri: '*');
      if (id != null && target != null) {
        ridToTarget[id] = target.startsWith('/xl/')
            ? target.substring(1)
            : 'xl/${target.replaceFirst(RegExp(r'^xl/'), '')}';
      }
    }

    final workbook = XmlDocument.parse(utf8.decode(workbookFile.content));
    for (final sheet in workbook.findAllElements('sheet', namespaceUri: '*')) {
      String? rid;
      for (final attr in sheet.attributes) {
        if (attr.name.local == 'id') rid = attr.value;
      }
      final target = rid == null ? null : ridToTarget[rid];
      final sheetFile = target == null ? null : findFile(target);
      if (sheetFile == null) continue;

      final grid = _readSheet(
        utf8.decode(sheetFile.content),
        sharedStrings,
      ).grid.where((row) => row.any((cell) => cell.isNotEmpty)).toList();
      if (grid.isEmpty) continue;

      var width = 0;
      for (final row in grid) {
        for (var c = row.length - 1; c >= 0; c--) {
          if (row[c].isNotEmpty) {
            if (c + 1 > width) width = c + 1;
            break;
          }
        }
      }
      return [
        for (final row in grid)
          [for (var c = 0; c < width; c++) c < row.length ? row[c] : ''],
      ];
    }
    return const [];
  }

  static const _weekdayWords = {
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };

  /// The weekday a block's label starts with ("Tue\n10, 24"), or null.
  static int? weekdayOfLabel(String label) {
    final match = RegExp(
      r'\b(mon|tue|wed|thu|fri|sat|sun)',
      caseSensitive: false,
    ).firstMatch(label);
    return match == null ? null : _weekdayWords[match.group(1)!.toLowerCase()];
  }

  /// The year that makes a menu's weekday labels agree with the calendar.
  ///
  /// The sheet names a month but never a year, and a block says "Tue 3, 17".
  /// Counting how many listed dates fall on the weekday their block names, for
  /// each candidate year, picks the year the sheet was written for. It matters
  /// because the next step trusts the calendar over the sheet.
  static int bestYear(
    int month,
    List<({int? weekday, List<int> numbers})> blocks,
    int preferred,
  ) {
    var best = preferred;
    var bestScore = -1;
    for (final year in [preferred, preferred - 1, preferred + 1]) {
      final length = DateTime(year, month + 1, 0).day;
      var score = 0;
      for (final block in blocks) {
        if (block.weekday == null) continue;
        for (final n in block.numbers) {
          if (n >= 1 &&
              n <= length &&
              DateTime(year, month, n).weekday == block.weekday) {
            score++;
          }
        }
      }
      if (score > bestScore) {
        best = year;
        bestScore = score;
      }
    }
    return best;
  }

  /// A block's dates, with any that the calendar contradicts put right.
  ///
  /// The sheets are typed by hand and carry slips: a block headed "Tue" lists
  /// "10, 25", but the 25th is a Wednesday. Taking the numbers as written gave
  /// the 25th Tuesday's food and left the 24th with no menu at all. A date that
  /// is not on the block's weekday is moved to the nearest day that is, within a
  /// few days and only where that day is not already listed; otherwise it is
  /// dropped rather than guessed at.
  static List<int> repairDates({
    required int? weekday,
    required List<int> numbers,
    required int year,
    required int month,
  }) {
    final length = DateTime(year, month + 1, 0).day;
    final inMonth = numbers.where((n) => n >= 1 && n <= length).toList();
    if (weekday == null) return inMonth;

    final onWeekday = [
      for (var d = 1; d <= length; d++)
        if (DateTime(year, month, d).weekday == weekday) d,
    ];
    final kept = <int>{
      for (final n in inMonth)
        if (DateTime(year, month, n).weekday == weekday) n,
    };

    for (final n in inMonth) {
      if (kept.contains(n) || onWeekday.contains(n)) continue;
      int? nearest;
      for (final candidate in onWeekday) {
        if (kept.contains(candidate) || inMonth.contains(candidate)) continue;
        if ((candidate - n).abs() > 3) continue;
        if (nearest == null || (candidate - n).abs() < (nearest - n).abs()) {
          nearest = candidate;
        }
      }
      if (nearest != null) kept.add(nearest);
    }
    return kept.toList()..sort();
  }

  static int _monthIndexFromName(String name) {
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    final lower = name.toLowerCase();
    for (var m = 0; m < months.length; m++) {
      if (lower.startsWith(months[m].substring(0, 3))) return m + 1;
    }
    return -1;
  }

  /// Reads a worksheet into a grid of strings indexed [row][col], and
  /// collects the merged ranges of column A (the day-label column), which
  /// mark the exact row span of each day group.
  static ({List<List<String>> grid, List<(int, int)> dayBlockRanges})
  _readSheet(String xml, List<String> sharedStrings) {
    final doc = XmlDocument.parse(xml);
    final grid = <List<String>>[];

    for (final row in doc.findAllElements('row', namespaceUri: '*')) {
      final rowAttr = row.getAttribute('r', namespaceUri: '*');
      final rowIndex = (int.tryParse(rowAttr ?? '') ?? grid.length + 1) - 1;
      while (grid.length <= rowIndex) {
        grid.add(<String>[]);
      }
      final cells = grid[rowIndex];

      for (final c in row.findElements('c', namespaceUri: '*')) {
        final ref = c.getAttribute('r', namespaceUri: '*') ?? '';
        final col = _columnIndexFromRef(ref);
        final type = c.getAttribute('t', namespaceUri: '*');

        String value = '';
        if (type == 'inlineStr') {
          value = c.descendantElements
              .where((e) => e.name.local == 't')
              .map((e) => e.innerText)
              .join();
        } else {
          XmlElement? v;
          for (final el in c.findElements('v', namespaceUri: '*')) {
            v = el;
            break;
          }
          if (v != null) {
            value = v.innerText;
            if (type == 's') {
              final idx = int.tryParse(value);
              value = (idx != null && idx < sharedStrings.length)
                  ? sharedStrings[idx]
                  : '';
            }
          }
        }

        while (cells.length <= col) {
          cells.add('');
        }
        cells[col] = value.trim();
      }
    }

    // Merged ranges of column A: "A4:A16" -> (3, 15). Each range is one
    // day group's exact row span.
    final dayBlockRanges = <(int, int)>[];
    for (final merge in doc.findAllElements('mergeCell', namespaceUri: '*')) {
      final ref = merge.getAttribute('ref', namespaceUri: '*') ?? '';
      if (!ref.toUpperCase().startsWith('A')) continue;
      final parts = ref.split(':');
      if (parts.length != 2) continue;
      final r1 = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
      final r2 = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      if (r1 != null && r2 != null && r2 > r1) {
        dayBlockRanges.add((r1 - 1, r2 - 1));
      }
    }
    dayBlockRanges.sort((a, b) => a.$1.compareTo(b.$1));

    return (grid: grid, dayBlockRanges: dayBlockRanges);
  }

  /// Converts a cell reference like "BC12" into a zero-based column index.
  static int _columnIndexFromRef(String ref) {
    final letters = ref.replaceAll(RegExp(r'[^A-Za-z]'), '');
    var index = 0;
    for (var i = 0; i < letters.length; i++) {
      index = index * 26 + (letters.toUpperCase().codeUnitAt(i) - 64);
    }
    return index - 1;
  }

  /// Builds the [MessMenu] from a raw grid, or null when the grid doesn't
  /// look like a mess menu.
  static MessMenu? _menuFromBlocks(
    List<List<String>> grid,
    List<(int, int)> dayBlockRanges,
    int monthHint,
  ) {
    // 1. Locate the header row (contains "Breakfast").
    var headerRow = -1;
    var breakfastCol = -1, lunchCol = -1, snacksCol = -1, dinnerCol = -1;
    for (var r = 0; r < grid.length; r++) {
      for (var c = 0; c < grid[r].length; c++) {
        final cell = grid[r][c].toLowerCase();
        if (cell == 'breakfast') breakfastCol = c;
        if (cell == 'lunch') lunchCol = c;
        if (cell == 'snacks') snacksCol = c;
        if (cell == 'dinner') dinnerCol = c;
      }
      if (breakfastCol != -1 && lunchCol != -1) {
        headerRow = r;
        break;
      }
    }
    if (headerRow == -1) return null;

    // 1b. Weekly pattern format (women's hostel): the label column holds
    // weekday names instead of dates, and each cell packs multiple items
    // separated by newlines. The menu repeats weekly for the whole month.
    final weekdayLabels = <int, List<int>>{}; // row -> weekday numbers
    var weeklyFormat = true;
    for (var r = headerRow + 1; r < grid.length; r++) {
      final row = grid[r];
      final label = row.isNotEmpty ? row[0] : '';
      if (label.isEmpty) continue;
      if (RegExp(r'\d').hasMatch(label)) {
        // Date-based labels — this is the monthly format, not weekly.
        weeklyFormat = false;
        break;
      }
      final days_ = _weekdaysFromLabel(label);
      if (days_ != null) weekdayLabels[r] = days_;
    }

    if (weeklyFormat && weekdayLabels.length >= 2) {
      return _menuFromWeeklyPattern(
        grid,
        weekdayLabels,
        monthHint,
        mealCols: [breakfastCol, lunchCol, snacksCol, dinnerCol],
      );
    }

    // 2. Month: trust the workbook-wide "MONTH OF <name>" hint first, then
    // any month name inside this sheet, then the current month.
    var month = monthHint;
    if (month == -1) {
      final everything = grid.expand((row) => row).join('\n').toLowerCase();
      final match = RegExp(
        'month of\\s*[:\\- ]*([a-z]+)',
      ).firstMatch(everything);
      if (match != null) {
        month = _monthIndexFromName(match.group(1)!);
        if (month == -1) month = -1;
      }
    }
    if (month == -1) {
      final everything = grid.expand((row) => row).join('\n').toLowerCase();
      for (var m = 12; m >= 1; m--) {
        if (everything.contains(_monthName(m))) {
          month = m;
          break;
        }
      }
    }
    if (month == -1) {
      month = DateTime.now().month;
    }
    final now = DateTime.now();
    var year = yearFor(month, now);
    final monthName = _monthName(month);

    // 3. Assign item rows to day groups. When the sheet has merged cells in
    // the label column (the usual case), each merge marks a day group's
    // exact row span — use those. Otherwise fall back to blank-row
    // boundaries.
    final days = <int, Map<String, List<String>>>{};

    int weekOfMonth(int day) => ((day - 1) ~/ 7) + 1;

    void addItemsToDays(List<int> targetDays, List<int> cols, int r) {
      final row = grid[r];
      String cellAt(int col) => col >= 0 && col < row.length ? row[col] : '';
      for (final col in cols) {
        final value = cellAt(col);
        if (value.isEmpty) continue;
        final key = col == lunchCol
            ? 'lunch'
            : col == snacksCol
            ? 'snacks'
            : col == dinnerCol
            ? 'dinner'
            : 'breakfast';
        for (final day in targetDays) {
          // Resolve "(week1,week3)" / "(alt weeks)" alternates per date.
          final resolved = _applyWeekTag(value, weekOfMonth(day));
          if (resolved == null || resolved.isEmpty) continue;
          days
              .putIfAbsent(day, () => {})
              .putIfAbsent(key, () => [])
              .add(resolved);
        }
      }
    }

    final mealCols = [breakfastCol, lunchCol, snacksCol, dinnerCol];

    if (dayBlockRanges.isNotEmpty) {
      // First read every block's label, so the year can be settled from all of
      // them before any date is trusted.
      final blocks =
          <({int start, int end, int? weekday, List<int> numbers})>[];
      for (final (start, end) in dayBlockRanges) {
        if (end <= headerRow) continue;
        // Day numbers live in the label text ("Mon" / "10, 24" — possibly
        // multiline within the merged cell).
        final labelBuffer = StringBuffer();
        for (var r = start; r <= end && r < grid.length; r++) {
          final row = grid[r];
          for (var c = 0; c < (breakfastCol > 0 ? breakfastCol : 1); c++) {
            if (c < row.length) labelBuffer.write('${row[c]} ');
          }
        }
        final label = labelBuffer.toString();
        final dayNumbers = RegExp(r'\d+')
            .allMatches(label)
            .map((m) => int.parse(m.group(0)!))
            .where((n) => n >= 1 && n <= 31)
            .toList();
        if (dayNumbers.isEmpty) continue;
        blocks.add((
          start: start,
          end: end,
          weekday: weekdayOfLabel(label),
          numbers: dayNumbers,
        ));
      }

      year = bestYear(month, [
        for (final b in blocks) (weekday: b.weekday, numbers: b.numbers),
      ], year);

      for (final block in blocks) {
        final dates = repairDates(
          weekday: block.weekday,
          numbers: block.numbers,
          year: year,
          month: month,
        );
        if (dates.isEmpty) continue;
        for (var r = block.start; r <= block.end && r < grid.length; r++) {
          if (r <= headerRow) continue;
          addItemsToDays(dates, mealCols, r);
        }
      }
    } else {
      // Fallback: blank rows separate day groups.
      var currentDays = <int>[];
      var prevRowHadItems = false;

      for (var r = headerRow + 1; r < grid.length; r++) {
        final row = grid[r];
        String cellAt(int col) => col >= 0 && col < row.length ? row[col] : '';

        final hasItems = mealCols.any((col) => cellAt(col).isNotEmpty);
        if (!hasItems) {
          prevRowHadItems = false;
          continue;
        }

        if (!prevRowHadItems) {
          // The label is read from the first rows of the group, but never past
          // its end: on a short block the three rows ahead belong to the next
          // block, and its dates were being given this block's food.
          var groupEnd = r;
          while (groupEnd + 1 < grid.length &&
              mealCols.any(
                (col) =>
                    col >= 0 &&
                    col < grid[groupEnd + 1].length &&
                    grid[groupEnd + 1][col].isNotEmpty,
              )) {
            groupEnd++;
          }
          final labelBuffer = StringBuffer();
          for (
            var lr = r;
            lr <= (r + 3 < groupEnd ? r + 3 : groupEnd) && lr < grid.length;
            lr++
          ) {
            final labelRow = grid[lr];
            for (var c = 0; c < (breakfastCol > 0 ? breakfastCol : 1); c++) {
              if (c < labelRow.length) {
                labelBuffer.write('${labelRow[c]} ');
              }
            }
          }
          currentDays = RegExp(r'\d+')
              .allMatches(labelBuffer.toString())
              .map((m) => int.parse(m.group(0)!))
              .where((n) => n >= 1 && n <= 31)
              .toList();
        }

        addItemsToDays(currentDays, mealCols, r);
        prevRowHadItems = true;
      }
    }

    if (days.isEmpty) return null;

    return MessMenu(
      monthName: monthName[0].toUpperCase() + monthName.substring(1),
      month: month,
      year: year,
      days: days.map(
        (day, meals) => MapEntry(
          day,
          MessDayMenu(
            breakfast: meals['breakfast'] ?? const [],
            lunch: meals['lunch'] ?? const [],
            snacks: meals['snacks'] ?? const [],
            dinner: meals['dinner'] ?? const [],
          ),
        ),
      ),
    );
  }

  // ============================================================ other layouts
  //
  // The reader above understands the layouts the hostels send today: dated
  // blocks with merged day labels, and the women's weekly pattern. Workbooks come
  // in other shapes, and a menu that cannot be read is a menu nobody sees, so the
  // layouts below are tried too. They are *added*: the reader above runs first,
  // and these only take over when it finds nothing, or when the sheet plainly has
  // one row per day (which the reader above would blur into a single group).

  /// Reads a sheet in whichever supported layout it is in.
  static MessMenu? _menuFromGrid(
    List<List<String>> grid,
    List<(int, int)> dayBlockRanges,
    int monthHint,
  ) {
    if (dayBlockRanges.isEmpty && _looksPerRow(grid)) {
      final perRow = _menuFromRows(grid, monthHint);
      if (perRow != null) return perRow;
    }

    final blocks = _menuFromBlocks(grid, dayBlockRanges, monthHint);
    if (blocks != null) return blocks;

    // The headings may simply be worded differently ("BREAKFAST (7:30 - 9:00)",
    // "Evening Snacks"). Put the usual words in their place and let the same
    // reader try again, which gives blocks and weekly patterns the benefit too.
    final canonical = _withCanonicalHeader(grid);
    if (canonical != null) {
      final again = _menuFromBlocks(canonical, dayBlockRanges, monthHint);
      if (again != null) return again;
    }

    return _menuFromRows(grid, monthHint) ?? _menuFromColumns(grid, monthHint);
  }

  /// A copy of the grid whose meal headings read exactly Breakfast, Lunch, Snacks
  /// and Dinner, or null when the sheet has no meal headings at all.
  static List<List<String>>? _withCanonicalHeader(List<List<String>> grid) {
    final header = _locateMealHeader(grid);
    if (header == null) return null;
    const names = {
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'snacks': 'Snacks',
      'dinner': 'Dinner',
    };
    final copy = [
      for (final row in grid) [...row],
    ];
    for (final entry in header.cols.entries) {
      copy[header.row][entry.value] = names[entry.key]!;
    }
    return copy;
  }

  /// Which meal a column or row heading names, however the sheet words it:
  /// "BREAKFAST", "Break fast", "Breakfast (7:30 - 9:00)", "Evening Snacks",
  /// "Supper". Null for anything else, including a long cell that merely
  /// mentions a meal.
  static String? mealOf(String cell) {
    if (cell.length > 40) return null;
    final t = cell.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (t.isEmpty) return null;
    if (t.startsWith('breakfast') || t.startsWith('brkfast'))
      return 'breakfast';
    if (t.startsWith('lunch')) return 'lunch';
    if (t.contains('snack') ||
        t.startsWith('tea') ||
        t.startsWith('eveningtea')) {
      return 'snacks';
    }
    if (t.startsWith('dinner') || t.startsWith('supper')) return 'dinner';
    return null;
  }

  /// The row that names the meals as columns, and which column is which.
  ///
  /// A heading row needs at least breakfast, lunch and dinner. Snacks are
  /// optional: some menus have none.
  static ({int row, Map<String, int> cols})? _locateMealHeader(
    List<List<String>> grid,
  ) {
    for (var r = 0; r < grid.length; r++) {
      final cols = <String, int>{};
      for (var c = 0; c < grid[r].length; c++) {
        final meal = mealOf(grid[r][c]);
        if (meal != null) cols.putIfAbsent(meal, () => c);
      }
      if (cols.containsKey('breakfast') &&
          cols.containsKey('lunch') &&
          cols.containsKey('dinner')) {
        return (row: r, cols: cols);
      }
    }
    return null;
  }

  static const _monthWords = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  /// What a day label says: a date, or a day of the month, in any of the ways a
  /// sheet writes one. Null when it names no day (a weekday on its own, a note).
  ///
  /// Reads "1", "01", "1st", "Mon 3", "3 Mon", "1 Nov", "Nov 1", "01-11-2026",
  /// "1/11/26", and an Excel date cell, which arrives as a serial number.
  static ({int day, int? month, int? year, int? weekday})? dayOf(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // An Excel date: days since 1899-12-30.
    final serial = double.tryParse(text);
    if (serial != null && serial > 30000 && serial < 80000) {
      final date = DateTime.utc(
        1899,
        12,
        30,
      ).add(Duration(days: serial.floor()));
      return (
        day: date.day,
        month: date.month,
        year: date.year,
        weekday: date.weekday,
      );
    }

    final numeric = RegExp(
      r'(\d{1,2})\s*[-/.]\s*(\d{1,2})\s*[-/.]\s*(\d{2,4})',
    ).firstMatch(text);
    if (numeric != null) {
      final day = int.parse(numeric.group(1)!);
      final month = int.parse(numeric.group(2)!);
      var year = int.parse(numeric.group(3)!);
      if (year < 100) year += 2000;
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return (day: day, month: month, year: year, weekday: null);
      }
    }

    final lower = text.toLowerCase();
    final dayThenMonth = RegExp(
      r'(\d{1,2})(?:st|nd|rd|th)?\s*[-/ ]?\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?(?:[\s,-]*(\d{4}))?',
    ).firstMatch(lower);
    if (dayThenMonth != null) {
      final day = int.parse(dayThenMonth.group(1)!);
      if (day >= 1 && day <= 31) {
        return (
          day: day,
          month: _monthWords.indexOf(dayThenMonth.group(2)!) + 1,
          year: dayThenMonth.group(3) == null
              ? null
              : int.parse(dayThenMonth.group(3)!),
          weekday: weekdayOfLabel(text),
        );
      }
    }
    final monthThenDay = RegExp(
      r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(lower);
    if (monthThenDay != null) {
      final day = int.parse(monthThenDay.group(2)!);
      if (day >= 1 && day <= 31) {
        return (
          day: day,
          month: _monthWords.indexOf(monthThenDay.group(1)!) + 1,
          year: null,
          weekday: weekdayOfLabel(text),
        );
      }
    }

    // A day of the month on its own, with at most a weekday beside it.
    final numbers = RegExp(r'\d+').allMatches(text).toList();
    if (numbers.length == 1) {
      final day = int.parse(numbers.first.group(0)!);
      final rest = text.replaceFirst(numbers.first.group(0)!, '').trim();
      final onlyWeekday =
          rest.isEmpty ||
          RegExp(r'^[a-zA-Z]{2,9}\.?[\s,.:-]*$').hasMatch(rest) &&
              weekdayOfLabel(rest) != null ||
          RegExp(r'^(st|nd|rd|th)$', caseSensitive: false).hasMatch(rest);
      if (day >= 1 && day <= 31 && onlyWeekday) {
        return (
          day: day,
          month: null,
          year: null,
          weekday: weekdayOfLabel(text),
        );
      }
    }
    return null;
  }

  /// A cell's items, one per line.
  static List<String> _itemsOf(String cell) => cell
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  /// Whether a sheet has one row per day: a day label on nearly every row that
  /// has food. Blocks, where the label sits on the first row of thirteen, are not
  /// like this, and are left to the reader that understands them.
  static bool _looksPerRow(List<List<String>> grid) {
    final header = _locateMealHeader(grid);
    if (header == null) return false;
    final firstMeal = header.cols.values.reduce((a, b) => a < b ? a : b);
    if (firstMeal == 0) return false;

    var withFood = 0;
    var withDay = 0;
    for (var r = header.row + 1; r < grid.length; r++) {
      final row = grid[r];
      final hasFood = header.cols.values.any(
        (c) => c < row.length && row[c].trim().isNotEmpty,
      );
      if (!hasFood) continue;
      withFood++;
      final label = [
        for (var c = 0; c < firstMeal && c < row.length; c++) row[c],
      ].join(' ');
      if (dayOf(label) != null) withDay++;
    }
    return withDay >= 5 && withDay / withFood >= 0.8;
  }

  /// One row per day: the label column names the date, the meal columns hold
  /// that day's food, packed one item to a line.
  static MessMenu? _menuFromRows(List<List<String>> grid, int monthHint) {
    final header = _locateMealHeader(grid);
    if (header == null) return null;
    final firstMeal = header.cols.values.reduce((a, b) => a < b ? a : b);
    if (firstMeal == 0) return null;

    final rows =
        <
          ({
            int day,
            int? month,
            int? year,
            int? weekday,
            Map<String, List<String>> meals,
          })
        >[];
    var withFood = 0;
    for (var r = header.row + 1; r < grid.length; r++) {
      final row = grid[r];
      final hasFood = header.cols.values.any(
        (c) => c < row.length && row[c].trim().isNotEmpty,
      );
      if (hasFood) withFood++;
      final label = [
        for (var c = 0; c < firstMeal && c < row.length; c++) row[c],
      ].join(' ');
      final info = dayOf(label);
      if (info == null) continue;

      final meals = <String, List<String>>{};
      for (final entry in header.cols.entries) {
        final cell = entry.value < row.length ? row[entry.value] : '';
        final items = _itemsOf(cell);
        if (items.isNotEmpty) meals[entry.key] = items;
      }
      if (meals.isEmpty) continue;
      rows.add((
        day: info.day,
        month: info.month,
        year: info.year,
        weekday: info.weekday,
        meals: meals,
      ));
    }
    // One row per day means nearly every row with food carries a day. A block
    // layout labels only the first row of each block, and must not be read as
    // fourteen one-row days.
    if (rows.length < 5 || rows.length / withFood < 0.8) return null;

    return _assemble(
      rows
          .map(
            (r) => (
              day: r.day,
              month: r.month,
              year: r.year,
              weekday: r.weekday,
              meals: r.meals,
            ),
          )
          .toList(),
      monthHint: monthHint,
    );
  }

  /// Days laid out across the top and meals down the side, the other way round
  /// from the usual sheet. The heading over a column is a date, a day of the
  /// month, or a weekday (a weekly pattern).
  static MessMenu? _menuFromColumns(List<List<String>> grid, int monthHint) {
    // Meal rows: a heading in the first few columns.
    final mealRows = <int, String>{};
    var labelCol = -1;
    for (var r = 0; r < grid.length; r++) {
      for (var c = 0; c < grid[r].length && c < 3; c++) {
        final meal = mealOf(grid[r][c]);
        if (meal == null) continue;
        if (labelCol == -1) labelCol = c;
        if (c == labelCol) mealRows.putIfAbsent(r, () => meal);
      }
    }
    if (labelCol == -1 || mealRows.length < 3) return null;
    final meals = mealRows.values.toSet();
    if (!meals.containsAll(['breakfast', 'lunch', 'dinner'])) return null;

    // The heading row of days: the row above the first meal with the most
    // day-like cells.
    final firstMealRow = mealRows.keys.reduce((a, b) => a < b ? a : b);
    int? headerRow;
    var best = 0;
    for (var r = firstMealRow - 1; r >= 0 && r >= firstMealRow - 4; r--) {
      var score = 0;
      for (var c = labelCol + 1; c < grid[r].length; c++) {
        if (dayOf(grid[r][c]) != null || _bareWeekday(grid[r][c]) != null) {
          score++;
        }
      }
      if (score > best) {
        best = score;
        headerRow = r;
      }
    }
    if (headerRow == null || best < 5) return null;

    final sortedMealRows = mealRows.keys.toList()..sort();
    String? mealForRow(int r) {
      String? current;
      for (final mr in sortedMealRows) {
        if (mr <= r) current = mealRows[mr];
      }
      return current;
    }

    final lastRow = grid.length;
    final columns =
        <
          ({
            int day,
            int? month,
            int? year,
            int? weekday,
            Map<String, List<String>> meals,
          })
        >[];
    final weekly = <({int weekday, Map<String, List<String>> meals})>[];

    for (var c = labelCol + 1; c < grid[headerRow].length; c++) {
      final label = grid[headerRow][c];
      final info = dayOf(label);
      final weekday = info == null ? _bareWeekday(label) : null;
      if (info == null && weekday == null) continue;

      final dayMeals = <String, List<String>>{};
      for (var r = firstMealRow; r < lastRow; r++) {
        final meal = mealForRow(r);
        if (meal == null || c >= grid[r].length) continue;
        dayMeals.putIfAbsent(meal, () => []).addAll(_itemsOf(grid[r][c]));
      }
      dayMeals.removeWhere((_, items) => items.isEmpty);
      if (dayMeals.isEmpty) continue;

      if (info != null) {
        columns.add((
          day: info.day,
          month: info.month,
          year: info.year,
          weekday: info.weekday,
          meals: dayMeals,
        ));
      } else {
        weekly.add((weekday: weekday!, meals: dayMeals));
      }
    }

    if (columns.length >= 5) {
      return _assemble(columns, monthHint: monthHint);
    }
    if (weekly.length >= 5) {
      // A weekly pattern: the same food on that weekday all month.
      final month = monthHint == -1 ? DateTime.now().month : monthHint;
      final year = yearFor(month, DateTime.now());
      final length = DateTime(year, month + 1, 0).day;
      return _assemble([
        for (var d = 1; d <= length; d++)
          for (final w in weekly)
            if (DateTime(year, month, d).weekday == w.weekday)
              (
                day: d,
                month: month,
                year: year,
                weekday: w.weekday,
                meals: w.meals,
              ),
      ], monthHint: month);
    }
    return null;
  }

  /// A column heading that is only a weekday ("Mon", "Monday"), as a DateTime
  /// weekday number.
  static int? _bareWeekday(String label) {
    final text = label.trim();
    if (text.isEmpty || text.length > 12 || RegExp(r'\d').hasMatch(text))
      return null;
    return weekdayOfLabel(text);
  }

  /// Puts the days read from a sheet together into a menu: settles the month and
  /// the year from what the labels say, drops days that belong to another month,
  /// and fixes a weekday the calendar contradicts.
  static MessMenu? _assemble(
    List<
      ({
        int day,
        int? month,
        int? year,
        int? weekday,
        Map<String, List<String>> meals,
      })
    >
    days, {
    required int monthHint,
  }) {
    if (days.isEmpty) return null;

    int? mostCommon(Iterable<int?> values) {
      final counts = <int, int>{};
      for (final v in values) {
        if (v != null) counts[v] = (counts[v] ?? 0) + 1;
      }
      if (counts.isEmpty) return null;
      return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }

    final now = DateTime.now();
    final month =
        mostCommon(days.map((d) => d.month)) ??
        (monthHint != -1 ? monthHint : now.month);
    var year = mostCommon(days.map((d) => d.year)) ?? yearFor(month, now);
    year = bestYear(month, [
      for (final d in days)
        if (d.weekday != null) (weekday: d.weekday, numbers: [d.day]),
    ], year);
    final length = DateTime(year, month + 1, 0).day;

    final menu = <int, Map<String, List<String>>>{};
    for (final d in days) {
      if (d.month != null && d.month != month) continue;
      if (d.day < 1 || d.day > length) continue;
      final target = menu.putIfAbsent(d.day, () => {});
      for (final entry in d.meals.entries) {
        final resolved = [
          for (final item in entry.value)
            ?_applyWeekTag(item, ((d.day - 1) ~/ 7) + 1),
        ].where((item) => item.isNotEmpty);
        target.putIfAbsent(entry.key, () => []).addAll(resolved);
      }
    }
    if (menu.isEmpty) return null;

    final name = _monthName(month);
    return MessMenu(
      monthName: name[0].toUpperCase() + name.substring(1),
      month: month,
      year: year,
      days: menu.map(
        (day, meals) => MapEntry(
          day,
          MessDayMenu(
            breakfast: meals['breakfast'] ?? const [],
            lunch: meals['lunch'] ?? const [],
            snacks: meals['snacks'] ?? const [],
            dinner: meals['dinner'] ?? const [],
          ),
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    return months[month - 1];
  }

  /// Resolves weekly alternates inside an item line against the date's
  /// week of month. Lines tagged "(week1,week3)" survive only on those
  /// weeks, "(alt weeks)" on odd weeks; untagged lines always survive.
  /// The tag itself is stripped from the kept text.
  static String? _applyWeekTag(String line, int weekOfMonth) {
    final tagMatch = RegExp(
      r'\((?:week|alt)\s*[^)]*\)',
      caseSensitive: false,
    ).firstMatch(line);
    if (tagMatch == null) return line;

    final tag = tagMatch.group(0)!.toLowerCase();
    final isAlt = tag.contains('alt');
    final weeks = RegExp(
      r'\d+',
    ).allMatches(tag).map((m) => int.parse(m.group(0)!)).toSet();
    final keep = isAlt ? weekOfMonth.isOdd : weeks.contains(weekOfMonth);
    if (!keep) return null;

    return line
        .replaceFirst(tagMatch.group(0)!, '')
        .replaceAll(RegExp(r'[/+]\s*$'), '')
        .trim();
  }

  /// Parses a weekly-pattern label like "Monday / Friday" or
  /// "Tuesday / Thursday / Saturday" into DateTime weekday numbers
  /// (1 = Monday ... 7 = Sunday). Returns null when the label doesn't
  /// look like a pure weekday list.
  static List<int>? _weekdaysFromLabel(String label) {
    final lower = label.toLowerCase();
    const map = {
      'mon': DateTime.monday,
      'tue': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'thu': DateTime.thursday,
      'fri': DateTime.friday,
      'sat': DateTime.saturday,
      'sun': DateTime.sunday,
    };
    final result = <int>{};
    for (final entry in map.entries) {
      if (lower.contains(entry.key)) result.add(entry.value);
    }
    return result.isEmpty ? null : result.toList();
  }

  /// Builds a [MessMenu] from the weekly-pattern format: each labelled row
  /// repeats on its weekdays for every week of the month, and each meal
  /// cell holds newline-separated items.
  static MessMenu _menuFromWeeklyPattern(
    List<List<String>> grid,
    Map<int, List<int>> weekdayLabels,
    int monthHint, {
    required List<int> mealCols,
  }) {
    var month = monthHint;
    if (month == -1) {
      // Weekly sheets usually don't carry a month title — apply to the
      // current month.
      month = DateTime.now().month;
    }
    final now = DateTime.now();
    final year = yearFor(month, now);
    final monthName = _monthName(month);

    String mealKey(int col) {
      // The caller passes cols in [breakfast, lunch, snacks, dinner] order.
      return switch (mealCols.indexOf(col)) {
        0 => 'breakfast',
        1 => 'lunch',
        2 => 'snacks',
        _ => 'dinner',
      };
    }

    final days = <int, Map<String, List<String>>>{};
    final daysInMonth = DateTime(year, month + 1, 0).day;

    int weekOfMonth(int day) => ((day - 1) ~/ 7) + 1;

    for (final entry in weekdayLabels.entries) {
      final row = entry.key < grid.length ? grid[entry.key] : <String>[];
      String cellAt(int col) => col >= 0 && col < row.length ? row[col] : '';

      for (final col in mealCols) {
        final cell = cellAt(col);
        if (cell.trim().isEmpty) continue;
        final lines = cell
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (lines.isEmpty) continue;

        final key = mealKey(col);
        for (var day = 1; day <= daysInMonth; day++) {
          final weekday = DateTime(year, month, day).weekday;
          if (!entry.value.contains(weekday)) continue;
          final week = weekOfMonth(day);
          for (final line in lines) {
            // Resolve "(week1,week3)" / "(alt weeks)" alternates per date.
            final resolved = _applyWeekTag(line, week);
            if (resolved == null || resolved.isEmpty) continue;
            days
                .putIfAbsent(day, () => {})
                .putIfAbsent(key, () => [])
                .add(resolved);
          }
        }
      }
    }

    return MessMenu(
      monthName: monthName[0].toUpperCase() + monthName.substring(1),
      month: month,
      year: year,
      days: days.map(
        (day, meals) => MapEntry(
          day,
          MessDayMenu(
            breakfast: meals['breakfast'] ?? const [],
            lunch: meals['lunch'] ?? const [],
            snacks: meals['snacks'] ?? const [],
            dinner: meals['dinner'] ?? const [],
          ),
        ),
      ),
    );
  }
}
