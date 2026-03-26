import 'package:flutter/widgets.dart';

class ResponsiveBreakpoints {
  const ResponsiveBreakpoints._();

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 720;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 720 && width < 1200;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1200;
}
