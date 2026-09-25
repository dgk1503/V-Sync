import 'package:flutter/material.dart';

class UnknownContentView extends StatelessWidget {
  const UnknownContentView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Text(
          'This page does not exist',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Instrument Sans',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
