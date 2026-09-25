import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class AuthField extends StatefulWidget {
  final String? title;
  final String hintText;
  final TextEditingController controller;
  final bool isObscureText;

  const AuthField({
    super.key,
    this.title,
    required this.hintText,
    required this.controller,
    this.isObscureText = false,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isObscureText;
  }

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AutofillGroup(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (widget.title ?? widget.hintText).toUpperCase(),
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.controller,
            style: TextStyle(
              fontFamily: 'Instrument Sans',
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontFamily: 'Instrument Sans',
                fontSize: 13.5,
                color: colorScheme.onSurfaceVariant,
              ),
              prefixIcon: widget.isObscureText
                  ? Icon(Iconsax.lock_1, size: 19, color: colorScheme.onSurfaceVariant)
                  : Icon(Iconsax.user, size: 19, color: colorScheme.onSurfaceVariant),
              suffixIcon: widget.isObscureText
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Iconsax.eye_slash : Iconsax.eye,
                        size: 19,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _toggleVisibility,
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            autofillHints: widget.isObscureText
                ? const [AutofillHints.password]
                : const [AutofillHints.username],
            validator: (value) {
              if (widget.isObscureText) {
                if (value!.isEmpty) {
                  return 'Password cannot be empty!';
                }
                if (value.length < 8) {
                  return '${widget.hintText} must be at least 8 characters!';
                }
                return null;
              } else {
                if (value!.isEmpty) {
                  return 'Username cannot be empty!';
                }
                if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(value)) {
                  return 'Username cannot contain special characters';
                }
                return null;
              }
            },
            obscureText: _obscureText,
          ),
        ],
      ),
    );
  }
}
