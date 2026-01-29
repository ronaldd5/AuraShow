import 'package:flutter/material.dart';

enum OutputDestination { screen, ndi, virtual }

enum OutputStyleProfile { audienceFull, streamLowerThird, stageNotes }

class OutputConfig {
  OutputConfig({
    required this.id,
    required this.name,
    required this.destination,
    required this.styleProfile,
    this.targetScreenId,
    this.width,
    this.height,
    this.stageNotes = false,
    this.textScale = 1.0,
    this.maxLines = 12,
    this.visible = true,
    this.alwaysOnTop = false,
    this.enableNdi = false, // New field
    this.ndiAudio = true,
    this.ndiFrameRate = 30,
    this.ndiName,
    this.ndiGroup,
    this.transparent = false,
    this.invisibleWindow = false,
    this.useStyle,
    this.layerOverrides,
  });

  final String id;
  final String name;
  final OutputDestination destination;
  final OutputStyleProfile styleProfile;
  final String? targetScreenId;
  final int? width;
  final int? height;
  final bool stageNotes;
  final double textScale;
  final int maxLines;
  final bool visible;
  final bool alwaysOnTop;
  final bool enableNdi; // New field
  final bool ndiAudio;
  final int ndiFrameRate;
  final String? ndiName;
  final String? ndiGroup;
  final bool transparent;
  final bool invisibleWindow;
  final String? useStyle;
  final Map<String, bool>? layerOverrides;

  factory OutputConfig.defaultAudience() {
    return OutputConfig(
      id: 'output-default',
      name: 'Output 1',
      destination: OutputDestination.screen,
      styleProfile: OutputStyleProfile.audienceFull,
      stageNotes: false,
      textScale: 1.0,
      maxLines: 12,
      visible: true,
      enableNdi: false,
    );
  }

  OutputConfig copyWith({
    String? id,
    String? name,
    OutputDestination? destination,
    OutputStyleProfile? styleProfile,
    String? targetScreenId,
    int? width,
    int? height,
    bool? stageNotes,
    double? textScale,
    int? maxLines,
    bool? visible,
    bool? alwaysOnTop,
    bool? enableNdi,
    bool? ndiAudio,
    int? ndiFrameRate,
    String? ndiName,
    String? ndiGroup,
    bool? transparent,
    bool? invisibleWindow,
    String? useStyle,
    Map<String, bool>? layerOverrides,
  }) {
    return OutputConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      styleProfile: styleProfile ?? this.styleProfile,
      targetScreenId: targetScreenId ?? this.targetScreenId,
      width: width ?? this.width,
      height: height ?? this.height,
      stageNotes: stageNotes ?? this.stageNotes,
      textScale: textScale ?? this.textScale,
      maxLines: maxLines ?? this.maxLines,
      visible: visible ?? this.visible,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      enableNdi: enableNdi ?? this.enableNdi,
      ndiAudio: ndiAudio ?? this.ndiAudio,
      ndiFrameRate: ndiFrameRate ?? this.ndiFrameRate,
      ndiName: ndiName ?? this.ndiName,
      ndiGroup: ndiGroup ?? this.ndiGroup,
      transparent: transparent ?? this.transparent,
      invisibleWindow: invisibleWindow ?? this.invisibleWindow,
      useStyle: useStyle ?? this.useStyle,
      layerOverrides: layerOverrides ?? this.layerOverrides,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'destination': destination.name,
    'styleProfile': styleProfile.name,
    'targetScreenId': targetScreenId,
    'width': width,
    'height': height,
    'stageNotes': stageNotes,
    'textScale': textScale,
    'maxLines': maxLines,
    'visible': visible,
    'alwaysOnTop': alwaysOnTop,
    'enableNdi': enableNdi,
    'ndiAudio': ndiAudio,
    'ndiFrameRate': ndiFrameRate,
    'ndiName': ndiName,
    'ndiGroup': ndiGroup,
    'transparent': transparent,
    'invisibleWindow': invisibleWindow,
    'useStyle': useStyle,
    'layerOverrides': layerOverrides,
  };

  factory OutputConfig.fromJson(Map<String, dynamic> json) {
    OutputDestination parseDest(String? v) {
      return OutputDestination.values.firstWhere(
        (e) => e.name == v,
        orElse: () => OutputDestination.screen,
      );
    }

    OutputStyleProfile parseStyle(String? v) {
      return OutputStyleProfile.values.firstWhere(
        (e) => e.name == v,
        orElse: () => OutputStyleProfile.audienceFull,
      );
    }

    return OutputConfig(
      id: json['id'] ?? 'output-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] ?? 'Output',
      destination: parseDest(json['destination'] as String?),
      styleProfile: parseStyle(json['styleProfile'] as String?),
      targetScreenId: json['targetScreenId'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      stageNotes: json['stageNotes'] as bool? ?? false,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      maxLines: (json['maxLines'] as num?)?.toInt() ?? 12,
      visible:
          json['visible'] as bool? ??
          parseDest(json['destination'] as String?) == OutputDestination.screen,
      alwaysOnTop: json['alwaysOnTop'] as bool? ?? false,
      enableNdi: json['enableNdi'] as bool? ?? false,
      ndiAudio: json['ndiAudio'] as bool? ?? true,
      ndiFrameRate: (json['ndiFrameRate'] as num?)?.toInt() ?? 30,
      ndiName: json['ndiName'] as String?,
      ndiGroup: json['ndiGroup'] as String?,
      transparent: json['transparent'] as bool? ?? false,
      invisibleWindow: json['invisibleWindow'] as bool? ?? false,
      useStyle: json['useStyle'] as String?,
      layerOverrides: (json['layerOverrides'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as bool),
      ),
    );
  }
}
