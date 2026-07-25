import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/file_item.dart';

class UndoItem {
  final String sourcePath;
  final String targetPath;
  final DateTime timestamp;

  UndoItem({required this.sourcePath, required this.targetPath, required this.timestamp});
}

class OrganizerService {
  static final String userHome = Platform.environment['HOME'] ?? '/Users/jhonathanvidal';
  final List<UndoItem> _history = [];

  List<UndoItem> get history => _history;

  // Auto-discover local folders and cloud drives
  List<SourceItem> getAvailableSources() {
    final List<SourceItem> sources = [
      SourceItem(
        id: 'downloads',
        name: 'Descargas',
        path: p.join(userHome, 'Downloads'),
        icon: CupertinoIcons.arrow_down_circle_fill,
      ),
      SourceItem(
        id: 'documents',
        name: 'Documentos',
        path: p.join(userHome, 'Documents'),
        icon: CupertinoIcons.doc_on_clipboard_fill,
      ),
      SourceItem(
        id: 'desktop',
        name: 'Escritorio',
        path: p.join(userHome, 'Desktop'),
        icon: CupertinoIcons.desktopcomputer,
      ),
      SourceItem(
        id: 'development',
        name: 'Desarrollo / Proyectos',
        path: p.join(userHome, 'Development'),
        icon: CupertinoIcons.sparkles,
      ),
      SourceItem(
        id: 'certificaciones',
        name: 'Certificaciones & Cursos',
        path: p.join(userHome, 'Certificaciones-Ingenieria-Software'),
        icon: CupertinoIcons.star_fill,
      ),
    ];

    // Discover Cloud Storage
    final cloudDir = Directory(p.join(userHome, 'Library/CloudStorage'));
    if (cloudDir.existsSync()) {
      try {
        final entities = cloudDir.listSync();
        for (final entity in entities) {
          final name = p.basename(entity.path);
          if (name.startsWith('.')) continue;

          if (name.startsWith('GoogleDrive-')) {
            final email = name.replaceFirst('GoogleDrive-', '');
            final miUnidad = Directory(p.join(entity.path, 'Mi unidad'));
            final drivePath = miUnidad.existsSync() ? miUnidad.path : entity.path;

            sources.add(SourceItem(
              id: 'google-drive-$email',
              name: 'Google Drive ($email)',
              path: drivePath,
              icon: CupertinoIcons.cloud_fill,
              isCloud: true,
            ));
          } else if (name.startsWith('OneDrive-')) {
            final driveName = name.replaceFirst('OneDrive-', '');
            sources.add(SourceItem(
              id: 'onedrive-${driveName.toLowerCase()}',
              name: 'OneDrive ($driveName)',
              path: entity.path,
              icon: CupertinoIcons.cloud_upload_fill,
              isCloud: true,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error leyendo CloudStorage: $e');
      }
    }

    // Check iCloud Drive
    final icloud = Directory(p.join(userHome, 'Library/Mobile Documents/com~apple~CloudDocs'));
    if (icloud.existsSync()) {
      sources.add(SourceItem(
        id: 'icloud',
        name: 'iCloud Drive',
        path: icloud.path,
        icon: CupertinoIcons.cloud_sun_fill,
        isCloud: true,
      ));
    }

    return sources.where((s) => Directory(s.path).existsSync()).toList();
  }

  // Scan a directory
  Future<List<FileItem>> scanFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return [];

    final List<FileItem> results = [];
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue; // Ignore hidden files

        if (entity is File) {
          final stat = entity.statSync();
          final ext = p.extension(name);

          results.add(FileItem(
            id: base64Encode(utf8.encode(entity.path)),
            name: name,
            path: entity.path,
            extension: ext,
            sizeBytes: stat.size,
            modifiedDate: stat.modified,
            sourceFolder: folderPath,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error escaneando carpeta: $e');
    }

    return results;
  }

  // Read content preview snippet
  Future<String> extractSnippet(String filePath, String ext) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return '[Archivo no encontrado]';

      final size = file.lengthSync();
      if (size > 5 * 1024 * 1024) return '[Archivo grande: ${(size / (1024 * 1024)).toStringAsFixed(1)} MB]';

      final lowerExt = ext.toLowerCase();
      if (['.txt', '.md', '.json', '.csv', '.py', '.js', '.ts', '.html', '.css', '.sh', '.yaml'].contains(lowerExt)) {
        final text = await file.readAsString();
        return text.substring(0, text.length > 1500 ? 1500 : text.length);
      }

      return '[Archivo $lowerExt de $size bytes]';
    } catch (e) {
      return '[Error leyendo extracto: $e]';
    }
  }

  // Check Ollama status
  Future<Map<String, dynamic>> checkOllamaStatus() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:11434/api/tags')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List? ?? []).map((m) => m['name'].toString()).toList();
        return {
          'active': true,
          'models': models,
          'chosenModel': models.firstWhere((m) => m.contains('llama') || m.contains('mistral') || m.contains('qwen'), orElse: () => models.isNotEmpty ? models.first : 'llama3.2:1b'),
        };
      }
    } catch (_) {}

    return {'active': false, 'models': [], 'chosenModel': null};
  }

  // Analyze file using Ollama or Heuristic Fallback
  Future<void> analyzeFile(FileItem item) async {
    final snippet = await extractSnippet(item.path, item.extension);
    item.snippet = snippet;

    final ollamaStatus = await checkOllamaStatus();

    if (ollamaStatus['active'] == true && ollamaStatus['chosenModel'] != null) {
      try {
        final model = ollamaStatus['chosenModel'];
        final prompt = '''System: Eres un asistente de inteligencia artificial para organización de archivos en macOS.
Analiza el archivo y responde UNICAMENTE con un objeto JSON válido con este formato:
{
  "category": "Nombre de Categoria",
  "suggestedSubfolder": "RutaRelativaDesdeHome",
  "suggestedName": "NombreLimpio",
  "confidence": 95,
  "reasoning": "Explicacion breve"
}

Información:
Nombre: "${item.name}"
Extensión: "${item.extension}"
Contenido: "${snippet.replaceAll('"', "'").substring(0, snippet.length > 800 ? 800 : snippet.length)}"''';

        final response = await http.post(
          Uri.parse('http://127.0.0.1:11434/api/generate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'stream': false,
            'format': 'json',
          }),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final parsed = jsonDecode(resData['response']);

          item.category = parsed['category'] ?? 'General';
          final subfolder = parsed['suggestedSubfolder'] ?? 'Documentos/Organizados';
          item.suggestedRelativeFolder = subfolder;
          item.suggestedPath = p.join(userHome, subfolder, parsed['suggestedName'] ?? item.name);
          item.confidence = parsed['confidence'] ?? 90;
          item.reasoning = parsed['reasoning'] ?? 'Clasificado por IA Ollama.';
          item.engine = 'Ollama ($model)';
          item.isAnalyzed = true;
          return;
        }
      } catch (e) {
        debugPrint('Fallback to Heuristic for ${item.name}: $e');
      }
    }

    // Heuristic AI Fallback
    _ruleBasedClassification(item, snippet);
    item.isAnalyzed = true;
  }

  void _ruleBasedClassification(FileItem item, String snippet) {
    final lowerName = item.name.toLowerCase();
    final lowerExt = item.extension.toLowerCase();
    final lowerSnippet = snippet.toLowerCase();

    if (['.pdf', '.docx', '.xlsx'].contains(lowerExt)) {
      if (lowerName.contains('factura') || lowerName.contains('invoice') || lowerSnippet.contains('total:')) {
        item.category = 'Finanzas';
        item.suggestedRelativeFolder = 'Documentos/Finanzas/Facturas';
        item.confidence = 94;
        item.reasoning = 'Factura o documento contable identificado.';
      } else if (lowerName.contains('hv') || lowerName.contains('resume') || lowerSnippet.contains('experiencia laboral')) {
        item.category = 'Laboral';
        item.suggestedRelativeFolder = 'Documentos/Laboral/HV_Resumes';
        item.confidence = 96;
        item.reasoning = 'Hoja de vida o currículum vitae.';
      } else if (lowerName.contains('certifica') || lowerName.contains('curso')) {
        item.category = 'Certificaciones';
        item.suggestedRelativeFolder = 'Certificaciones-Ingenieria-Software';
        item.confidence = 92;
        item.reasoning = 'Certificado o diploma de curso.';
      } else {
        item.category = 'Documentos';
        item.suggestedRelativeFolder = 'Documentos/General';
        item.confidence = 85;
        item.reasoning = 'Documento de texto o reporte.';
      }
    } else if (['.png', '.jpg', '.jpeg', '.svg'].contains(lowerExt)) {
      item.category = 'Multimedia';
      item.suggestedRelativeFolder = 'Imágenes/Organizadas';
      item.confidence = 90;
      item.reasoning = 'Archivo de imagen o diseño visual.';
    } else if (['.py', '.js', '.ts', '.html', '.css', '.json'].contains(lowerExt)) {
      item.category = 'Código';
      item.suggestedRelativeFolder = 'Development/Scripts';
      item.confidence = 95;
      item.reasoning = 'Código fuente o script de software.';
    } else {
      item.category = 'General';
      item.suggestedRelativeFolder = 'Documentos/Varios';
      item.confidence = 80;
      item.reasoning = 'Archivo genérico por tipo de extensión.';
    }

    item.suggestedPath = p.join(userHome, item.suggestedRelativeFolder, item.name);
    item.engine = 'IA Heurística Nativa';
  }

  // Move files
  Future<int> moveFiles(List<FileItem> files) async {
    int successCount = 0;
    for (final fileItem in files) {
      try {
        final src = File(fileItem.path);
        if (!src.existsSync()) continue;

        final targetDir = Directory(p.dirname(fileItem.suggestedPath));
        if (!targetDir.existsSync()) {
          targetDir.createSync(recursive: true);
        }

        final targetFile = File(fileItem.suggestedPath);
        src.renameSync(targetFile.path);

        _history.add(UndoItem(
          sourcePath: fileItem.path,
          targetPath: targetFile.path,
          timestamp: DateTime.now(),
        ));
        successCount++;
      } catch (e) {
        debugPrint('Error moviendo archivo ${fileItem.name}: $e');
      }
    }
    return successCount;
  }

  // Undo move
  Future<int> undoLastMove() async {
    if (_history.isEmpty) return 0;
    int undone = 0;
    final lastItems = _history.length > 5 ? _history.sublist(_history.length - 5) : List<UndoItem>.from(_history);

    for (final item in lastItems.reversed) {
      try {
        final target = File(item.targetPath);
        if (target.existsSync()) {
          final srcDir = Directory(p.dirname(item.sourcePath));
          if (!srcDir.existsSync()) srcDir.createSync(recursive: true);

          target.renameSync(item.sourcePath);
          _history.remove(item);
          undone++;
        }
      } catch (e) {
        debugPrint('Error deshaciendo: $e');
      }
    }
    return undone;
  }
}
