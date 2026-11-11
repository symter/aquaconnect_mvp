import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app is designed mobile-first (390px). Phones and portrait tablets
/// (up to [maxWidth]) use the full width; on a wider window the app sits in
/// a centered column of [maxWidth] instead of stretching edge-to-edge.
///
/// Inside the column, [MediaQuery] reports the column's width, so bottom
/// sheets, dialogs and anything sized from the screen fit the column rather
/// than the whole window.
class ResponsiveMobileFrame extends StatelessWidget {
  const ResponsiveMobileFrame({super.key, required this.child, this.maxWidth = contentWidth});

  final Widget child;
  final double maxWidth;

  /// Every screen, the calendar included.
  static const double contentWidth = 800;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth <= maxWidth) return child;
      final mq = MediaQuery.of(context);
      return ColoredBox(
        color: AppColors.divider,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.background,
                boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 24)],
              ),
              child: MediaQuery(
                data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
                child: child,
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Keeps a form (login, signup, invite) at a readable width on wide
/// screens, centered horizontally, while still filling the height.
class FormWidth extends StatelessWidget {
  const FormWidth({super.key, required this.child, this.maxWidth = 480});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth <= maxWidth) return child;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: (box.maxWidth - maxWidth) / 2),
        child: child,
      );
    });
  }
}
