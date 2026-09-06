import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/accent_gradient_text.dart';
import 'package:vit_ap_student_app/core/utils/request_notification_permission.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/milestones_viewmodel.dart';

class MilestoneManagePage extends ConsumerWidget {
  const MilestoneManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(milestonesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: AccentGradientText(
          'Manage countdowns',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Iconsax.add_copy, size: 20),
        label: const Text(
          'New countdown',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: milestones.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.calendar_circle_copy,
                    size: 44,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nothing to track yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create a countdown for exams, quizzes\nor assignment deadlines.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: milestones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                final daysLeft = milestone.daysLeft();
                final hoursLeft = milestone.hoursLeft();

                final String daysText;
                if (milestone.isPassed()) {
                  daysText = 'Passed';
                } else if (daysLeft >= 1) {
                  daysText = 'In $daysLeft days';
                } else if (hoursLeft >= 1) {
                  daysText = 'In $hoursLeft hours';
                } else {
                  daysText = 'Any moment now';
                }

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              milestone.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (milestone.info != null &&
                                milestone.info!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                milestone.info!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat('d MMM yyyy, h:mm a').format(milestone.targetDate)}  •  $daysText',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Iconsax.trash_copy,
                          size: 19,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => ref
                            .read(milestonesProvider.notifier)
                            .removeMilestone(milestone.id),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _AddMilestoneSheet(),
    );
  }
}

class _AddMilestoneSheet extends ConsumerStatefulWidget {
  const _AddMilestoneSheet();

  @override
  ConsumerState<_AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends ConsumerState<_AddMilestoneSheet> {
  final _titleController = TextEditingController();
  final _infoController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Opt-in reminder. Off by default — the user explicitly enables it per
  // countdown and picks how long before the target moment it should fire.
  bool _remindMe = false;
  int _reminderMinutesBefore = 30;

  /// Trigger-time choices: minutes before the countdown -> label.
  static const Map<int, String> _reminderChoices = {
    10: '10 min',
    30: '30 min',
    60: '1 hour',
    360: '6 hours',
    1440: '1 day',
    10080: '1 week',
  };

  @override
  void initState() {
    super.initState();
    // Rebuild so the save button enables once the required fields are valid.
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      // Follow up with the time picker so the target moment is exact.
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      );
      if (pickedTime != null && mounted) {
        setState(() => _selectedTime = pickedTime);
      }
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedDate == null) return;

    final time = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
    final target = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      time.hour,
      time.minute,
    );

    await ref.read(milestonesProvider.notifier).addMilestone(
          title: title,
          info: _infoController.text,
          targetDate: target,
          reminderEnabled: _remindMe,
          reminderMinutesBefore: _reminderMinutesBefore,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'New countdown',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            Text(
              'TITLE',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. CAT-1',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NOTES (OPTIONAL)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _infoController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Covers modules 1-3',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  color: colorScheme.onSurfaceVariant,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'DATE',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.calendar_copy,
                      size: 17,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedDate == null
                          ? 'Pick a date & time'
                          : DateFormat('EEEE, d MMM yyyy').format(
                                  _selectedDate!) +
                              (_selectedTime == null
                                  ? ''
                                  : ', ${_selectedTime!.format(context)}'),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _selectedDate == null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Opt-in reminder: default OFF. Toggling it on requests the
            // notification permission right here (user-gesture context).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.notification_bing_copy,
                    size: 17,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Remind me before',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch.adaptive(
                      value: _remindMe,
                      onChanged: (value) async {
                        if (value) await requestNotificationPermission();
                        if (!mounted) return;
                        setState(() => _remindMe = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_remindMe) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reminderChoices.entries.map((choice) {
                  final selected = _reminderMinutesBefore == choice.key;
                  return ChoiceChip(
                    label: Text(choice.value),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _reminderMinutesBefore = choice.key),
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                    selectedColor: colorScheme.primary,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed:
                    _titleController.text.trim().isNotEmpty &&
                            _selectedDate != null
                        ? _save
                        : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  disabledBackgroundColor: colorScheme.surfaceContainerHigh,
                  disabledForegroundColor: colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save countdown',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

