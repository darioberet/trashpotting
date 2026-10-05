import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Campo del redesign: etichetta sopra, icona a sinistra, bordo menta che
/// diventa verde con un alone quando il campo è attivo.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.icon,
    this.controller,
    this.focusNode,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.validator,
    this.autofillHints,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;

  /// Azione a destra, es. "mostra password".
  final Widget? suffix;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              height: 16 / 13,
              fontWeight: FontWeight.w700,
              color: focused ? AppColors.greenDark : AppColors.textSecondary,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: focused ? AppColors.greenLight : Colors.transparent,
                spreadRadius: 4,
              ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            onChanged: widget.onChanged,
            validator: widget.validator,
            autofillHints: widget.autofillHints,
            textCapitalization: widget.textCapitalization,
            maxLength: widget.maxLength,
            autofocus: widget.autofocus,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.hintText,
              counterText: '',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(widget.icon, size: 20),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              suffixIcon: widget.suffix,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
