import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Su schermi larghi (web da computer, tablet) l'app resta una colonna
/// centrale della larghezza di un telefono: le schermate sono pensate per
/// quella misura. Sotto [breakpoint] non cambia niente.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const breakpoint = 600.0;
  static const maxWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= breakpoint) return child;

    return ColoredBox(
      color: AppColors.forest,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          // Le schermate che leggono la larghezza dello schermo devono vedere
          // quella della colonna, non quella della finestra.
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
