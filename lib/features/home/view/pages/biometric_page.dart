import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/common/widget/empty_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/error_content_view.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/features/home/model/biometric.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/biometric_viewmodel.dart';

/// Where the student's biometric (hostel and campus gate) entries are shown.
///
/// One day at a time. The last week is a row of chips that load the day when
/// tapped, and "Pick date" reaches anything older. A day that has been loaded is
/// kept for the life of the page, so going back to it costs no request; pulling
/// down refreshes the day on screen.
class BiometricPage extends ConsumerStatefulWidget {
  const BiometricPage({super.key});

  @override
  ConsumerState<BiometricPage> createState() => _BiometricPageState();
}

class _BiometricPageState extends ConsumerState<BiometricPage> {
  /// The date VTOP expects, which is also the key a day is cached under.
  static final DateFormat _vtopDate = DateFormat('dd/MM/yyyy');

  late final DateTime _today;
  late DateTime _selected;

  /// Days already loaded, by [_vtopDate].
  final Map<String, List<Biometric>> _cache = {};

  /// Why a day could not be loaded, by [_vtopDate].
  final Map<String, String> _errors = {};

  /// The day most recently asked for. An answer for any other day is stale (the
  /// student has moved on) and is dropped rather than shown under the wrong date.
  String? _requested;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selected = _today;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_selected));
  }

  String _key(DateTime day) => _vtopDate.format(day);

  /// Selects [day], and fetches it unless it is already on hand.
  Future<void> _load(DateTime day, {bool force = false}) async {
    setState(() => _selected = day);
    final key = _key(day);
    if (!force && _cache.containsKey(key)) return;

    _requested = key;
    setState(() => _errors.remove(key));
    await ref.read(biometricViewModelProvider.notifier).fetchBiometric(key);

    // The view model holds one answer at a time, so it is read straight after
    // its own request finishes, and only if that is still the day being asked for.
    if (!mounted || _requested != key) return;
    ref
        .read(biometricViewModelProvider)
        ?.whenOrNull(
          data: (data) => setState(() => _cache[key] = data),
          error: (error, _) => setState(() => _errors[key] = error.toString()),
        );
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2024),
      lastDate: _today,
      helpText: 'Pick a date',
    );
    if (picked == null || !mounted) return;
    await _load(DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Listening is what keeps the view model alive. It is auto-disposed, so a
    // page that only `read`s it loses it, and the answer to a request that takes
    // a few seconds, which VTOP's does, to a provider that no longer exists. The
    // page then waited for ever on a spinner.
    ref.watch(biometricViewModelProvider);
    final key = _key(_selected);
    final cached = _cache[key];
    final error = _errors[key];
    final loading = cached == null && error == null;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const AccentGradientText(
          'Biometric Log',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayStrip(
              today: _today,
              selected: _selected,
              onSelect: _load,
              onPick: _pick,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: loading
                  ? const _Loading()
                  : error != null
                  ? ErrorContentView(error: error)
                  : cached == null
                  ? const SizedBox.shrink()
                  : _Day(
                      day: _selected,
                      entries: cached,
                      onRefresh: () => _load(_selected, force: true),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today, Yesterday, the five days before, and "Pick date" for anything older.
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.today,
    required this.selected,
    required this.onSelect,
    required this.onPick,
  });

  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var i = 0; i < 7; i++) today.subtract(Duration(days: i)),
    ];
    final inStrip = days.any((d) => d == selected);

    String label(int i, DateTime day) => switch (i) {
      0 => 'Today',
      1 => 'Yesterday',
      _ => DateFormat('EEE d').format(day),
    };

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          for (var i = 0; i < days.length; i++) ...[
            _Chip(
              label: label(i, days[i]),
              selected: days[i] == selected,
              onTap: () => onSelect(days[i]),
            ),
            const SizedBox(width: 8),
          ],
          // An older day was chosen from the calendar: show which, selected.
          _Chip(
            label: inStrip
                ? 'Pick date'
                : DateFormat('d MMM yyyy').format(selected),
            icon: Icons.calendar_today_outlined,
            selected: !inStrip,
            onTap: onPick,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Instrument Sans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Loader(),
        const SizedBox(height: 16),
        Text(
          'Fetching your biometric log',
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 13.5,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One day: a summary line and the entries in the order they happened.
class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.entries,
    required this.onRefresh,
  });

  final DateTime day;
  final List<Biometric> entries;
  final Future<void> Function() onRefresh;

  /// "8:12 AM" for VTOP's `08:12`; anything that is not a time is shown as given
  /// rather than dropped.
  static String _clock(String raw) {
    try {
      return DateFormat.jm().format(DateFormat.Hm().parse(raw.trim()));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final sorted = [...entries]..sort((a, b) => a.time.compareTo(b.time));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: sorted.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: const EmptyContentView(
                    primaryText: 'No entries',
                    secondaryText:
                        'No biometric entries were found for this day',
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                Text(
                  '${DateFormat('EEEE, d MMMM').format(day)} · '
                  '${sorted.length} ${sorted.length == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(
                    fontFamily: 'Instrument Sans',
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in sorted) ...[
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(
                            _clock(entry.time),
                            style: TextStyle(
                              fontFamily: 'Instrument Sans',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.location,
                            style: TextStyle(
                              fontFamily: 'Instrument Sans',
                              fontSize: 14,
                              height: 1.3,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}
