import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/features/auth/model/semester_groups.dart';
import 'package:vit_ap_student_app/src/rust/api/vtop/types/semester.dart';

/// The semester choices, grouped into academic years.
///
/// Used wherever a semester is picked (first run and Settings), so the two can
/// never drift apart. Each year is a heading that folds its semesters away. The
/// year holding the chosen or current semester starts open and the rest start
/// folded, so a long history is a few lines rather than a wall.
///
/// A row is in one of three states: **selected** (the one about to be used, filled
/// like every other selected control), **current** (the one in use now, outlined
/// and tagged) or plain.
class SemesterYearList extends StatefulWidget {
  const SemesterYearList({
    super.key,
    required this.semesters,
    required this.onSelect,
    this.selectedId,
    this.currentId,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
  });

  final List<SemesterInfo> semesters;
  final ValueChanged<SemesterInfo> onSelect;
  final String? selectedId;
  final String? currentId;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  @override
  State<SemesterYearList> createState() => _SemesterYearListState();
}

class _SemesterYearListState extends State<SemesterYearList> {
  late List<SemesterYear> _years;
  final Set<String> _open = {};

  @override
  void initState() {
    super.initState();
    _years = SemesterGrouping.group(widget.semesters);
    _openTheRightYear();
  }

  @override
  void didUpdateWidget(covariant SemesterYearList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.semesters != widget.semesters) {
      _years = SemesterGrouping.group(widget.semesters);
    }
    // Choosing a semester must never leave it hidden behind a folded year.
    if (oldWidget.selectedId != widget.selectedId ||
        oldWidget.semesters != widget.semesters) {
      _openTheRightYear(keepOthers: true);
    }
  }

  void _openTheRightYear({bool keepOthers = false}) {
    if (!keepOthers) _open.clear();
    if (_years.isEmpty) return;

    final holding = _years.where(
      (y) => y.contains(widget.selectedId) || y.contains(widget.currentId),
    );
    _open.add((holding.isEmpty ? _years.first : holding.first).label);
  }

  void _toggle(String label) => setState(() {
    if (!_open.remove(label)) _open.add(label);
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: widget.shrinkWrap,
      padding: widget.padding,
      children: [
        for (final year in _years) ...[
          _YearHeader(
            label: year.label,
            count: year.entries.length,
            open: _open.contains(year.label),
            onTap: () => _toggle(year.label),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open.contains(year.label)
                ? Column(
                    children: [
                      for (final entry in year.entries) ...[
                        _SemesterRow(
                          name: entry.shortName,
                          selected: entry.info.id == widget.selectedId,
                          current: entry.info.id == widget.currentId,
                          onTap: () => widget.onSelect(entry.info),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({
    required this.label,
    required this.count,
    required this.open,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      expanded: open,
      label: '$label, $count ${count == 1 ? 'semester' : 'semesters'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count ${count == 1 ? 'semester' : 'semesters'}',
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemesterRow extends StatelessWidget {
  const _SemesterRow({
    required this.name,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final foreground = selected ? colors.onPrimary : colors.onSurface;
    final secondary = selected
        ? colors.onPrimary.withValues(alpha: 0.7)
        : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : current
                  ? colors.onSurfaceVariant
                  : colors.outlineVariant,
              width: current && !selected ? 1 : 0.75,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
              if (current)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'current',
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: secondary,
                    ),
                  ),
                ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_rounded, size: 18, color: colors.onPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
