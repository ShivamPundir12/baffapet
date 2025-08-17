import 'package:baffapet/app/theme_dark.dart';
import 'package:baffapet/app/theme_light.dart';
import 'package:baffapet/webview/webview_screen.dart';
import 'package:flutter/material.dart';

class WebAppShell extends StatelessWidget {
  const WebAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bafapet',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const WebHomePage(),
    );
  }
}
