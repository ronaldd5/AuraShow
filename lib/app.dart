import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/palette.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'widgets/native_menu_wrapper.dart';

/// The main AuraShow application widget.
///
/// This configures the app theme and provides the root MaterialApp
/// with dark theme styling and the DashboardScreen as the home.
class AuraShowApp extends StatelessWidget {
  const AuraShowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return NativeMenuWrapper(
      child: MaterialApp(
        title: 'AuraShow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppPalette.carbonBlack,
          colorScheme: ColorScheme.dark(
            primary: AppPalette.dustyMauve,
            secondary: AppPalette.dustyRose,
            surface: AppPalette.carbonBlack,
            background: AppPalette.carbonBlack,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.white,
            onBackground: Colors.white,
          ).copyWith(tertiary: AppPalette.willowGreen),
          textTheme: GoogleFonts.outfitTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme,
          ).apply(bodyColor: Colors.white, displayColor: Colors.white),
          useMaterial3: true,
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
