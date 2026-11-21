import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/services/demo_service.dart';
import 'package:vit_ap_student_app/core/utils/show_snackbar.dart';
import 'package:vit_ap_student_app/features/home/view/pages/outing/general_outing_history_page.dart';
import 'package:vit_ap_student_app/features/home/view/widgets/outing/outing_form.dart';
import 'package:vit_ap_student_app/features/home/viewmodel/outing_submission_viewmodel.dart';

class GeneralOutingTab extends ConsumerStatefulWidget {
  const GeneralOutingTab({super.key});

  @override
  ConsumerState<GeneralOutingTab> createState() => _GeneralOutingTabState();
}

class _GeneralOutingTabState extends ConsumerState<GeneralOutingTab> {
  String? _placeOfVisit;
  String? _purposeOfVisit;
  DateTime? _fromDate;
  TimeOfDay? _fromTime;
  DateTime? _toDate;
  TimeOfDay? _toTime;
  final _formKey = GlobalKey<FormState>();

  /// VTOP only takes general outings between 6 AM and 10 PM.
  bool _validateTime(TimeOfDay time) {
    final int hour = time.hour;
    final int minute = time.minute;

    if ((hour > 6 || (hour == 6 && minute >= 0)) &&
        (hour < 22 || (hour == 22 && minute == 0))) {
      return true;
    } else {
      showSnackBar(
        context,
        'Please select a time between 06:00 AM and 10:00 PM',
        SnackBarType.warning,
      );
      return false;
    }
  }

  /// A day and a time of day as one moment.
  static DateTime _moment(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  /// The time the way VTOP wants it: `HH:mm`.
  static String _hhmm(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final leaving = _moment(_fromDate!, _fromTime!);
    final back = _moment(_toDate!, _toTime!);
    if (!back.isAfter(leaving)) {
      showSnackBar(
        context,
        'You must be back after the time you leave',
        SnackBarType.warning,
      );
      return;
    }

    await ref
        .read(generalOutingSubmissionProvider.notifier)
        .submitGeneralOuting(
          outPlace: _placeOfVisit!,
          purposeOfVisit: _purposeOfVisit!,
          outingDate: DateFormat('dd-MMM-yyyy').format(_fromDate!),
          outTime: _hhmm(_fromTime!),
          inDate: DateFormat('dd-MMM-yyyy').format(_toDate!),
          inTime: _hhmm(_toTime!),
        );
  }

  void _clearForm() {
    setState(() {
      _fromTime = null;
      _toTime = null;
      _placeOfVisit = null;
      _purposeOfVisit = null;
      _fromDate = null;
      _toDate = null;
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      generalOutingSubmissionProvider.select((val) => val?.isLoading == true),
    );

    ref.listen(generalOutingSubmissionProvider, (_, next) {
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

    final today = DateTime.now();

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
                OutingTextField(
                  label: 'Place of visit',
                  hint: 'Where are you going?',
                  capitalization: TextCapitalization.words,
                  onChanged: (value) => _placeOfVisit = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter the place of visit'
                      : null,
                ),
                const SizedBox(height: 14),
                OutingTextField(
                  label: 'Purpose of visit',
                  hint: 'Why are you going?',
                  onChanged: (value) => _purposeOfVisit = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter the purpose of visit'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutingSection(
              title: 'When',
              children: [
                OutingMomentField(
                  label: 'Leaving',
                  date: _fromDate,
                  time: _fromTime,
                  timeEnabled: true,
                  firstDate: today,
                  onDate: (date) => setState(() => _fromDate = date),
                  onTime: (time) => setState(() => _fromTime = time),
                  timeValidator: _validateTime,
                  validator: () => _fromDate == null || _fromTime == null
                      ? 'Please pick the day and time you leave'
                      : null,
                ),
                const SizedBox(height: 14),
                OutingMomentField(
                  label: 'Back',
                  date: _toDate,
                  time: _toTime,
                  timeEnabled: true,
                  firstDate: _fromDate ?? today,
                  onDate: (date) => setState(() => _toDate = date),
                  onTime: (time) => setState(() => _toTime = time),
                  timeValidator: _validateTime,
                  validator: () => _toDate == null || _toTime == null
                      ? 'Please pick the day and time you are back'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutingActions(
              loading: isLoading,
              // Applying is a write to VTOP, off for the demo account. The
              // history stays viewable.
              canApply: !DemoService.isDemoMode,
              onApply: _submitForm,
              onHistory: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const GeneralOutingHistoryPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
