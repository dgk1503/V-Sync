import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_ap_student_app/core/common/widget/loader.dart';
import 'package:vit_ap_student_app/core/models/user.dart';
import 'package:vit_ap_student_app/core/providers/current_user.dart';
import 'package:vit_ap_student_app/features/auth/view/pages/semester_selection_page.dart';
import 'package:vit_ap_student_app/features/auth/viewmodel/semester_viewmodel.dart';

class ProfileCard extends ConsumerStatefulWidget {
  final User? user;
  final bool isProfile;
  const ProfileCard({super.key, this.isProfile = false, required this.user});

  @override
  ConsumerState<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<ProfileCard> {
  String? _selectedSemesterName;

  @override
  void initState() {
    super.initState();
    _loadSelectedSemester();
  }

  Future<void> _loadSelectedSemester() async {
    final semester = await ref
        .read(semesterViewModelProvider.notifier)
        .getSelectedSemester();
    if (mounted && semester != null) {
      setState(() {
        _selectedSemesterName = semester.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      semesterViewModelProvider.select((val) => val?.isLoading == true),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Text(
                (widget.user?.profile.target?.studentName ?? '?')
                    .trim()
                    .substring(0, 1)
                    .toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.user?.profile.target?.studentName ?? 'N/A',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (!widget.isProfile) ...[
              if (isLoading) ...[
                const Loader(),
              ] else ...[
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                  ),
                  child: Text(
                    _selectedSemesterName ?? 'Select Semester',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                TextButton(
                  style: const ButtonStyle(),
                  onPressed: () async {
                    final credentials = await ref
                        .read(currentUserProvider.notifier)
                        .getSavedCredentials();
                    if (credentials == null || !context.mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => SemesterSelectionPage(
                          registrationNumber: credentials.registrationNumber,
                          password: credentials.password,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    await _loadSelectedSemester();
                  },
                  child: const Text(
                    'Change semster',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
