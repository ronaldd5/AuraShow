import 'package:flutter/material.dart';
import '../../../core/theme/palette.dart';

/// Model representing a slide for projection in the output window.
///
/// Contains all styling and content information needed to render
/// a slide on a secondary display.
class ProjectionSlide {
  ProjectionSlide({
    required this.body,
    required this.templateTextColor,
    required this.templateBackground,
    required this.templateFontSize,
    required this.templateAlign,
    this.fontSizeOverride,
    this.fontFamilyOverride,
    this.textColorOverride,
    this.alignOverride,
    this.lineHeight,
    this.letterSpacing,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.shadowColor,
    this.shadowBlur,
    this.shadowOffsetX,
    this.shadowOffsetY,
    this.outlineColor,
    this.outlineWidth,
    this.boxPadding,
    this.boxBorderRadius,
    this.boxBackgroundColor,
    this.textTransform,
    this.boxLeft,
    this.boxTop,
    this.boxWidth,
    this.boxHeight,
    this.backgroundColor,
    this.mediaPath,
    this.mediaType,
    this.mediaOpacity,
    this.hueRotate,
    this.invert,
    this.blur,
    this.brightness,
    this.contrast,
    this.saturate,
    this.rotation,
    List<ProjectionLayer>? layers,
  }) : layers = layers ?? const [];

  final String body;
  final Color templateTextColor;
  final Color templateBackground;
  final double templateFontSize;
  final TextAlign templateAlign;

  final double? fontSizeOverride;
  final String? fontFamilyOverride;
  final Color? textColorOverride;
  final TextAlign? alignOverride;
  final double? lineHeight;
  final double? letterSpacing;
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final Color? shadowColor;
  final double? shadowBlur;
  final double? shadowOffsetX;
  final double? shadowOffsetY;
  final Color? outlineColor;
  final double? outlineWidth;
  final double? boxPadding;
  final double? boxBorderRadius;
  final Color? boxBackgroundColor;
  final String? textTransform;
  final double? boxLeft;
  final double? boxTop;
  final double? boxWidth;
  final double? boxHeight;
  final Color? backgroundColor;
  final String? mediaPath;
  final String? mediaType;
  final double? mediaOpacity;
  final double? hueRotate;
  final double? invert;
  final double? blur;
  final double? brightness;
  final double? contrast;
  final double? saturate;
  final double? rotation;
  final List<ProjectionLayer> layers;

  factory ProjectionSlide.fromJson(Map<String, dynamic> json) {
    Color? parseColor(dynamic v) => v == null ? null : Color(v as int);
    double? numToDouble(dynamic v) => (v as num?)?.toDouble();

    return ProjectionSlide(
      body: json['body'] ?? '',
      templateTextColor: parseColor(json['templateTextColor']) ?? Colors.white,
      templateBackground:
          parseColor(json['templateBackground']) ?? AppPalette.carbonBlack,
      templateFontSize: numToDouble(json['templateFontSize']) ?? 38,
      templateAlign: TextAlign.values.firstWhere(
        (e) => e.name == (json['templateAlign'] ?? 'center'),
        orElse: () => TextAlign.center,
      ),
      fontSizeOverride: numToDouble(json['fontSizeOverride']),
      fontFamilyOverride: json['fontFamilyOverride'] as String?,
      textColorOverride: parseColor(json['textColorOverride']),
      alignOverride: json['alignOverride'] != null
          ? TextAlign.values.firstWhere(
              (e) => e.name == json['alignOverride'],
              orElse: () => TextAlign.center,
            )
          : null,
      lineHeight: numToDouble(json['lineHeight']),
      letterSpacing: numToDouble(json['letterSpacing']),
      isBold: json['isBold'] as bool?,
      isItalic: json['isItalic'] as bool?,
      isUnderline: json['isUnderline'] as bool?,
      shadowColor: parseColor(json['shadowColor']),
      shadowBlur: numToDouble(json['shadowBlur']),
      shadowOffsetX: numToDouble(json['shadowOffsetX']),
      shadowOffsetY: numToDouble(json['shadowOffsetY']),
      outlineColor: parseColor(json['outlineColor']),
      outlineWidth: numToDouble(json['outlineWidth']),
      boxPadding: numToDouble(json['boxPadding']),
      boxBorderRadius: numToDouble(json['boxBorderRadius']),
      boxBackgroundColor: parseColor(json['boxBackgroundColor']),
      textTransform: json['textTransform'] as String?,
      boxLeft: numToDouble(json['boxLeft']),
      boxTop: numToDouble(json['boxTop']),
      boxWidth: numToDouble(json['boxWidth']),
      boxHeight: numToDouble(json['boxHeight']),
      backgroundColor: parseColor(json['backgroundColor']),
      mediaPath: json['mediaPath'] as String?,
      mediaType: json['mediaType'] as String?,
      mediaOpacity: numToDouble(json['mediaOpacity']) ?? 1.0,
      hueRotate: numToDouble(json['hueRotate']),
      invert: numToDouble(json['invert']),
      blur: numToDouble(json['blur']),
      brightness: numToDouble(json['brightness']),
      contrast: numToDouble(json['contrast']),
      saturate: numToDouble(json['saturate']),
      rotation: numToDouble(json['rotation']),
      layers: () {
        debugPrint(
          'proj: parsing layers, json[layers]=${json['layers']?.runtimeType} length=${(json['layers'] as List?)?.length ?? 0}',
        );
        return (json['layers'] as List?)
                ?.map(
                  (e) => ProjectionLayer.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            const [];
      }(),
    );
  }
}

/// Model representing a single layer in a projection slide.
///
/// Layers can be either media (image/video) or text content,
/// positioned at normalized coordinates (0-1) on the stage.
class ProjectionLayer {
  ProjectionLayer({
    required this.kind,
    required this.role,
    this.text,
    this.path,
    this.mediaType,
    this.left,
    this.top,
    this.width,
    this.height,
    this.opacity,
    this.fit,
    this.fontSize,
    this.fontFamily,
    this.textColor,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.align,
    this.boxColor,
    this.boxPadding,
    this.boxBorderRadius,
    this.outlineWidth,
    this.outlineColor,
    this.rotation,
    this.shaderId,
    this.shaderParams,
    this.qrData,
    this.qrForegroundColor,
    this.qrBackgroundColor,
    // Scripture
    this.scriptureReference,
    this.highlightedIndices,
    // Clock
    this.clockType,
    this.clockShowSeconds,
    this.clock24Hour,
    // Weather
    this.weatherCity,
    this.weatherCelsius,
    this.weatherShowCondition,
    this.weatherShowHumidity,
    this.weatherShowWind,
    this.weatherShowFeelsLike,
    // Visualizer
    this.visualizerType,
    this.visualizerBarCount,
    this.visualizerSensitivity,
    this.visualizerSmoothing,
    this.visualizerColor1,
    this.visualizerColor2,
    this.visualizerMirror,
    this.visualizerGlow,
    this.visualizerGlowIntensity,
    this.visualizerColorMode,
    this.visualizerLineWidth,
    this.visualizerGap,
    this.visualizerRadius,
    this.visualizerRotationSpeed,
    this.visualizerShape,
    this.visualizerFilled,
    this.visualizerMinHeight,
    this.visualizerFrequencyRange,
    this.visualizerAudioSource,
    this.visualizerPreviewMode,
  });

  /// The kind of layer: 'media' or 'textbox'
  final String kind;

  /// The role of the layer: 'background' or 'foreground'
  final String role;

  /// Text content for textbox layers
  final String? text;

  /// File path for media layers
  final String? path;

  /// Media type: 'image' or 'video'
  final String? mediaType;

  /// Normalized left position (0-1)
  final double? left;

  /// Normalized top position (0-1)
  final double? top;

  /// Normalized width (0-1)
  final double? width;

  /// Normalized height (0-1)
  final double? height;

  /// Layer opacity (0-1)
  final double? opacity;

  /// Fit mode: 'cover', 'contain', etc.
  final String? fit;

  // Text styling overrides
  final double? fontSize;
  final String? fontFamily;
  final Color? textColor;
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final TextAlign? align;
  final Color? boxColor;
  final double? boxPadding;
  final double? boxBorderRadius;
  final double? outlineWidth;
  final Color? outlineColor;
  final double? rotation;
  final String? shaderId;
  final Map<String, double>? shaderParams;
  final String? qrData;
  final Color? qrForegroundColor;
  final Color? qrBackgroundColor;
  // Scripture
  final String? scriptureReference;
  final List<int>? highlightedIndices;

  // Clock
  final String? clockType;
  final bool? clockShowSeconds;
  final bool? clock24Hour;

  // Weather
  final String? weatherCity;
  final bool? weatherCelsius;
  final bool? weatherShowCondition;
  final bool? weatherShowHumidity;
  final bool? weatherShowWind;
  final bool? weatherShowFeelsLike;

  // Visualizer
  final String? visualizerType;
  final int? visualizerBarCount;
  final double? visualizerSensitivity;
  final double? visualizerSmoothing;
  final Color? visualizerColor1;
  final Color? visualizerColor2;
  final bool? visualizerMirror;
  final bool? visualizerGlow;
  final double? visualizerGlowIntensity;
  final String? visualizerColorMode;
  final double? visualizerLineWidth;
  final double? visualizerGap;
  final double? visualizerRadius;
  final double? visualizerRotationSpeed;
  final String? visualizerShape;
  final bool? visualizerFilled;
  final double? visualizerMinHeight;
  final String? visualizerFrequencyRange;
  final String? visualizerAudioSource;
  final bool? visualizerPreviewMode;

  factory ProjectionLayer.fromJson(Map<String, dynamic> json) {
    double? numToDouble(dynamic v) => (v as num?)?.toDouble();

    return ProjectionLayer(
      kind: json['kind'] as String? ?? 'media',
      role: json['role'] as String? ?? 'foreground',
      text: json['text'] as String?,
      path: json['path'] as String?,
      mediaType: json['mediaType'] as String?,
      left: numToDouble(json['left']),
      top: numToDouble(json['top']),
      width: numToDouble(json['width']),
      height: numToDouble(json['height']),
      opacity: numToDouble(json['opacity']) ?? 1.0,
      fit: json['fit'] as String?,
      fontSize: numToDouble(json['fontSize']),
      fontFamily: json['fontFamily'] as String?,
      textColor: json['textColor'] != null ? Color(json['textColor']) : null,
      isBold: json['isBold'] as bool?,
      isItalic: json['isItalic'] as bool?,
      isUnderline: json['isUnderline'] as bool?,
      align: json['align'] != null
          ? TextAlign.values.firstWhere(
              (e) => e.name == json['align'],
              orElse: () => TextAlign.center,
            )
          : null,
      boxColor: json['boxColor'] != null ? Color(json['boxColor']) : null,
      boxPadding: numToDouble(json['boxPadding']),
      boxBorderRadius: numToDouble(json['boxBorderRadius']),
      outlineWidth: numToDouble(json['outlineWidth']),
      outlineColor: json['outlineColor'] != null
          ? Color(json['outlineColor'])
          : null,
      rotation: numToDouble(json['rotation']),
      shaderId: json['shaderId'] as String?,
      shaderParams: (json['shaderParams'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      qrData: json['qrData'] as String?,
      qrForegroundColor: json['qrForegroundColor'] != null
          ? Color(json['qrForegroundColor'])
          : null,
      qrBackgroundColor: json['qrBackgroundColor'] != null
          ? Color(json['qrBackgroundColor'])
          : null,
      scriptureReference: json['scriptureReference'] as String?,
      highlightedIndices: (json['highlightedIndices'] as List?)
          ?.map((e) => e as int)
          .toList(),
      clockType: json['clockType'] as String?,
      clockShowSeconds: json['clockShowSeconds'] as bool?,
      clock24Hour: json['clock24Hour'] as bool?,
      weatherCity: json['weatherCity'] as String?,
      weatherCelsius: json['weatherCelsius'] as bool?,
      weatherShowCondition: json['weatherShowCondition'] as bool?,
      weatherShowHumidity: json['weatherShowHumidity'] as bool?,
      weatherShowWind: json['weatherShowWind'] as bool?,
      weatherShowFeelsLike: json['weatherShowFeelsLike'] as bool?,
      // Visualizer
      visualizerType: json['visualizerType'] as String?,
      visualizerBarCount: (json['visualizerBarCount'] as num?)?.toInt(),
      visualizerSensitivity: numToDouble(json['visualizerSensitivity']),
      visualizerSmoothing: numToDouble(json['visualizerSmoothing']),
      visualizerColor1: json['visualizerColor1'] != null
          ? Color(json['visualizerColor1'])
          : null,
      visualizerColor2: json['visualizerColor2'] != null
          ? Color(json['visualizerColor2'])
          : null,
      visualizerMirror: json['visualizerMirror'] as bool?,
      visualizerGlow: json['visualizerGlow'] as bool?,
      visualizerGlowIntensity: numToDouble(json['visualizerGlowIntensity']),
      visualizerColorMode: json['visualizerColorMode'] as String?,
      visualizerLineWidth: numToDouble(json['visualizerLineWidth']),
      visualizerGap: numToDouble(json['visualizerGap']),
      visualizerRadius: numToDouble(json['visualizerRadius']),
      visualizerRotationSpeed: numToDouble(json['visualizerRotationSpeed']),
      visualizerShape: json['visualizerShape'] as String?,
      visualizerFilled: json['visualizerFilled'] as bool?,
      visualizerMinHeight: numToDouble(json['visualizerMinHeight']),
      visualizerFrequencyRange: json['visualizerFrequencyRange'] as String?,
      visualizerAudioSource: json['visualizerAudioSource'] as String?,
      visualizerPreviewMode: json['visualizerPreviewMode'] as bool?,
    );
  }
}
