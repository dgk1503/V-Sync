import 'package:flutter/material.dart';

class ErrorContentView extends StatelessWidget {
  final String error;
  const ErrorContentView({required this.error, super.key});

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
              'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
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
