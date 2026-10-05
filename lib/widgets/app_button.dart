import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

enum AppButtonVariant {
  /// Giallo: l'azione principale della schermata.
  primary,

  /// Bianco con bordo menta: azione secondaria accanto alla principale.
  secondary,

  /// Viola: azioni della community (voti).
  community,

  /// Verde brand.
  green,
}

/// Pulsante "a rilievo" del redesign: sotto ha un bordo pieno più scuro
/// che sparisce quando lo premi, come un tasto che si abbassa.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.badge,
    this.variant = AppButtonVariant.primary,
    this.height = 60,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Pillola a destra dell'etichetta, es. "+1 pt".
  final String? badge;
  final AppButtonVariant variant;
  final double height;
  final bool loading;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  static const _edge = 4.0;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  ({Color bg, Color fg, Color edge}) _colors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_enabled && !widget.loading) {
      return (
        bg: isDark ? context.palette.divider : AppColors.mintBorder,
        fg: context.palette.textDisabled,
        edge: Colors.transparent,
      );
    }
    return switch (widget.variant) {
      AppButtonVariant.primary => (
        bg: AppColors.yellow,
        fg: AppColors.onYellow,
        edge: AppColors.yellowEdge,
      ),
      AppButtonVariant.secondary => (
        bg: context.palette.surfaceWhite,
        fg: isDark ? context.palette.textPrimary : AppColors.greenDark,
        edge: isDark ? context.palette.divider : AppColors.mintBorder,
      ),
      AppButtonVariant.community => (
        bg: AppColors.purple,
        fg: Colors.white,
        edge: AppColors.purpleDark,
      ),
      AppButtonVariant.green => (
        bg: AppColors.greenBrand,
        fg: Colors.white,
        edge: AppColors.greenDark,
      ),
    };
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors(context);
    final radius = BorderRadius.circular(18);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final down = _pressed && _enabled;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: c.fg),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 22, color: c.fg),
        if (widget.loading || widget.icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.fg,
              height: 1.15,
            ),
          ),
        ),
        if (widget.badge != null) ...[
          const SizedBox(width: 8),
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.fg.withAlpha(30),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.badge!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: c.fg,
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? '${widget.label}, in corso' : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapCancel: () => _setPressed(false),
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTap: _enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: SizedBox(
          height: widget.height + _edge,
          child: Align(
            alignment: Alignment.topCenter,
            widthFactor: widget.expand ? null : 1,
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              margin: EdgeInsets.only(top: down ? _edge : 0),
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(color: c.edge, offset: Offset(0, down ? 0 : _edge)),
                ],
              ),
              child: ExcludeSemantics(
                excluding: widget.loading,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
