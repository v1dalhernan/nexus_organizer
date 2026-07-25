import 'package:flutter/cupertino.dart';
import 'models/file_item.dart';
import 'services/organizer_service.dart';

void main() {
  runApp(const NexusOrganizerApp());
}

class NexusOrganizerApp extends StatelessWidget {
  const NexusOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'NexusOrganizer',
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: Color(0xFF000000),
        barBackgroundColor: Color(0xCC1C1C1E),
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.white,
        ),
      ),
      home: MainCupertinoHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainCupertinoHomePage extends StatefulWidget {
  const MainCupertinoHomePage({super.key});

  @override
  State<MainCupertinoHomePage> createState() => _MainCupertinoHomePageState();
}

class _MainCupertinoHomePageState extends State<MainCupertinoHomePage> {
  final OrganizerService _service = OrganizerService();

  List<SourceItem> _sources = [];
  SourceItem? _currentSource;
  List<FileItem> _scannedFiles = [];
  bool _isLoading = false;
  bool _isAnalyzing = false;
  int _selectedFilterIndex = 0;

  bool _ollamaActive = false;
  String _ollamaModel = '';

  final List<String> _categories = ['Todos', 'Finanzas', 'Laboral', 'Certificaciones', 'Código', 'Multimedia'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final status = await _service.checkOllamaStatus();
    setState(() {
      _ollamaActive = status['active'] == true;
      _ollamaModel = status['chosenModel'] ?? 'Ollama Local';
      _sources = _service.getAvailableSources();
      if (_sources.isNotEmpty) {
        _currentSource = _sources.first;
      }
    });

    if (_currentSource != null) {
      _scanCurrentSource();
    }
  }

  Future<void> _scanCurrentSource() async {
    if (_currentSource == null) return;
    setState(() {
      _isLoading = true;
      _scannedFiles = [];
    });

    final files = await _service.scanFolder(_currentSource!.path);
    setState(() {
      _scannedFiles = files;
      _isLoading = false;
    });

    if (files.isNotEmpty) {
      _analyzeAllWithAI();
    }
  }

  Future<void> _analyzeAllWithAI() async {
    if (_scannedFiles.isEmpty) return;
    setState(() => _isAnalyzing = true);

    for (final file in _scannedFiles) {
      if (!file.isAnalyzed) {
        await _service.analyzeFile(file);
        if (mounted) setState(() {});
      }
    }

    if (mounted) setState(() => _isAnalyzing = false);
  }

  Future<void> _moveSelected() async {
    final selected = _scannedFiles.where((f) => f.isSelected && f.isAnalyzed).toList();
    if (selected.isEmpty) return;

    final movedCount = await _service.moveFiles(selected);
    if (movedCount > 0) {
      _showCupertinoToast('¡Se movieron $movedCount archivo(s) correctamente!');
      _scanCurrentSource();
    }
  }

  Future<void> _undo() async {
    final undone = await _service.undoLastMove();
    if (undone > 0) {
      _showCupertinoToast('Se deshicieron $undone movimiento(s).');
      _scanCurrentSource();
    } else {
      _showCupertinoToast('No hay movimientos para deshacer.');
    }
  }

  void _showCupertinoToast(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('NexusOrganizer'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  List<FileItem> get _filteredFiles {
    if (_selectedFilterIndex == 0) return _scannedFiles;
    final catName = _categories[_selectedFilterIndex];
    return _scannedFiles.where((f) => f.category.toLowerCase() == catName.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.sparkles, color: CupertinoColors.activeBlue, size: 20),
            const SizedBox(width: 8),
            const Text('NexusOrganizer', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _ollamaActive ? CupertinoColors.activeGreen.withOpacity(0.2) : CupertinoColors.systemOrange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _ollamaActive ? CupertinoColors.activeGreen : CupertinoColors.systemOrange, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _ollamaActive ? CupertinoColors.activeGreen : CupertinoColors.systemOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isAnalyzing ? 'IA Analizando...' : (_ollamaActive ? 'Ollama: $_ollamaModel' : 'IA Heurística Nativa'),
                    style: TextStyle(
                      fontSize: 11,
                      color: _ollamaActive ? CupertinoColors.activeGreen : CupertinoColors.systemOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isAnalyzing) ...[
                    const SizedBox(width: 6),
                    const CupertinoActivityIndicator(radius: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _undo,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.arrow_counterclockwise, size: 18),
              SizedBox(width: 4),
              Text('Deshacer', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Sidebar Sources (Apple iOS Grouped List Style)
            SizedBox(
              width: 320,
              child: Container(
                color: const Color(0xFF1C1C1E),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Text(
                        'ORÍGENES Y NUBES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _sources.length,
                        itemBuilder: (context, index) {
                          final src = _sources[index];
                          final isSelected = _currentSource?.id == src.id;

                          return GestureDetector(
                            onTap: () {
                              setState(() => _currentSource = src);
                              _scanCurrentSource();
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? CupertinoColors.activeBlue.withValues(alpha: 0.2) : CupertinoColors.transparent,
                                border: isSelected ? Border.all(color: CupertinoColors.activeBlue) : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    src.icon,
                                    color: src.isCloud ? CupertinoColors.activeGreen : CupertinoColors.activeBlue,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          src.name,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            fontSize: 14,
                                            color: CupertinoColors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          src.isCloud ? 'Nube Sincronizada' : 'Carpeta Local',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Toolbar & Segmented Filter
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentSource?.name ?? 'Carpeta',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _currentSource?.path ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  color: CupertinoColors.darkBackgroundGray,
                                  onPressed: _scanCurrentSource,
                                  child: const Row(
                                    children: [
                                      Icon(CupertinoIcons.refresh, size: 16),
                                      SizedBox(width: 6),
                                      Text('Escanear'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CupertinoButton.filled(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  onPressed: _scannedFiles.any((f) => f.isSelected) ? _moveSelected : null,
                                  child: Row(
                                    children: [
                                      const Icon(CupertinoIcons.arrow_right_arrow_left, size: 16),
                                      const SizedBox(width: 6),
                                      Text('Mover Seleccionados (${_scannedFiles.where((f) => f.isSelected).length})'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // iOS Segmented Control
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoSegmentedControl<int>(
                            groupValue: _selectedFilterIndex,
                            onValueChanged: (val) => setState(() => _selectedFilterIndex = val),
                            children: {
                              for (int i = 0; i < _categories.length; i++)
                                i: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Text(_categories[i], style: const TextStyle(fontSize: 13)),
                                ),
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // File List Grid
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CupertinoActivityIndicator(radius: 16))
                        : _filteredFiles.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.folder_badge_minus, size: 48, color: CupertinoColors.systemGrey),
                                    SizedBox(height: 12),
                                    Text('No hay archivos para mostrar', style: TextStyle(color: CupertinoColors.systemGrey)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredFiles.length,
                                itemBuilder: (context, index) {
                                  final file = _filteredFiles[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C1C1E),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: file.isSelected ? CupertinoColors.activeBlue : const Color(0xFF2C2C2E),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CupertinoCheckbox(
                                          value: file.isSelected,
                                          onChanged: (val) {
                                            setState(() => file.isSelected = val ?? false);
                                          },
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(file.iconData, size: 32, color: CupertinoColors.activeBlue),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                file.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${file.formattedSize} • ${file.extension.toUpperCase()}',
                                                style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2C2C2E),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: CupertinoColors.activeGreen.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            '${file.category} (${file.confidence}%)',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              color: CupertinoColors.activeGreen,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          '➔ ~/${file.suggestedRelativeFolder}',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontFamily: 'monospace',
                                                            color: CupertinoColors.activeBlue,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      file.reasoning,
                                                      style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey2),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
