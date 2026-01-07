part of dashboard_screen;

enum _SlideMediaType { image, video }

enum _LayerRole { background, foreground }

enum _LayerKind {
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
}

enum _HandlePosition {
  topLeft,
  midTop,
  topRight,
  midLeft,
  midRight,
  bottomLeft,
  midBottom,
  bottomRight,
}

class _SlideLayer {
  _SlideLayer({
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
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final String id;
  final String label;
  final _LayerKind kind;
  final String? text;
  final String? path;
  final _SlideMediaType? mediaType;
  final _LayerRole role;
  final double? left;
  final double? top;
  final double? width;
  final double? height;
  final double? opacity;
  final DateTime addedAt;

  _SlideLayer copyWith({
    String? id,
    String? label,
    _LayerKind? kind,
    _LayerRole? role,
    String? text,
    String? path,
    _SlideMediaType? mediaType,
    double? left,
    double? top,
    double? width,
    double? height,
    double? opacity,
    DateTime? addedAt,
  }) {
    return _SlideLayer(
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
      addedAt: addedAt ?? this.addedAt,
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
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  factory _SlideLayer.fromJson(Map<String, dynamic> json) {
    return _SlideLayer(
      id: json['id'] ?? 'layer-${DateTime.now().millisecondsSinceEpoch}',
      label: json['label'] ?? 'Layer',
      kind: _LayerKind.values.firstWhere(
        (e) => e.name == (json['kind'] ?? 'media'),
        orElse: () => _LayerKind.media,
      ),
      role: _LayerRole.values.firstWhere(
        (e) => e.name == (json['role'] ?? 'background'),
        orElse: () => _LayerRole.background,
      ),
      text: json['text'] as String?,
      path: json['path'] as String?,
      mediaType: json['mediaType'] != null
          ? _SlideMediaType.values.firstWhere(
              (e) => e.name == json['mediaType'],
              orElse: () => _SlideMediaType.image,
            )
          : null,
      left: (json['left'] as num?)?.toDouble(),
      top: (json['top'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      opacity: (json['opacity'] as num?)?.toDouble(),
      addedAt: json['addedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['addedAt'] as num).toInt())
          : DateTime.now(),
    );
  }
}
