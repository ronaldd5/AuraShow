import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Shortcuts
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/palette.dart';
import 'screens/dashboard/controller/dashboard_controller.dart';
import 'screens/dashboard/dashboard_screen.dart';

class AuraShowApp extends StatelessWidget {
  const AuraShowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Native Menu Bar Wrapper
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'AuraShow',
          menus: [
            if (Platform.isMacOS)
              PlatformMenuItemGroup(
                members: [
                  PlatformMenuItem(
                    label: 'About AuraShow',
                    onSelected: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'AuraShow',
                        applicationVersion: '1.0.0',
                      );
                    },
                  ),
                  PlatformMenuItem(
                    label: 'Quit',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyQ,
                      meta: true,
                    ),
                    onSelected: () => exit(0),
                  ),
                ],
              ),
          ],
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'New Show',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
              ),
              onSelected: () {
                // Future: Hook up to DashboardController
              },
            ),
          ],
        ),
      ],
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DashboardController()),
        ],
        child: MaterialApp(
          title: 'AuraShow',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: AppPalette.primary,
            scaffoldBackgroundColor: AppPalette.background,
            useMaterial3: true,
            fontFamily: 'Inter',
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''),
            Locale('es', ''),
            Locale('fr', ''),
          ],
          home: const DashboardScreen(),
        ),
      ),
    );
  }
}
