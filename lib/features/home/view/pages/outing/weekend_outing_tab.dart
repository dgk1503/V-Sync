import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/constants/app_constants.dart';
import 'package:vit_ap_student_app/core/providers/user_preferences_notifier.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/weekend_outing_history_page.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/outing/outing_form.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/outing_submission_viewmodel.dart';

class WeekendOutingTab extends ConsumerStatefulWidget {
  const WeekendOutingTab({super.key});

  @override
  ConsumerState<WeekendOutingTab> createState() => _WeekendOutingTabState();
}

class _WeekendOutingTabState extends ConsumerState<WeekendOutingTab> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedPlace = AppConstants.outingPlaces.first;
  String? _selectedTimeSlot = AppConstants.outingTimeSlots.first;
  String? _purpose;
  String? _contactNumber;
  DateTime? _outingDate;

  /// Check if the deadline has passed for applying weekend outing
  /// Sunday outing: Can apply till Friday 11:59 PM
  /// Monday outing: Can apply till Saturday 11:59 PM
  bool _isDeadlinePassed(DateTime outingDate, bool bypassRestriction) {
    if (bypassRestriction) return false;

    final now = DateTime.now();
    final outingDay = outingDate.weekday;

    if (outingDay == DateTime.sunday) {
      // Sunday outing - deadline is Friday 11:59 PM
      // Find the Friday before the selected Sunday
      final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
      final targetSunday = now.add(Duration(days: daysUntilSunday));

      // Check if selected Sunday matches the upcoming Sunday
      if (outingDate.year == targetSunday.year &&
          outingDate.month == targetSunday.month &&
          outingDate.day == targetSunday.day) {
        // Deadline is Friday 11:59 PM (2 days before Sunday)
        final deadline = DateTime(
          targetSunday.year,
          targetSunday.month,
          targetSunday.day - 2,
          23,
          59,
          59,
        );
        return now.isAfter(deadline);
      }
    } else if (outingDay == DateTime.monday) {
      // Monday outing - deadline is Saturday 11:59 PM
      // Find the Monday
      final daysUntilMonday = (DateTime.monday - now.weekday) % 7;
      final targetMonday = now.add(
        Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday),
      );

      // Check if selected Monday matches the target Monday
      if (outingDate.year == targetMonday.year &&
          outingDate.month == targetMonday.month &&
          outingDate.day == targetMonday.day) {
        // Deadline is Saturday 11:59 PM (2 days before Monday)
        final deadline = DateTime(
          targetMonday.year,
          targetMonday.month,
          targetMonday.day - 2,
          23,
          59,
          59,
        );
        return now.isAfter(deadline);
      }
    }

    return false;
  }

  Future<void> _submitWeekendOuting() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check deadline restriction
    final prefs = ref.read(userPreferencesProvider);
    final bypassRestriction = prefs.bypassWeekendOutingRestriction;

    if (_isDeadlinePassed(_outingDate!, bypassRestriction)) {
      showSnackBar(
        context,
        'Application deadline has passed for this date',
        SnackBarType.error,
      );
      return;
    }

    await ref
        .read(weekendOutingSubmissionProvider.notifier)
        .submitWeekendOuting(
          outPlace: _selectedPlace!,
          purposeOfVisit: _purpose!,
          outingDate: DateFormat('dd-MMM-yyyy').format(_outingDate!),
          outTime: _selectedTimeSlot!,
          contactNumber: _contactNumber!,
        );
  }

  void _clearForm() {
    setState(() {
      _selectedPlace = AppConstants.outingPlaces.first;
      _selectedTimeSlot = AppConstants.outingTimeSlots.first;
      _outingDate = null;
      _purpose = null;
      _contactNumber = null;
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      weekendOutingSubmissionProvider.select((val) => val?.isLoading == true),
    );

    ref.listen(weekendOutingSubmissionProvider, (_, next) {
      next?.when(
        data: (message) {
          showSnackBar(context, message, SnackBarType.success);
          _clearForm();
        },
        loading: () {},
        error: (error, st) {
          showSnackBar(context, error.toString(), SnackBarType.error);
        },
      );
    });

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 4,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutingSection(
              title: 'Where to',
              children: [
                OutingChoices(
                  label: 'Place of visit',
                  options: AppConstants.outingPlaces,
                  selected: _selectedPlace,
                  onSelected: (place) => setState(() => _selectedPlace = place),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select a place'
                      : null,
                ),
                const SizedBox(height: 14),
                OutingTextField(
                  label: 'Purpose of visit',
                  hint: 'Why are you going?',
                  onChanged: (value) => _purpose = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter purpose'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutingSection(
              title: 'When',
              children: [
                OutingMomentField(
                  label: 'Outing date',
                  date: _outingDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 7)),
                  onDate: (date) => setState(() => _outingDate = date),
                  selectableDayPredicate: (DateTime date) {
                    // Only allow Sunday (7) or Monday (1)
                    if (date.weekday != DateTime.sunday &&
                        date.weekday != DateTime.monday) {
                      return false;
                    }

                    // Check if deadline has passed (unless bypassed)
                    final prefs = ref.read(userPreferencesProvider);
                    final bypassRestriction =
                        prefs.bypassWeekendOutingRestriction;

                    if (!bypassRestriction && _isDeadlinePassed(date, false)) {
                      return false;
                    }

                    return true;
                  },
                  validator: () =>
                      _outingDate == null ? 'Please select a date' : null,
                ),
                const SizedBox(height: 14),
                OutingChoices(
                  label: 'Time slot',
                  options: AppConstants.outingTimeSlots,
                  selected: _selectedTimeSlot,
                  onSelected: (slot) =>
                      setState(() => _selectedTimeSlot = slot),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select a time slot'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutingSection(
              title: 'Contact',
              children: [
                OutingTextField(
                  label: 'Contact number',
                  hint: '10 digit mobile number',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  onChanged: (value) => _contactNumber = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter contact number';
                    }
                    if (value.length != 10) {
                      return 'Contact number must be 10 digits';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutingActions(
              loading: isLoading,
              // Applying is a write to VTOP, off for the demo account. The
              // history stays viewable.
              canApply: !DemoService.isDemoMode,
              onApply: _submitWeekendOuting,
              onHistory: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const WeekendOutingHistoryPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
