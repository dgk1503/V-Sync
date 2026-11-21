import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds a minimal real `.xlsx` from plain grids, for tests.
///
/// Only what a reader needs: a workbook, its relationships and one worksheet per
/// sheet, with every cell as an inline string. That is enough to exercise the
/// whole unzip-and-parse path without a binary fixture.
Uint8List buildXlsx(
  Map<String, List<List<String>>> sheets, {
  Map<String, List<String>> merges = const {},
}) {
  final archive = Archive();

  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String colName(int index) {
    var n = index + 1;
    var s = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      s = String.fromCharCode(65 + rem) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  final names = sheets.keys.toList();

  final sheetTags = StringBuffer();
  final relTags = StringBuffer();
  for (var i = 0; i < names.length; i++) {
    sheetTags.write(
      '<sheet name="${esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
    );
    relTags.write(
      '<Relationship Id="rId${i + 1}" Type="worksheet" '
      'Target="worksheets/sheet${i + 1}.xml"/>',
    );
  }

  add(
    'xl/workbook.xml',
    '<?xml version="1.0" encoding="UTF-8"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets>$sheetTags</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<?xml version="1.0" encoding="UTF-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$relTags</Relationships>',
  );

  for (var s = 0; s < names.length; s++) {
    final grid = sheets[names[s]]!;
    final rows = StringBuffer();
    for (var r = 0; r < grid.length; r++) {
      final cells = StringBuffer();
      for (var c = 0; c < grid[r].length; c++) {
        final value = grid[r][c];
        if (value.isEmpty) continue;
        cells.write(
          '<c r="${colName(c)}${r + 1}" t="inlineStr"><is>'
          '<t xml:space="preserve">${esc(value)}</t></is></c>',
        );
      }
      rows.write('<row r="${r + 1}">$cells</row>');
    }

    final mergeList = merges[names[s]] ?? const <String>[];
    final mergeXml = mergeList.isEmpty
        ? ''
        : '<mergeCells>${mergeList.map((m) => '<mergeCell ref="$m"/>').join()}</mergeCells>';

    add(
      'xl/worksheets/sheet${s + 1}.xml',
      '<?xml version="1.0" encoding="UTF-8"?>'
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<sheetData>$rows</sheetData>$mergeXml</worksheet>',
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}
