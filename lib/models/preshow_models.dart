import 'package:uuid/uuid.dart';

enum PlaylistItemType { video, audio }

enum PlaylistViewType { list, grid, carousel }

class PreShowPlaylistItem {
  final String id;
  final String title;
  final String path;
  final PlaylistItemType type;
  final Duration? duration;

  PreShowPlaylistItem({
    required this.id,
    required this.title,
    required this.path,
    required this.type,
    this.duration,
  });

  factory PreShowPlaylistItem.create({
    required String title,
    required String path,
    required PlaylistItemType type,
    Duration? duration,
  }) {
    return PreShowPlaylistItem(
      id: const Uuid().v4(),
      title: title,
      path: path,
      type: type,
      duration: duration,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'path': path,
    'type': type.name,
    'durationMs': duration?.inMilliseconds,
  };

  factory PreShowPlaylistItem.fromJson(Map<String, dynamic> json) {
    return PreShowPlaylistItem(
      id: json['id'],
      title: json['title'],
      path: json['path'],
      type: PlaylistItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PlaylistItemType.audio,
      ),
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'])
          : null,
    );
  }

  PreShowPlaylistItem copyWith({
    String? title,
    String? path,
    PlaylistItemType? type,
    Duration? duration,
  }) {
    return PreShowPlaylistItem(
      id: id,
      title: title ?? this.title,
      path: path ?? this.path,
      type: type ?? this.type,
      duration: duration ?? this.duration,
    );
  }
}

class PreShowPlaylist {
  final String id;
  final String name;
  final List<PreShowPlaylistItem> items;
  bool isLooping;

  PreShowPlaylist({
    required this.id,
    required this.name,
    this.items = const [],
    this.isLooping = true,
  });

  factory PreShowPlaylist.create({required String name}) {
    return PreShowPlaylist(id: const Uuid().v4(), name: name);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
    'isLooping': isLooping,
  };

  factory PreShowPlaylist.fromJson(Map<String, dynamic> json) {
    return PreShowPlaylist(
      id: json['id'],
      name: json['name'],
      items:
          (json['items'] as List?)
              ?.map((i) => PreShowPlaylistItem.fromJson(i))
              .toList() ??
          [],
      isLooping: json['isLooping'] ?? true,
    );
  }

  PreShowPlaylist copyWith({
    String? name,
    List<PreShowPlaylistItem>? items,
    bool? isLooping,
  }) {
    return PreShowPlaylist(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
      isLooping: isLooping ?? this.isLooping,
    );
  }
}
