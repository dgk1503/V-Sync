import 'package:flutter/material.dart';

class EmptyContentView extends StatelessWidget {
  final String primaryText;
  final String secondaryText;

  const EmptyContentView({
    super.key,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              primaryText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              secondaryText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
