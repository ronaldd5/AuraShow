import 'package:flutter/material.dart';
import '../core/theme/palette.dart';

enum SlideMediaType { image, video, audio }

enum LayerRole { background, foreground }

enum LayerKind {
  media,
  textbox,
  camera,
  screen,
  website,
  timer,
  clock,
  progress,
  events,
  weather,
  visualizer,
  captions,
  icon,
  shader,
  qr,
  scripture,
}

enum HandlePosition {
  topLeft,
  midTop,
  topRight,
  midLeft,
  midRight,
  bottomLeft,
  midBottom,
  bottomRight,
}

class SlideLayer {
  SlideLayer({
    required this.id,
    required this.label,
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
    DateTime? addedAt,
    // Style properties
    this.fontSize,
    this.fontFamily,
    this.textColor,
    this.align,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.boxPadding,
    this.boxColor,
    this.outlineColor,
    this.outlineWidth,

    this.boxBorderRadius,
    this.rotation,
    this.shaderId,
    this.shaderParams,
    // QR Code
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
    this.visualizerAudioSource, // 'app_audio', 'system_audio', 'microphone'
    this.visualizerPreviewMode, // true = show simulated data for editing
    this.visualizerAudioDevice, // Selected audio device ID
  }) : addedAt = addedAt ?? DateTime.now();

  final String id;
  final String label;
  final LayerKind kind;
  final String? text;
  final String? path;
  final SlideMediaType? mediaType;
  final LayerRole role;
  final double? left;
  final double? top;
  final double? width;
  final double? height;
  final double? opacity;
  final String? fit;
  final DateTime addedAt;

  // Style properties
  final double? fontSize;
  final String? fontFamily;
  final Color? textColor;
  final TextAlign? align;
  final bool? isBold;
  final bool? isItalic;
  final bool? isUnderline;
  final double? boxPadding;
  final Color? boxColor;
  final Color? outlineColor;
  final double? outlineWidth;
  final double? boxBorderRadius;
  final double? rotation;
  final String? shaderId;
  final Map<String, double>? shaderParams;

  // QR Code
  final String? qrData;
  final Color? qrForegroundColor;
  final Color? qrBackgroundColor;

  // Scripture
  final String? scriptureReference;
  final List<int>? highlightedIndices;

  // Clock
  final String? clockType; // 'digital' | 'analog'
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
  final String?
  visualizerType; // 'bars', 'waveform', 'circular', 'particles', 'spectrum'
  final int? visualizerBarCount; // Number of bars (8-128)
  final double? visualizerSensitivity; // Audio sensitivity (0.1-3.0)
  final double? visualizerSmoothing; // Animation smoothing (0.0-1.0)
  final Color? visualizerColor1; // Primary color
  final Color? visualizerColor2; // Secondary/gradient color
  final bool? visualizerMirror; // Mirror effect
  final bool? visualizerGlow; // Glow effect
  final double? visualizerGlowIntensity; // Glow strength (0.0-2.0)
  final String?
  visualizerColorMode; // 'solid', 'gradient', 'rainbow', 'reactive'
  final double? visualizerLineWidth; // Line/bar width
  final double? visualizerGap; // Gap between bars
  final double? visualizerRadius; // For circular visualizers
  final double? visualizerRotationSpeed; // Rotation speed for circular
  final String? visualizerShape; // 'rectangle', 'rounded', 'circle', 'triangle'
  final bool? visualizerFilled; // Filled or outline
  final double? visualizerMinHeight; // Minimum bar height
  final String? visualizerFrequencyRange; // 'bass', 'mid', 'treble', 'full'
  final String?
  visualizerAudioSource; // 'app_audio', 'system_audio', 'microphone'
  final bool? visualizerPreviewMode; // Preview mode for editing
  final String? visualizerAudioDevice; // Selected audio device ID

  bool get isMedia => kind == LayerKind.media && path != null;

  SlideLayer copyWith({
    String? id,
    String? label,
    LayerKind? kind,
    LayerRole? role,
    String? text,
    String? path,
    SlideMediaType? mediaType,
    double? left,
    double? top,
    double? width,
    double? height,
    double? opacity,
    String? fit,
    DateTime? addedAt,
    double? fontSize,
    String? fontFamily,
    Color? textColor,
    TextAlign? align,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    double? boxPadding,
    Color? boxColor,
    Color? outlineColor,
    double? outlineWidth,
    double? boxBorderRadius,
    double? rotation,
    String? shaderId,
    Map<String, double>? shaderParams,
    String? qrData,
    Color? qrForegroundColor,
    Color? qrBackgroundColor,
    String? scriptureReference,
    List<int>? highlightedIndices,
    String? clockType,
    bool? clockShowSeconds,
    bool? clock24Hour,
    String? weatherCity,
    bool? weatherCelsius,
    bool? weatherShowCondition,
    bool? weatherShowHumidity,
    bool? weatherShowWind,
    bool? weatherShowFeelsLike,
    // Visualizer
    String? visualizerType,
    int? visualizerBarCount,
    double? visualizerSensitivity,
    double? visualizerSmoothing,
    Color? visualizerColor1,
    Color? visualizerColor2,
    bool? visualizerMirror,
    bool? visualizerGlow,
    double? visualizerGlowIntensity,
    String? visualizerColorMode,
    double? visualizerLineWidth,
    double? visualizerGap,
    double? visualizerRadius,
    double? visualizerRotationSpeed,
    String? visualizerShape,
    bool? visualizerFilled,
    double? visualizerMinHeight,
    String? visualizerFrequencyRange,
    String? visualizerAudioSource,
    bool? visualizerPreviewMode,
    String? visualizerAudioDevice,
  }) {
    return SlideLayer(
      id: id ?? this.id,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      role: role ?? this.role,
      text: text ?? this.text,
      path: path ?? this.path,
      mediaType: mediaType ?? this.mediaType,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      opacity: opacity ?? this.opacity,
      fit: fit ?? this.fit,
      addedAt: addedAt ?? this.addedAt,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      textColor: textColor ?? this.textColor,
      align: align ?? this.align,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      boxPadding: boxPadding ?? this.boxPadding,
      boxColor: boxColor ?? this.boxColor,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      boxBorderRadius: boxBorderRadius ?? this.boxBorderRadius,
      rotation: rotation ?? this.rotation,
      shaderId: shaderId ?? this.shaderId,
      shaderParams: shaderParams ?? this.shaderParams,
      qrData: qrData ?? this.qrData,
      qrForegroundColor: qrForegroundColor ?? this.qrForegroundColor,
      qrBackgroundColor: qrBackgroundColor ?? this.qrBackgroundColor,
      scriptureReference: scriptureReference ?? this.scriptureReference,
      highlightedIndices: highlightedIndices ?? this.highlightedIndices,
      clockType: clockType ?? this.clockType,
      clockShowSeconds: clockShowSeconds ?? this.clockShowSeconds,
      clock24Hour: clock24Hour ?? this.clock24Hour,
      weatherCity: weatherCity ?? this.weatherCity,
      weatherCelsius: weatherCelsius ?? this.weatherCelsius,
      weatherShowCondition: weatherShowCondition ?? this.weatherShowCondition,
      weatherShowHumidity: weatherShowHumidity ?? this.weatherShowHumidity,
      weatherShowWind: weatherShowWind ?? this.weatherShowWind,
      weatherShowFeelsLike: weatherShowFeelsLike ?? this.weatherShowFeelsLike,
      visualizerType: visualizerType ?? this.visualizerType,
      visualizerBarCount: visualizerBarCount ?? this.visualizerBarCount,
      visualizerSensitivity:
          visualizerSensitivity ?? this.visualizerSensitivity,
      visualizerSmoothing: visualizerSmoothing ?? this.visualizerSmoothing,
      visualizerColor1: visualizerColor1 ?? this.visualizerColor1,
      visualizerColor2: visualizerColor2 ?? this.visualizerColor2,
      visualizerMirror: visualizerMirror ?? this.visualizerMirror,
      visualizerGlow: visualizerGlow ?? this.visualizerGlow,
      visualizerGlowIntensity:
          visualizerGlowIntensity ?? this.visualizerGlowIntensity,
      visualizerColorMode: visualizerColorMode ?? this.visualizerColorMode,
      visualizerLineWidth: visualizerLineWidth ?? this.visualizerLineWidth,
      visualizerGap: visualizerGap ?? this.visualizerGap,
      visualizerRadius: visualizerRadius ?? this.visualizerRadius,
      visualizerRotationSpeed:
          visualizerRotationSpeed ?? this.visualizerRotationSpeed,
      visualizerShape: visualizerShape ?? this.visualizerShape,
      visualizerFilled: visualizerFilled ?? this.visualizerFilled,
      visualizerMinHeight: visualizerMinHeight ?? this.visualizerMinHeight,
      visualizerFrequencyRange:
          visualizerFrequencyRange ?? this.visualizerFrequencyRange,
      visualizerAudioSource:
          visualizerAudioSource ?? this.visualizerAudioSource,
      visualizerPreviewMode:
          visualizerPreviewMode ?? this.visualizerPreviewMode,
      visualizerAudioDevice:
          visualizerAudioDevice ?? this.visualizerAudioDevice,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.name,
    'role': role.name,
    'text': text,
    'path': path,
    'mediaType': mediaType?.name,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'opacity': opacity,
    'fit': fit,
    'addedAt': addedAt.millisecondsSinceEpoch,
    'fontSize': fontSize,
    'fontFamily': fontFamily,
    'textColor': textColor?.value,
    'align': align?.name,
    'isBold': isBold,
    'isItalic': isItalic,
    'isUnderline': isUnderline,
    'boxPadding': boxPadding,
    'boxColor': boxColor?.value,
    'outlineColor': outlineColor?.value,
    'outlineWidth': outlineWidth,
    'boxBorderRadius': boxBorderRadius,
    'rotation': rotation,
    'shaderId': shaderId,
    'shaderParams': shaderParams,
    'qrData': qrData,
    'qrForegroundColor': qrForegroundColor?.value,
    'qrBackgroundColor': qrBackgroundColor?.value,
    'clockType': clockType,
    'clockShowSeconds': clockShowSeconds,
    'clock24Hour': clock24Hour,
    'weatherCity': weatherCity,
    'weatherCelsius': weatherCelsius,
    'weatherShowCondition': weatherShowCondition,
    'weatherShowHumidity': weatherShowHumidity,
    'weatherShowWind': weatherShowWind,
    'weatherShowFeelsLike': weatherShowFeelsLike,
    // Visualizer
    'visualizerType': visualizerType,
    'visualizerBarCount': visualizerBarCount,
    'visualizerSensitivity': visualizerSensitivity,
    'visualizerSmoothing': visualizerSmoothing,
    'visualizerColor1': visualizerColor1?.value,
    'visualizerColor2': visualizerColor2?.value,
    'visualizerMirror': visualizerMirror,
    'visualizerGlow': visualizerGlow,
    'visualizerGlowIntensity': visualizerGlowIntensity,
    'visualizerColorMode': visualizerColorMode,
    'visualizerLineWidth': visualizerLineWidth,
    'visualizerGap': visualizerGap,
    'visualizerRadius': visualizerRadius,
    'visualizerRotationSpeed': visualizerRotationSpeed,
    'visualizerShape': visualizerShape,
    'visualizerFilled': visualizerFilled,
    'visualizerMinHeight': visualizerMinHeight,
    'visualizerFrequencyRange': visualizerFrequencyRange,
    'visualizerAudioSource': visualizerAudioSource,
    'visualizerPreviewMode': visualizerPreviewMode,
    'visualizerAudioDevice': visualizerAudioDevice,
  };

  factory SlideLayer.fromJson(Map<String, dynamic> json) {
    return SlideLayer(
      id: json['id'] ?? 'layer-${DateTime.now().millisecondsSinceEpoch}',
      label: json['label'] ?? 'Layer',
      kind: LayerKind.values.firstWhere(
        (e) => e.name == (json['kind'] ?? 'media'),
        orElse: () => LayerKind.media,
      ),
      role: LayerRole.values.firstWhere(
        (e) => e.name == (json['role'] ?? 'background'),
        orElse: () => LayerRole.background,
      ),
      text: json['text'] as String?,
      path: json['path'] as String?,
      mediaType: json['mediaType'] != null
          ? SlideMediaType.values.firstWhere(
              (e) => e.name == json['mediaType'],
              orElse: () => SlideMediaType.image,
            )
          : null,
      left: (json['left'] as num?)?.toDouble(),
      top: (json['top'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      opacity: (json['opacity'] as num?)?.toDouble(),
      fit: json['fit'] as String?,
      addedAt: json['addedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['addedAt'] as num).toInt(),
            )
          : DateTime.now(),
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      fontFamily: json['fontFamily'] as String?,
      textColor: json['textColor'] != null ? Color(json['textColor']) : null,
      align: json['align'] != null
          ? TextAlign.values.firstWhere(
              (e) => e.name == json['align'],
              orElse: () => TextAlign.left,
            )
          : null,
      isBold: json['isBold'] as bool?,
      isItalic: json['isItalic'] as bool?,
      isUnderline: json['isUnderline'] as bool?,
      boxPadding: (json['boxPadding'] as num?)?.toDouble(),
      boxColor: json['boxColor'] != null ? Color(json['boxColor']) : null,
      outlineColor: json['outlineColor'] != null
          ? Color(json['outlineColor'])
          : null,
      outlineWidth: (json['outlineWidth'] as num?)?.toDouble(),
      boxBorderRadius: (json['boxBorderRadius'] as num?)?.toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble(),
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
      visualizerSensitivity: (json['visualizerSensitivity'] as num?)
          ?.toDouble(),
      visualizerSmoothing: (json['visualizerSmoothing'] as num?)?.toDouble(),
      visualizerColor1: json['visualizerColor1'] != null
          ? Color(json['visualizerColor1'])
          : null,
      visualizerColor2: json['visualizerColor2'] != null
          ? Color(json['visualizerColor2'])
          : null,
      visualizerMirror: json['visualizerMirror'] as bool?,
      visualizerGlow: json['visualizerGlow'] as bool?,
      visualizerGlowIntensity: (json['visualizerGlowIntensity'] as num?)
          ?.toDouble(),
      visualizerColorMode: json['visualizerColorMode'] as String?,
      visualizerLineWidth: (json['visualizerLineWidth'] as num?)?.toDouble(),
      visualizerGap: (json['visualizerGap'] as num?)?.toDouble(),
      visualizerRadius: (json['visualizerRadius'] as num?)?.toDouble(),
      visualizerRotationSpeed: (json['visualizerRotationSpeed'] as num?)
          ?.toDouble(),
      visualizerShape: json['visualizerShape'] as String?,
      visualizerFilled: json['visualizerFilled'] as bool?,
      visualizerMinHeight: (json['visualizerMinHeight'] as num?)?.toDouble(),
      visualizerFrequencyRange: json['visualizerFrequencyRange'] as String?,
      visualizerAudioSource: json['visualizerAudioSource'] as String?,
      visualizerPreviewMode: json['visualizerPreviewMode'] as bool?,
      visualizerAudioDevice: json['visualizerAudioDevice'] as String?,
    );
  }
}

enum TextTransform { none, uppercase, lowercase, title, capitalizeLine }

enum VerticalAlign { top, middle, bottom }

enum SizingMode { shrinkToFit, growToFit, fixed }

enum ScrollDirection {
  none,
  leftToRight,
  rightToLeft,
  topToBottom,
  bottomToTop,
}

class SlideTemplate {
  SlideTemplate({
    required this.id,
    required this.name,
    required this.textColor,
    required this.background,
    required this.overlayAccent,
    required this.fontSize,
    required this.alignment,
    this.backgroundImagePath,
    this.isBold = false,
    this.isItalic = false,
    this.verticalAlign = VerticalAlign.middle,
  });

  final String id;
  final String name;
  final Color textColor;
  final Color background;
  final Color overlayAccent;
  final double fontSize;
  final TextAlign alignment;
  final String? backgroundImagePath;
  final bool isBold;
  final bool isItalic;
  final VerticalAlign verticalAlign;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'textColor': textColor.value,
    'background': background.value,
    'overlayAccent': overlayAccent.value,
    'fontSize': fontSize,
    'alignment': alignment.name,
    'backgroundImagePath': backgroundImagePath,
    'isBold': isBold,
    'isItalic': isItalic,
    'verticalAlign': verticalAlign.name,
  };

  factory SlideTemplate.fromJson(Map<String, dynamic> json) {
    return SlideTemplate(
      id: json['id'] ?? 'default',
      name: json['name'] ?? 'Default',
      textColor: Color(json['textColor'] ?? Colors.white.value),
      background: Color(json['background'] ?? AppPalette.carbonBlack.value),
      overlayAccent: Color(
        json['overlayAccent'] ?? AppPalette.dustyMauve.value,
      ),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 50.0,
      alignment: TextAlign.values.firstWhere(
        (e) => e.name == json['alignment'],
        orElse: () => TextAlign.center,
      ),
      backgroundImagePath: json['backgroundImagePath'],
      isBold: json['isBold'] ?? false,
      isItalic: json['isItalic'] ?? false,
      verticalAlign: VerticalAlign.values.firstWhere(
        (e) => e.name == json['verticalAlign'],
        orElse: () => VerticalAlign.middle,
      ),
    );
  }
}

class SlideContent {
  SlideContent({
    required this.id,
    required this.title,
    required this.body,
    required this.templateId,
    this.overlayNote,
    this.autoAdvanceSeconds,
    this.fontSizeOverride,
    this.fontFamilyOverride,
    this.textGradientOverride,
    this.textColorOverride,
    this.alignOverride,
    this.verticalAlign,
    this.lineHeight,
    this.letterSpacing,
    this.wordSpacing,
    this.isBold,
    this.isItalic,
    this.isUnderline,
    this.shadowColor,
    this.shadowBlur,
    this.shadowOffsetX,
    this.shadowOffsetY,
    this.outlineColor,
    this.outlineWidth,
    this.boxBorderRadius,
    this.rotation,
    this.boxPadding,
    this.boxBackgroundColor,
    this.textTransform,
    this.boxLeft,
    this.boxTop,
    this.boxWidth,
    this.boxHeight,
    this.autoSize,
    this.backgroundColor,
    this.singleLine,
    this.hueRotate,
    this.invert,
    this.blur,
    this.brightness,
    this.contrast,
    this.saturate,
    this.scrollDirection,
    this.scrollDurationSeconds,
    this.mediaPath,
    this.mediaType,
    List<SlideLayer>? layers,
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.timesUsed = 0,
    this.category = 'General',
    this.sizingMode,
    this.maxLinesPerSlide,
    this.groupColor,
    this.triggerTime,
    this.audioPath,
    this.alignmentData,
  }) : layers = layers ?? const [],
       createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? DateTime.now();

  final String id;
  String title;
  String body;
  String templateId;
  String? overlayNote;
  int? autoAdvanceSeconds;
  double? fontSizeOverride;
  String? fontFamilyOverride;
  List<Color>? textGradientOverride;
  Color? textColorOverride;
  TextAlign? alignOverride;
  VerticalAlign? verticalAlign;
  double? lineHeight;
  double? letterSpacing;
  double? wordSpacing;
  bool? isBold;
  bool? isItalic;
  bool? isUnderline;
  Color? shadowColor;
  double? shadowBlur;
  double? shadowOffsetX;
  double? shadowOffsetY;
  Color? outlineColor;
  double? outlineWidth;
  double? boxBorderRadius;
  double? rotation;
  double? boxPadding;
  Color? boxBackgroundColor;
  TextTransform? textTransform;
  double? boxLeft;
  double? boxTop;
  double? boxWidth;
  double? boxHeight;
  bool? autoSize;
  Color? backgroundColor;
  bool? singleLine;
  double? hueRotate;
  double? invert;
  double? blur;
  double? brightness;
  double? contrast;
  double? saturate;
  ScrollDirection? scrollDirection;
  int? scrollDurationSeconds;
  String? mediaPath;
  SlideMediaType? mediaType;
  List<SlideLayer> layers;
  final DateTime createdAt;
  DateTime modifiedAt;
  int timesUsed;
  String category;
  SizingMode? sizingMode;
  int? maxLinesPerSlide;
  Color? groupColor;
  Duration? triggerTime;
  String? audioPath;
  String? alignmentData;

  static const _unset = Object();
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'templateId': templateId,
    'overlayNote': overlayNote,
    'autoAdvanceSeconds': autoAdvanceSeconds,
    'fontSizeOverride': fontSizeOverride,
    'fontFamilyOverride': fontFamilyOverride,
    'textGradientOverride': textGradientOverride?.map((c) => c.value).toList(),
    'textColorOverride': textColorOverride?.value,
    'alignOverride': alignOverride?.name,
    'verticalAlign': verticalAlign?.name,
    'lineHeight': lineHeight,
    'letterSpacing': letterSpacing,
    'wordSpacing': wordSpacing,
    'isBold': isBold,
    'isItalic': isItalic,
    'isUnderline': isUnderline,
    'shadowColor': shadowColor?.value,
    'shadowBlur': shadowBlur,
    'shadowOffsetX': shadowOffsetX,
    'shadowOffsetY': shadowOffsetY,
    'outlineColor': outlineColor?.value,
    'outlineWidth': outlineWidth,
    'boxBorderRadius': boxBorderRadius,
    'rotation': rotation,
    'boxPadding': boxPadding,
    'boxBackgroundColor': boxBackgroundColor?.value,
    'textTransform': textTransform?.name,
    'boxLeft': boxLeft,
    'boxTop': boxTop,
    'boxWidth': boxWidth,
    'boxHeight': boxHeight,
    'autoSize': autoSize,
    'backgroundColor': backgroundColor?.value,
    'singleLine': singleLine,
    'hueRotate': hueRotate,
    'invert': invert,
    'blur': blur,
    'brightness': brightness,
    'contrast': contrast,
    'saturate': saturate,
    'scrollDirection': scrollDirection?.name,
    'scrollDurationSeconds': scrollDurationSeconds,
    'mediaPath': mediaPath,
    'mediaType': mediaType?.name,
    'layers': layers.map((l) => l.toJson()).toList(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'modifiedAt': modifiedAt.millisecondsSinceEpoch,
    'timesUsed': timesUsed,
    'category': category,
    'sizingMode': sizingMode?.name,
    'maxLinesPerSlide': maxLinesPerSlide,
    'groupColor': groupColor?.value,
    'audioPath': audioPath,
    'alignmentData': alignmentData,
  };

  SlideContent copyWith({
    String? id,
    String? title,
    String? body,
    String? templateId,
    Object? overlayNote = _unset,
    int? autoAdvanceSeconds,
    double? fontSizeOverride,
    String? fontFamilyOverride,
    Object? textGradientOverride = _unset,
    Color? textColorOverride,
    TextAlign? alignOverride,
    VerticalAlign? verticalAlign,
    double? lineHeight,
    double? letterSpacing,
    double? wordSpacing,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    Color? shadowColor,
    double? shadowBlur,
    double? shadowOffsetX,
    double? shadowOffsetY,
    Color? outlineColor,
    double? outlineWidth,
    double? boxBorderRadius,
    double? rotation,
    double? boxPadding,
    Color? boxBackgroundColor,
    TextTransform? textTransform,
    double? boxLeft,
    double? boxTop,
    double? boxWidth,
    double? boxHeight,
    bool? autoSize,
    Color? backgroundColor,
    bool? singleLine,
    double? hueRotate,
    double? invert,
    double? blur,
    double? brightness,
    double? contrast,
    double? saturate,
    ScrollDirection? scrollDirection,
    int? scrollDurationSeconds,
    Object? mediaPath = _unset,
    Object? mediaType = _unset,
    List<SlideLayer>? layers,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? timesUsed,
    String? category,
    SizingMode? sizingMode,
    int? maxLinesPerSlide,
    Color? groupColor,
    Object? triggerTime = _unset,
    Object? audioPath = _unset,
    Object? alignmentData = _unset,
  }) {
    return SlideContent(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      templateId: templateId ?? this.templateId,
      overlayNote: identical(overlayNote, _unset)
          ? this.overlayNote
          : overlayNote as String?,
      autoAdvanceSeconds: autoAdvanceSeconds ?? this.autoAdvanceSeconds,
      fontSizeOverride: fontSizeOverride ?? this.fontSizeOverride,
      fontFamilyOverride: fontFamilyOverride ?? this.fontFamilyOverride,
      textGradientOverride: identical(textGradientOverride, _unset)
          ? this.textGradientOverride
          : textGradientOverride as List<Color>?,
      textColorOverride: textColorOverride ?? this.textColorOverride,
      alignOverride: alignOverride ?? this.alignOverride,
      verticalAlign: verticalAlign ?? this.verticalAlign,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      boxBorderRadius: boxBorderRadius ?? this.boxBorderRadius,
      rotation: rotation ?? this.rotation,
      boxPadding: boxPadding ?? this.boxPadding,
      boxBackgroundColor: boxBackgroundColor ?? this.boxBackgroundColor,
      textTransform: textTransform ?? this.textTransform,
      boxLeft: boxLeft ?? this.boxLeft,
      boxTop: boxTop ?? this.boxTop,
      boxWidth: boxWidth ?? this.boxWidth,
      boxHeight: boxHeight ?? this.boxHeight,
      autoSize: autoSize ?? this.autoSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      singleLine: singleLine ?? this.singleLine,
      hueRotate: hueRotate ?? this.hueRotate,
      invert: invert ?? this.invert,
      blur: blur ?? this.blur,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturate: saturate ?? this.saturate,
      scrollDirection: scrollDirection ?? this.scrollDirection,
      scrollDurationSeconds:
          scrollDurationSeconds ?? this.scrollDurationSeconds,
      mediaPath: identical(mediaPath, _unset)
          ? this.mediaPath
          : mediaPath as String?,
      mediaType: identical(mediaType, _unset)
          ? this.mediaType
          : mediaType as SlideMediaType?,
      layers: layers ?? this.layers,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      timesUsed: timesUsed ?? this.timesUsed,
      category: category ?? this.category,
      sizingMode: sizingMode ?? this.sizingMode,
      maxLinesPerSlide: maxLinesPerSlide ?? this.maxLinesPerSlide,
      groupColor: groupColor ?? this.groupColor,
      triggerTime: identical(triggerTime, _unset)
          ? this.triggerTime
          : triggerTime as Duration?,
      audioPath: identical(audioPath, _unset)
          ? this.audioPath
          : audioPath as String?,
      alignmentData: identical(alignmentData, _unset)
          ? this.alignmentData
          : alignmentData as String?,
    );
  }

  factory SlideContent.fromJson(Map<String, dynamic> json) {
    return SlideContent(
      id: json['id'],
      title: json['title'] ?? 'Slide',
      body: json['body'] ?? '',
      templateId: json['templateId'] ?? 'default',
      overlayNote: json['overlayNote'],
      autoAdvanceSeconds: json['autoAdvanceSeconds'],
      groupColor: json['groupColor'] != null ? Color(json['groupColor']) : null,
      fontSizeOverride: (json['fontSizeOverride'] as num?)?.toDouble(),
      fontFamilyOverride: json['fontFamilyOverride'] as String?,
      textGradientOverride: (json['textGradientOverride'] as List?)
          ?.map((e) => Color(e as int))
          .toList(),
      textColorOverride: json['textColorOverride'] != null
          ? Color(json['textColorOverride'])
          : null,
      alignOverride: json['alignOverride'] != null
          ? TextAlign.values.firstWhere(
              (e) => e.name == json['alignOverride'],
              orElse: () => TextAlign.center,
            )
          : null,
      verticalAlign: json['verticalAlign'] != null
          ? VerticalAlign.values.firstWhere(
              (e) => e.name == json['verticalAlign'],
              orElse: () => VerticalAlign.middle,
            )
          : null,
      lineHeight: (json['lineHeight'] as num?)?.toDouble(),
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble(),
      wordSpacing: (json['wordSpacing'] as num?)?.toDouble(),
      isBold: json['isBold'] as bool?,
      isItalic: json['isItalic'] as bool?,
      isUnderline: json['isUnderline'] as bool?,
      shadowColor: json['shadowColor'] != null
          ? Color(json['shadowColor'])
          : null,
      shadowBlur: (json['shadowBlur'] as num?)?.toDouble(),
      shadowOffsetX: (json['shadowOffsetX'] as num?)?.toDouble(),
      shadowOffsetY: (json['shadowOffsetY'] as num?)?.toDouble(),
      outlineColor: json['outlineColor'] != null
          ? Color(json['outlineColor'])
          : null,
      outlineWidth: (json['outlineWidth'] as num?)?.toDouble(),
      boxBorderRadius: (json['boxBorderRadius'] as num?)?.toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble(),
      boxPadding: (json['boxPadding'] as num?)?.toDouble(),
      boxBackgroundColor: json['boxBackgroundColor'] != null
          ? Color(json['boxBackgroundColor'])
          : null,
      textTransform: json['textTransform'] != null
          ? TextTransform.values.firstWhere(
              (e) => e.name == json['textTransform'],
              orElse: () => TextTransform.none,
            )
          : null,
      boxLeft: (json['boxLeft'] as num?)?.toDouble(),
      boxTop: (json['boxTop'] as num?)?.toDouble(),
      boxWidth: (json['boxWidth'] as num?)?.toDouble(),
      boxHeight: (json['boxHeight'] as num?)?.toDouble(),
      autoSize: json['autoSize'] as bool?,
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'])
          : null,
      singleLine: json['singleLine'] as bool?,
      hueRotate: (json['hueRotate'] as num?)?.toDouble(),
      invert: (json['invert'] as num?)?.toDouble(),
      blur: (json['blur'] as num?)?.toDouble(),
      brightness: (json['brightness'] as num?)?.toDouble(),
      contrast: (json['contrast'] as num?)?.toDouble(),
      saturate: (json['saturate'] as num?)?.toDouble(),
      scrollDirection: json['scrollDirection'] != null
          ? ScrollDirection.values.firstWhere(
              (e) => e.name == json['scrollDirection'],
              orElse: () => ScrollDirection.none,
            )
          : null,
      scrollDurationSeconds: json['scrollDurationSeconds'] as int?,
      mediaPath: json['mediaPath'] as String?,
      mediaType: json['mediaType'] != null
          ? SlideMediaType.values.firstWhere(
              (e) => e.name == json['mediaType'],
              orElse: () => SlideMediaType.image,
            )
          : null,
      layers:
          (json['layers'] as List?)
              ?.map((e) => SlideLayer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : null,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['modifiedAt'] as int)
          : null,
      timesUsed: json['timesUsed'] ?? 0,

      category: json['category'] ?? 'General',
      sizingMode: json['sizingMode'] != null
          ? SizingMode.values.firstWhere(
              (e) => e.name == json['sizingMode'],
              orElse: () => SizingMode.shrinkToFit,
            )
          : null,
      maxLinesPerSlide: json['maxLinesPerSlide'],
      triggerTime: json['triggerTime'] != null
          ? Duration(milliseconds: json['triggerTime'])
          : null,
      audioPath: json['audioPath'] as String?,
      alignmentData: json['alignmentData'] as String?,
    );
  }
}
