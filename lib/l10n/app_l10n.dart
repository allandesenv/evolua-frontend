import 'package:evolua_frontend/l10n/generated/app_localizations.dart';
import 'package:evolua_frontend/l10n/generated/app_localizations_pt.dart';
import 'package:flutter/widgets.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsPtBr();
}
