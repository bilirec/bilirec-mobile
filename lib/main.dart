import 'dart:async';

import 'package:bilirec/app/home_page.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  runApp(const BilirecApp());
}

class BilirecApp extends StatefulWidget {
  const BilirecApp({super.key});

  @override
  State<BilirecApp> createState() => _BilirecAppState();
}

class _BilirecAppState extends State<BilirecApp> {
  Locale _locale = _devicePreferredLocale();

  static Locale _devicePreferredLocale() {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    return AppLocaleConfig.codeForLocale(deviceLocale) ==
            AppLocaleConfig.simplifiedCode
        ? AppLocaleConfig.simplifiedLocale
        : AppLocaleConfig.traditionalLocale;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final code = await Preferences.getLocaleCode();
    if (code == null || !mounted) return;
    setState(() {
      _locale = AppLocaleConfig.localeForCode(code);
    });
  }

  Future<void> _setLocale(Locale locale) async {
    final code = AppLocaleConfig.codeForLocale(locale);
    await Preferences.setLocaleCode(code);
    if (!mounted) return;
    setState(() {
      _locale = AppLocaleConfig.localeForCode(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bilirec',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8EDBFF)),
        useMaterial3: true,
      ),
      home: BilirecHomePage(
        currentLocale: _locale,
        onLocaleChanged: _setLocale,
      ),
    );
  }
}
