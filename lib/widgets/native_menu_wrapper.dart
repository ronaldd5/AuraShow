import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeMenuWrapper extends StatelessWidget {
  final Widget child;

  const NativeMenuWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Only Mac needs the top system menu
    if (!Platform.isMacOS) return child;

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
                ],
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
                // Hook this up to your DashboardController later
                debugPrint("New Show Clicked");
              },
            ),
          ],
        ),
        // Standard Edit Menu (Copy/Paste relies on system focus)
        const PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Undo',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                  ),
                  onSelected: null,
                ),
                PlatformMenuItem(
                  label: 'Redo',
                  shortcut: SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                    shift: true,
                  ),
                  onSelected: null,
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
