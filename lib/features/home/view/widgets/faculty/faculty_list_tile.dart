import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/utils/faculty_name.dart';
import 'package:vit_ap_student_app/features/home/model/faculty.dart';

class FacultyListTile extends StatelessWidget {
  final FacultyListItem faculty;
  final VoidCallback onTap;

  const FacultyListTile({
    super.key,
    required this.faculty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The faculty directory is intentionally name-only. Full designation,
    // department, contact, and office details remain available after tap.
    final name = stripFacultyTitle(faculty.facultyName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
