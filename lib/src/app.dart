import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/design_tokens.dart';
import 'localization/app_localizations.dart';
import 'state/app_state.dart';
import 'ui/root_shell.dart';

class MobileTaxiApp extends StatelessWidget {
  const MobileTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Mobile Taxi',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: buildLightTheme(GoogleFonts.urbanistTextTheme()),
            darkTheme: buildDarkTheme(GoogleFonts.urbanistTextTheme()),
            themeAnimationDuration: AppDurations.long,
            themeAnimationCurve: Curves.easeInOutCubic,
            locale: state.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const RootShell(),
          );
        },
      ),
    );
  }
}
