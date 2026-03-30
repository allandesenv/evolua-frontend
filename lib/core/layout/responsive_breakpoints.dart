import 'package:flutter/widgets.dart';

class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) =>
      width(context) < 720;

  static bool isMedium(BuildContext context) {
    final currentWidth = width(context);
    return currentWidth >= 720 && currentWidth < 1200;
  }

  static bool isExpanded(BuildContext context) =>
      width(context) >= 1200;

  static double pagePadding(BuildContext context) {
    final currentWidth = width(context);
    if (currentWidth < 720) {
      return 16;
    }
    if (currentWidth < 1200) {
      return 20;
    }
    return 24;
  }

  static double panelPadding(BuildContext context) {
    return isCompact(context) ? 18 : 24;
  }

  static bool useStackedStats(BuildContext context) => width(context) < 860;
}
