import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
          final lightTextTheme = _urbanistTextTheme(Brightness.light);
          final darkTextTheme = _urbanistTextTheme(Brightness.dark);
          return MaterialApp(
            title: 'Mobile Taxi',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: buildLightTheme(lightTextTheme),
            darkTheme: buildDarkTheme(darkTextTheme),
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
            builder: (context, child) => ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                bottom: true,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            home: const RootShell(),
          );
        },
      ),
    );
  }
}

TextTheme _urbanistTextTheme(Brightness brightness) {
  final typography = Typography.material2021();
  final base = brightness == Brightness.dark
      ? typography.white
      : typography.black;
  return base.apply(fontFamily: 'Urbanist');
}
