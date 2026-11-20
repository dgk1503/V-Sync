import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vit_ap_student_app/core/common/widget/app_card.dart';
import 'package:vit_ap_student_app/core/common/widgets/common_date_picker.dart';

/// The pieces both outing applications are built from, so the weekend and the
/// general form look and behave as one.

/// A titled card that holds one group of fields.
class OutingSection extends StatelessWidget {
  const OutingSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// A small caption above a field.
class OutingLabel extends StatelessWidget {
  const OutingLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Instrument Sans',
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// A filled, borderless text field with its caption above it.
class OutingTextField extends StatelessWidget {
  const OutingTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.onChanged,
    required this.validator,
    this.keyboardType,
    this.capitalization = TextCapitalization.sentences,
    this.maxLength,
  });

  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    OutlineInputBorder border([Color? color]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutingLabel(label),
        TextFormField(
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          maxLength: maxLength,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 15,
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15,
              color: colors.onSurfaceVariant,
            ),
            filled: true,
            fillColor: colors.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: border(),
            enabledBorder: border(),
            focusedBorder: border(colors.primary),
            errorBorder: border(colors.error),
            focusedErrorBorder: border(colors.error),
            errorStyle: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 12,
              color: colors.error,
            ),
          ),
        ),
      ],
    );
  }
}

/// One choice among a few, as the same pill every other selected control uses.
class OutingChoices extends StatelessWidget {
  const OutingChoices({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.validator,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FormField<String>(
      initialValue: selected,
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutingLabel(label),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  Semantics(
                    button: true,
                    selected: option == selected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        onSelected(option);
                        state.didChange(option);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: option == selected
                              ? colors.primary
                              : colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          option,
                          style: TextStyle(
                            fontFamily: 'Instrument Sans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: option == selected
                                ? colors.onPrimary
                                : colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (state.hasError) OutingError(state.errorText!),
          ],
        );
      },
    );
  }
}

/// A validation message in the same place and style everywhere.
class OutingError extends StatelessWidget {
  const OutingError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Instrument Sans',
        fontSize: 12,
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

/// A day, and optionally a time of day, chosen with the platform's pickers.
///
/// The same shape as the skip planner's Leaving / Back on: the date reads as the
/// field and the time is its own pill beside it, so either can be changed alone.
/// Pass [timeLabel] null for a date-only field.
class OutingMomentField extends StatelessWidget {
  const OutingMomentField({
    super.key,
    required this.label,
    required this.date,
    required this.onDate,
    required this.validator,
    this.time,
    this.onTime,
    this.firstDate,
    this.lastDate,
    this.selectableDayPredicate,
    this.timeValidator,
    this.timeEnabled = false,
  });

  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onDate;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay>? onTime;

  /// Whether this field also asks for a time.
  final bool timeEnabled;

  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool Function(DateTime)? selectableDayPredicate;

  /// Return false to refuse a picked time (the caller says why).
  final bool Function(TimeOfDay)? timeValidator;

  /// Returns the error to show, or null when the field is complete.
  final String? Function() validator;

  Future<void> _pickDate(
    BuildContext context,
    FormFieldState<void> state,
  ) async {
    final picked = await CommonDatePicker.pick(
      context,
      selectedDate: date,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: selectableDayPredicate,
    );
    if (picked == null) return;
    onDate(picked);
    // Tells the form the field changed, which re-checks it and clears a message
    // that no longer applies.
    state.didChange(null);
  }

  Future<void> _pickTime(
    BuildContext context,
    FormFieldState<void> state,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time ?? TimeOfDay.now(),
      helpText: label,
    );
    if (picked == null) return;
    if (timeValidator != null && !timeValidator!(picked)) return;
    onTime?.call(picked);
    state.didChange(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FormField<void>(
      validator: (_) => validator(),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutingLabel(label),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context, state),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              date == null
                                  ? 'Select a date'
                                  : DateFormat('EEE, d MMM yyyy').format(date!),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Instrument Sans',
                                fontSize: 15,
                                color: date == null
                                    ? colors.onSurfaceVariant
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (timeEnabled) ...[
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _pickTime(context, state),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            time == null ? 'Time' : time!.format(context),
                            style: TextStyle(
                              fontFamily: 'Instrument Sans',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: time == null
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (state.hasError) OutingError(state.errorText!),
          ],
        );
      },
    );
  }
}

/// The two actions under a form: apply, and the history of past applications.
class OutingActions extends StatelessWidget {
  const OutingActions({
    super.key,
    required this.loading,
    required this.canApply,
    required this.onApply,
    required this.onHistory,
  });

  final bool loading;

  /// False for the demo account: applying is a write to VTOP.
  final bool canApply;
  final VoidCallback onApply;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (canApply)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: loading ? null : onApply,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                disabledBackgroundColor: colors.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : const Text(
                      'Apply',
                      style: TextStyle(
                        fontFamily: 'Instrument Sans',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        if (canApply) const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton.icon(
            onPressed: onHistory,
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text(
              'Past applications',
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
