import 'package:flutter/material.dart';

import 'app_localizations.dart';

extension LocalizationExt on BuildContext {
  AppLocalizations get strings => AppLocalizations.of(this);
}
