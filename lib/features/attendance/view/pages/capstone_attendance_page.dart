import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/common/widget/empty_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/error_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/theme/app_theme.dart';
import 'package:vit_ap_student_app/features/attendance/model/capstone_attendance.dart';
import 'package:vit_ap_student_app/features/attendance/viewmodel/capstone_viewmodel.dart';

/// Capstone (or SDP) attendance: the present / on-duty / absent tally and the
/// day-by-day calendar. Students without a registration see a plain "none".
class CapstoneAttendancePage extends ConsumerStatefulWidget {
  const CapstoneAttendancePage({super.key});

  @override
  ConsumerState<CapstoneAttendancePage> createState() =>
      _CapstoneAttendancePageState();
}

class _CapstoneAttendancePageState
    extends ConsumerState<CapstoneAttendancePage> {
  bool _showOtherDays = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Watched here, in build, for as long as the page is up: the notifier is
    // auto-disposed, and a slow request must not lose it.
    final state = ref.watch(capstoneViewModelProvider);
    final capstone = state.capstone;

    Widget body;
    if (!state.loaded) {
      body = const Loader();
    } else if (capstone == null && state.error != null) {
      body = ErrorContentView(error: state.error!);
    } else if (capstone == null) {
      body = const EmptyContentView(
        primaryText: 'No capstone this semester',
        secondaryText:
            'Your capstone or SDP attendance appears here once you are '
            'registered for one.',
      );
    } else {
      body = _Content(
        capstone: capstone,
        state: state,
        showOtherDays: _showOtherDays,
        onToggleOtherDays: () =>
            setState(() => _showOtherDays = !_showOtherDays),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: AccentGradientText(
          (capstone?.title.isNotEmpty ?? false) ? capstone!.title : 'Capstone',
          style: const TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (state.refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              icon: Icon(
                LucideIcons.refreshCw,
                color: colors.primary,
                size: 20,
              ),
              onPressed: () =>
                  ref.read(capstoneViewModelProvider.notifier).refresh(),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(capstoneViewModelProvider.notifier).refresh(),
          child: body,
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.capstone,
    required this.state,
    required this.showOtherDays,
    required this.onToggleOtherDays,
  });

  final CapstoneAttendance capstone;
  final CapstoneState state;
  final bool showOtherDays;
  final VoidCallback onToggleOtherDays;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final marked = capstone.markedDays;
    final other = capstone.otherDays;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        _SummaryCard(capstone: capstone),
        const SizedBox(height: 10),
        if (capstone.guideEvaluationStatus.isNotEmpty ||
            capstone.dateOfRegistration.isNotEmpty)
          _InfoCard(capstone: capstone),
        if (state.error != null) ...[
          const SizedBox(height: 10),
          Text(
            '${state.error!} Showing what was saved.',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 12.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          'Days',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        if (marked.isEmpty)
          Text('No days have been marked yet.', style: _caption(context))
        else
          for (final day in marked) ...[
            _DayRow(day: day),
            const SizedBox(height: 8),
          ],
        if (other.isNotEmpty) ...[
          TextButton(
            onPressed: onToggleOtherDays,
            child: Text(
              showOtherDays
                  ? 'Hide holidays and other days'
                  : 'Show holidays and other days (${other.length})',
              style: const TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13.5,
              ),
            ),
          ),
          if (showOtherDays)
            for (final day in other) ...[
              _DayRow(day: day, dim: true),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.capstone});

  final CapstoneAttendance capstone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final percent = capstone.percentage;

    Widget stat(String label, int value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: _caption(context)),
        ],
      ),
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance', style: _caption(context)),
          const SizedBox(height: 4),
          Text(
            percent == null ? '-' : '${_percent(percent)}%',
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 38,
              height: 1.1,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('Present', capstone.present),
              stat('On duty', capstone.onDuty),
              stat('Absent', capstone.absent),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.capstone});

  final CapstoneAttendance capstone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget line(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  child: Text(label, style: _caption(context)),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Instrument Sans',
                      fontSize: 13.5,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        children: [
          line(
            'Guide evaluation',
            _trimTrailingComma(capstone.guideEvaluationStatus),
          ),
          line('Registered on', _registered(capstone.dateOfRegistration)),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, this.dim = false});

  final CapstonePunch day;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);
    final when = day.when;

    final statusColor = switch (day.status.toLowerCase()) {
      'present' => status.success,
      'absent' => status.danger,
      'on duty' => colors.onSurface,
      _ => colors.onSurfaceVariant,
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when == null
                      ? day.date
                      : DateFormat('EEE, d MMM').format(when),
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: dim ? colors.onSurfaceVariant : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(day.dayType, style: _caption(context)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (day.status.isNotEmpty)
                Text(
                  day.status,
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              if (day.punchTime.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(day.punchTime, style: _caption(context)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

TextStyle _caption(BuildContext context) => TextStyle(
  fontFamily: 'Instrument Sans',
  fontSize: 12,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

/// "60", or "66.7" when it is not whole.
String _percent(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _trimTrailingComma(String text) =>
    text.trim().replaceAll(RegExp(r',\s*$'), '');

/// "2026-07-06 00:00:00.0" as "6 Jul 2026"; as written when it does not parse.
String _registered(String raw) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
  if (m == null) return raw.trim();
  final date = DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
  return DateFormat('d MMM yyyy').format(date);
}
