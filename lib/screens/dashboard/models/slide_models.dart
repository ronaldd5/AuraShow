// ignore_for_file: unused_element

part of dashboard_screen;

enum _TextTransform { none, uppercase, lowercase, title }

enum _VerticalAlign { top, middle, bottom }

enum _ScrollDirection { none, leftToRight, rightToLeft, topToBottom, bottomToTop }

class _SlideTemplate {
  _SlideTemplate({
    required this.id,
    required this.name,
    required this.textColor,
    required this.background,
    required this.overlayAccent,
    required this.fontSize,
    required this.alignment,
  });

  final String id;
  final String name;
  final Color textColor;
  final Color background;
  final Color overlayAccent;
  final double fontSize;
  final TextAlign alignment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'textColor': textColor.value,
        'background': background.value,
        'overlayAccent': overlayAccent.value,
        'fontSize': fontSize,
        'alignment': alignment.name,
      };

  factory _SlideTemplate.fromJson(Map<String, dynamic> json) {
    return _SlideTemplate(
      id: json['id'] ?? 'default',
      name: json['name'] ?? 'Default',
      textColor: Color(json['textColor'] ?? Colors.white.value),
      background: Color(json['background'] ?? AppPalette.carbonBlack.value),
      overlayAccent: Color(json['overlayAccent'] ?? AppPalette.dustyMauve.value),
      fontSize: (json['fontSize'] ?? 38).toDouble(),
      alignment: TextAlign.values.firstWhere(
        (e) => e.name == (json['alignment'] ?? 'center'),
        orElse: () => TextAlign.center,
      ),
    );
  }
}

class _SlideContent {
  _SlideContent({
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
    List<_SlideLayer>? layers,
  }) : layers = layers ?? const [];

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
  _VerticalAlign? verticalAlign;
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
  double? boxPadding;
  Color? boxBackgroundColor;
  _TextTransform? textTransform;
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
  _ScrollDirection? scrollDirection;
  int? scrollDurationSeconds;
  String? mediaPath;
  _SlideMediaType? mediaType;
  List<_SlideLayer> layers;

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
      };

  _SlideContent copyWith({
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
    _VerticalAlign? verticalAlign,
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
    double? boxPadding,
    Color? boxBackgroundColor,
    _TextTransform? textTransform,
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
    _ScrollDirection? scrollDirection,
    int? scrollDurationSeconds,
    Object? mediaPath = _unset,
    Object? mediaType = _unset,
    List<_SlideLayer>? layers,
  }) {
    return _SlideContent(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      templateId: templateId ?? this.templateId,
      overlayNote: identical(overlayNote, _unset) ? this.overlayNote : overlayNote as String?,
      autoAdvanceSeconds: autoAdvanceSeconds ?? this.autoAdvanceSeconds,
      fontSizeOverride: fontSizeOverride ?? this.fontSizeOverride,
      fontFamilyOverride: fontFamilyOverride ?? this.fontFamilyOverride,
      textGradientOverride: identical(textGradientOverride, _unset) ? this.textGradientOverride : textGradientOverride as List<Color>?,
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
      scrollDurationSeconds: scrollDurationSeconds ?? this.scrollDurationSeconds,
      mediaPath: identical(mediaPath, _unset) ? this.mediaPath : mediaPath as String?,
      mediaType: identical(mediaType, _unset) ? this.mediaType : mediaType as _SlideMediaType?,
      layers: layers ?? this.layers,
    );
  }

  factory _SlideContent.fromJson(Map<String, dynamic> json) {
    return _SlideContent(
      id: json['id'],
      title: json['title'] ?? 'Slide',
      body: json['body'] ?? '',
      templateId: json['templateId'] ?? 'default',
      overlayNote: json['overlayNote'],
      autoAdvanceSeconds: json['autoAdvanceSeconds'],
      fontSizeOverride: (json['fontSizeOverride'] as num?)?.toDouble(),
      fontFamilyOverride: json['fontFamilyOverride'] as String?,
      textGradientOverride: (json['textGradientOverride'] as List?)?.map((e) => Color(e as int)).toList(),
      textColorOverride: json['textColorOverride'] != null ? Color(json['textColorOverride']) : null,
      alignOverride: json['alignOverride'] != null
          ? TextAlign.values.firstWhere(
              (e) => e.name == json['alignOverride'],
              orElse: () => TextAlign.center,
            )
          : null,
      verticalAlign: json['verticalAlign'] != null
          ? _VerticalAlign.values.firstWhere(
              (e) => e.name == json['verticalAlign'],
              orElse: () => _VerticalAlign.middle,
            )
          : null,
      lineHeight: (json['lineHeight'] as num?)?.toDouble(),
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble(),
      wordSpacing: (json['wordSpacing'] as num?)?.toDouble(),
      isBold: json['isBold'] as bool?,
      isItalic: json['isItalic'] as bool?,
      isUnderline: json['isUnderline'] as bool?,
      shadowColor: json['shadowColor'] != null ? Color(json['shadowColor']) : null,
      shadowBlur: (json['shadowBlur'] as num?)?.toDouble(),
      shadowOffsetX: (json['shadowOffsetX'] as num?)?.toDouble(),
      shadowOffsetY: (json['shadowOffsetY'] as num?)?.toDouble(),
      outlineColor: json['outlineColor'] != null ? Color(json['outlineColor']) : null,
      outlineWidth: (json['outlineWidth'] as num?)?.toDouble(),
      boxPadding: (json['boxPadding'] as num?)?.toDouble(),
      boxBackgroundColor: json['boxBackgroundColor'] != null ? Color(json['boxBackgroundColor']) : null,
      textTransform: json['textTransform'] != null
          ? _TextTransform.values.firstWhere(
              (e) => e.name == json['textTransform'],
              orElse: () => _TextTransform.none,
            )
          : null,
      boxLeft: (json['boxLeft'] as num?)?.toDouble(),
      boxTop: (json['boxTop'] as num?)?.toDouble(),
      boxWidth: (json['boxWidth'] as num?)?.toDouble(),
      boxHeight: (json['boxHeight'] as num?)?.toDouble(),
      autoSize: json['autoSize'] as bool?,
      backgroundColor: json['backgroundColor'] != null ? Color(json['backgroundColor']) : null,
      singleLine: json['singleLine'] as bool?,
      hueRotate: (json['hueRotate'] as num?)?.toDouble(),
      invert: (json['invert'] as num?)?.toDouble(),
      blur: (json['blur'] as num?)?.toDouble(),
      brightness: (json['brightness'] as num?)?.toDouble(),
      contrast: (json['contrast'] as num?)?.toDouble(),
      saturate: (json['saturate'] as num?)?.toDouble(),
      scrollDirection: json['scrollDirection'] != null
          ? _ScrollDirection.values.firstWhere(
              (e) => e.name == json['scrollDirection'],
              orElse: () => _ScrollDirection.none,
            )
          : null,
      scrollDurationSeconds: json['scrollDurationSeconds'] as int?,
      mediaPath: json['mediaPath'] as String?,
      mediaType: json['mediaType'] != null
          ? _SlideMediaType.values.firstWhere(
              (e) => e.name == json['mediaType'],
              orElse: () => _SlideMediaType.image,
            )
          : null,
      layers: (json['layers'] as List?)?.map((e) => _SlideLayer.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }
}
