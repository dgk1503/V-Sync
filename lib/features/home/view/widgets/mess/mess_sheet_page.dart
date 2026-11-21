import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/features/home/model/mess_menu.dart';
import 'package:vit_ap_student_app/features/home/services/mess_menu_service.dart';

/// A mess menu spreadsheet shown as the table it came as.
///
/// This is the fallback for a sheet the menu reader does not understand: the
/// student still gets to see their menu, laid out as the hostel wrote it.
class MessSheetPage extends StatefulWidget {
  const MessSheetPage({super.key, required this.source});

  final MessSource source;

  @override
  State<MessSheetPage> createState() => _MessSheetPageState();
}

class _MessSheetPageState extends State<MessSheetPage> {
  late final Future<List<List<String>>> _grid = _load();

  Future<List<List<String>>> _load() async {
    final bytes = await File(widget.source.path).readAsBytes();
    return compute(MessMenuService.rawGrid, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const AccentGradientText(
          'Mess menu',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FutureBuilder<List<List<String>>>(
        future: _grid,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Loader();
          }
          final grid = snapshot.data;
          if (snapshot.hasError || grid == null || grid.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "This file has nothing the app can show. Open it in a "
                  'spreadsheet app instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 14,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return _SheetTable(grid: grid);
        },
      ),
    );
  }
}

class _SheetTable extends StatelessWidget {
  const _SheetTable({required this.grid});

  final List<List<String>> grid;

  // A sheet is a month of rows; showing a few hundred is plenty and keeps a
  // pathological file from freezing the page.
  static const _maxRows = 400;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = grid.take(_maxRows).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(150),
          border: TableBorder.all(color: colors.outlineVariant, width: 0.5),
          children: [
            for (final row in rows)
              TableRow(
                children: [
                  for (final cell in row)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        cell,
                        style: TextStyle(
                          fontFamily: 'Instrument Sans',
                          fontSize: 12.5,
                          height: 1.3,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
