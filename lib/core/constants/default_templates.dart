import 'package:flutter/material.dart';
import '../../models/slide_model.dart';
import '../../core/theme/palette.dart';

// These use the new capabilities (VerticalAlign, Bold, etc)
// ignore: non_constant_identifier_names
final List<SlideTemplate> kDefaultTemplates = [
  // --- BASICS ---
  SlideTemplate(
    id: 'default',
    name: 'Default',
    textColor: Colors.white,
    background: Colors.black,
    overlayAccent: AppPalette.dustyMauve,
    fontSize: 50,
    alignment: TextAlign.center,
    isBold: false,
  ),
  SlideTemplate(
    id: 'default_bold',
    name: 'Default Bold',
    textColor: Colors.white,
    background: Colors.black,
    overlayAccent: AppPalette.dustyMauve,
    fontSize: 50,
    alignment: TextAlign.center,
    isBold: true,
  ),

  // --- BIG ---
  SlideTemplate(
    id: 'big',
    name: 'Big',
    textColor: Colors.white,
    background: Colors.black,
    overlayAccent: Colors.transparent,
    fontSize: 90,
    alignment: TextAlign.center,
    isBold: false,
  ),
  SlideTemplate(
    id: 'big_bold',
    name: 'Big Bold',
    textColor: Colors.white,
    background: Colors.black,
    overlayAccent: Colors.transparent,
    fontSize: 90,
    alignment: TextAlign.center,
    isBold: true,
  ),

  // --- HEADER ---
  SlideTemplate(
    id: 'header',
    name: 'Header',
    textColor: Colors.white,
    background: Colors.transparent,
    overlayAccent: Colors.transparent,
    fontSize: 60,
    alignment: TextAlign.center,
    verticalAlign: VerticalAlign.top,
    isBold: true,
  ),

  // --- LOWER THIRDS ---
  SlideTemplate(
    id: 'lower_third',
    name: 'Lower Third',
    textColor: Colors.white,
    background: Colors.transparent,
    overlayAccent: Colors.black.withOpacity(0.8),
    fontSize: 32,
    alignment: TextAlign.center,
    verticalAlign: VerticalAlign.bottom,
  ),
  SlideTemplate(
    id: 'lower_third_blue',
    name: 'Lower Third Blue',
    textColor: Colors.white,
    background: Colors.transparent,
    overlayAccent: Colors.blue.withOpacity(0.8),
    fontSize: 32,
    alignment: TextAlign.center,
    verticalAlign: VerticalAlign.bottom,
  ),
  SlideTemplate(
    id: 'lower_third_pastel',
    name: 'Lower Third Pastel',
    textColor: Colors.black87,
    background: Colors.transparent,
    overlayAccent: const Color(0xFFB39DDB).withOpacity(0.9), // Pastel Purple
    fontSize: 32,
    alignment: TextAlign.center,
    verticalAlign: VerticalAlign.bottom,
  ),
  SlideTemplate(
    id: 'lower_third_white',
    name: 'Lower Third White',
    textColor: Colors.black,
    background: Colors.transparent,
    overlayAccent: Colors.white.withOpacity(0.9),
    fontSize: 32,
    alignment: TextAlign.center,
    verticalAlign: VerticalAlign.bottom,
  ),

  // --- SPECIFIC ---
  SlideTemplate(
    id: 'scripture',
    name: 'Scripture',
    textColor: const Color(0xFFE0E0E0),
    background: const Color(0xFF121212),
    overlayAccent: Colors.transparent,
    fontSize: 38,
    alignment: TextAlign.left,
  ),
  SlideTemplate(
    id: 'bullets',
    name: 'Bullets',
    textColor: Colors.white,
    background: Colors.black,
    overlayAccent: Colors.transparent,
    fontSize: 40,
    alignment: TextAlign.left,
    verticalAlign: VerticalAlign.middle,
  ),
  SlideTemplate(
    id: 'message',
    name: 'Message Notes',
    textColor: Colors.black87,
    background: const Color(0xFFF5F5F7),
    overlayAccent: AppPalette.willowGreen,
    fontSize: 42,
    alignment: TextAlign.left,
  ),
  SlideTemplate(
    id: 'countdown',
    name: 'Countdown',
    textColor: Colors.white,
    background: Colors.black,
    overlayAccent: Colors.transparent,
    fontSize: 120,
    alignment: TextAlign.center,
    isBold: true,
  ),
];
