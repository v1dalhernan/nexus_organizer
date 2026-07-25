import 'package:flutter/cupertino.dart';

class FileItem {
  final String id;
  final String name;
  final String path;
  final String extension;
  final int sizeBytes;
  final DateTime modifiedDate;
  final String sourceFolder;

  bool isSelected;
  bool isAnalyzed;
  String? snippet;

  // AI Classification
  String category;
  String suggestedPath;
  String suggestedRelativeFolder;
  String suggestedName;
  int confidence;
  String reasoning;
  String engine;

  FileItem({
    required this.id,
    required this.name,
    required this.path,
    required this.extension,
    required this.sizeBytes,
    required this.modifiedDate,
    required this.sourceFolder,
    this.isSelected = false,
    this.isAnalyzed = false,
    this.snippet,
    this.category = 'Pendiente',
    this.suggestedPath = '',
    this.suggestedRelativeFolder = '',
    this.suggestedName = '',
    this.confidence = 0,
    this.reasoning = 'Esperando análisis de IA...',
    this.engine = 'Pendiente',
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData get iconData {
    final ext = extension.toLowerCase();
    if (['.pdf', '.docx', '.doc', '.txt'].contains(ext)) return CupertinoIcons.doc_text;
    if (['.png', '.jpg', '.jpeg', '.gif', '.svg'].contains(ext)) return CupertinoIcons.photo;
    if (['.mp4', '.mov', '.mp3', '.wav'].contains(ext)) return CupertinoIcons.film;
    if (['.zip', '.rar', '.7z'].contains(ext)) return CupertinoIcons.archivebox;
    if (['.py', '.js', '.ts', '.html', '.css', '.json'].contains(ext)) return CupertinoIcons.chevron_left_slash_chevron_right;
    return CupertinoIcons.doc;
  }
}

class SourceItem {
  final String id;
  final String name;
  final String path;
  final IconData icon;
  final bool isCloud;
  final bool exists;

  SourceItem({
    required this.id,
    required this.name,
    required this.path,
    required this.icon,
    this.isCloud = false,
    this.exists = true,
  });
}
