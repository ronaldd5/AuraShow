import 'slide_model.dart';

enum NodeType { folder, project, show }

abstract class FileSystemNode {
  final String id;
  String name;
  String?
  parentId; // The ID of the folder (or project for shows) containing this node
  final NodeType type;

  FileSystemNode({
    required this.id,
    required this.name,
    this.parentId,
    required this.type,
  });

  // Serialization logic for JSON persistence
  Map<String, dynamic> toJson();

  static FileSystemNode fromJson(Map<String, dynamic> json) {
    final type = NodeType.values.firstWhere(
      (e) => e.toString() == json['type'],
      orElse: () => NodeType.project,
    );

    switch (type) {
      case NodeType.folder:
        return FolderNode.fromJson(json);
      case NodeType.project:
        return ProjectNode.fromJson(json);
      case NodeType.show:
        return ShowNode.fromJson(json);
    }
  }
}

class ProjectNode extends FileSystemNode {
  // Metadata specific to a project container
  final String? projectFilePath;
  final String? category; // Retained for backward compatibility/export

  ProjectNode({
    required String id,
    required String name,
    String? parentId,
    this.projectFilePath,
    this.category,
  }) : super(id: id, name: name, parentId: parentId, type: NodeType.project);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'type': type.toString(),
    'projectFilePath': projectFilePath,
    'category': category,
  };

  factory ProjectNode.fromJson(Map<String, dynamic> json) {
    return ProjectNode(
      id: json['id'],
      name: json['name'],
      parentId: json['parentId'],
      projectFilePath: json['projectFilePath'],
      category: json['category'],
    );
  }
}

class FolderNode extends FileSystemNode {
  bool isExpanded; // UI state persisted with the node

  FolderNode({
    required String id,
    required String name,
    String? parentId,
    this.isExpanded = false,
  }) : super(id: id, name: name, parentId: parentId, type: NodeType.folder);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'type': type.toString(),
    'isExpanded': isExpanded,
  };

  factory FolderNode.fromJson(Map<String, dynamic> json) {
    return FolderNode(
      id: json['id'],
      name: json['name'],
      parentId: json['parentId'],
      isExpanded: json['isExpanded'] ?? false,
    );
  }
}

class ShowNode extends FileSystemNode {
  // A specific show (set of slides) inside a Project
  final String? originalSongId; // If created from a song import
  List<SlideContent> slides;

  ShowNode({
    required String id,
    required String name,
    required String parentId, // Shows MUST have a parent Project
    this.originalSongId,
    List<SlideContent>? slides,
  }) : slides = slides ?? [],
       super(id: id, name: name, parentId: parentId, type: NodeType.show);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'type': type.toString(),
    'originalSongId': originalSongId,
    'slides': slides.map((s) => s.toJson()).toList(),
  };

  factory ShowNode.fromJson(Map<String, dynamic> json) {
    return ShowNode(
      id: json['id'],
      name: json['name'],
      parentId: json['parentId']!,
      originalSongId: json['originalSongId'],
      slides: (json['slides'] as List<dynamic>?)
          ?.map((e) => SlideContent.fromJson(e))
          .toList(),
    );
  }
}
