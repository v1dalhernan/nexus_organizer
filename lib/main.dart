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
    if (!mounted) return;

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
    if (!mounted) return;

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

  void _openSourcesActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Seleccionar Origen / Nube'),
        message: const Text('Elige qué ubicación escanear'),
        actions: _sources.map((src) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentSource = src);
              _scanCurrentSource();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(src.icon, color: src.isCloud ? CupertinoColors.activeGreen : CupertinoColors.activeBlue, size: 20),
                const SizedBox(width: 8),
                Text(src.name),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
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
    final mediaWidth = MediaQuery.of(context).size.width;
    final isCompact = mediaWidth < 768; // Compact view check for responsive UI

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: isCompact
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _openSourcesActionSheet(context),
                child: const Icon(CupertinoIcons.sidebar_left, size: 22),
              )
            : null,
        middle: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.sparkles, color: CupertinoColors.activeBlue, size: 20),
              const SizedBox(width: 8),
              const Text('NexusOrganizer', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _ollamaActive ? CupertinoColors.activeGreen.withValues(alpha: 0.2) : CupertinoColors.systemOrange.withValues(alpha: 0.2),
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
                      _isAnalyzing ? 'IA Analizando...' : (_ollamaActive ? 'Ollama: $_ollamaModel' : 'IA Heurística'),
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
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _undo,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.arrow_counterclockwise, size: 18),
              SizedBox(width: 4),
              Text('Deshacer', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                // Sidebar (Only visible on wide screens)
                if (!isCompact)
                  SizedBox(
                    width: constraints.maxWidth > 1000 ? 300 : 250,
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
                                fontSize: 11,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                src.name,
                                                style: TextStyle(
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  fontSize: 13,
                                                  color: CupertinoColors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                src.isCloud ? 'Nube' : 'Local',
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

                // Main Content View (Fully Responsive)
                Expanded(
                  child: Column(
                    children: [
                      // Responsive Header Bar
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E))),
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentSource?.name ?? 'Carpeta',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _currentSource?.path ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CupertinoButton(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      color: CupertinoColors.darkBackgroundGray,
                                      onPressed: _scanCurrentSource,
                                      child: const Row(
                                        children: [
                                          Icon(CupertinoIcons.refresh, size: 15),
                                          SizedBox(width: 4),
                                          Text('Escanear', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CupertinoButton.filled(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      onPressed: _scannedFiles.any((f) => f.isSelected) ? _moveSelected : null,
                                      child: Row(
                                        children: [
                                          const Icon(CupertinoIcons.arrow_right_arrow_left, size: 15),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Mover (${_scannedFiles.where((f) => f.isSelected).length})',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Scrollable / Responsive Segmented Control
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: CupertinoSegmentedControl<int>(
                                groupValue: _selectedFilterIndex,
                                onValueChanged: (val) => setState(() => _selectedFilterIndex = val),
                                children: {
                                  for (int i = 0; i < _categories.length; i++)
                                    i: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Text(_categories[i], style: const TextStyle(fontSize: 12)),
                                    ),
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Responsive File Cards Grid / List
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CupertinoActivityIndicator(radius: 16))
                            : _filteredFiles.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(CupertinoIcons.folder_badge_minus, size: 44, color: CupertinoColors.systemGrey),
                                        SizedBox(height: 10),
                                        Text('No hay archivos para mostrar', style: TextStyle(color: CupertinoColors.systemGrey)),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _filteredFiles.length,
                                    itemBuilder: (context, index) {
                                      final file = _filteredFiles[index];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
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
                                            const SizedBox(width: 8),
                                            Icon(file.iconData, size: 28, color: CupertinoColors.activeBlue),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    file.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${file.formattedSize} • ${file.extension.toUpperCase()}',
                                                    style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF2C2C2E),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Wrap(
                                                          crossAxisAlignment: WrapCrossAlignment.center,
                                                          spacing: 6,
                                                          runSpacing: 4,
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: CupertinoColors.activeGreen.withValues(alpha: 0.2),
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
                                                            Text(
                                                              '➔ ~/${file.suggestedRelativeFolder}',
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                fontFamily: 'monospace',
                                                                color: CupertinoColors.activeBlue,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          file.reasoning,
                                                          style: const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2),
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
            );
          },
        ),
      ),
    );
  }
}
