import 'package:flutter/material.dart';

/// Monochrome initial avatar used for faculty entries: the first letter
/// of the name on a neutral surface chip. Colors follow the active theme
/// so it stays black & white (or theme-accented) across all palettes.
class UserIcon extends StatelessWidget {
  final String name;
  const UserIcon({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final facultyName = name.trim();

    if (facultyName.isEmpty) {
      return const CircleAvatar(child: Text('N/A'));
    }

    final String firstLetter = facultyName.characters.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 50,
        width: 50,
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            firstLetter,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ),
    );
  }
}
