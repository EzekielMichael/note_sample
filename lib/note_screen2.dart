import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'database_helper2.dart';
import 'html_creator_screen_db.dart';
import 'text_to_speech_service_db.dart';
import 'dart:async';

// Define SortOption as a class for extensibility
class SortOption {
  final String label;
  final String sqlOrder;

  const SortOption(this.label, this.sqlOrder);

  static const List<SortOption> values = [
    SortOption('A-Z', 'title ASC'),
    SortOption('Z-A', 'title DESC'),
    SortOption('First Saved', 'date ASC, time ASC'),
    SortOption('Last Saved', 'date DESC, time DESC'),
  ];
}

// Reusable widget for media display
class MediaDisplayWidget extends StatelessWidget {
  final List<String> mediaPaths;
  final Function(String) onTap;
  final Function(int)? onRemove;

  const MediaDisplayWidget({
    Key? key,
    required this.mediaPaths,
    required this.onTap,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaPaths.isEmpty) {
      return const Text('No media');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mediaPaths.asMap().entries.map((entry) {
        final index = entry.key;
        final path = entry.value;
        Widget mediaWidget;
        if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
          mediaWidget = Image.file(
            File(path),
            width: 100,
            height: 100,
            errorBuilder: (context, error, stackTrace) => const Text('Image not found'),
          );
        } else if (path.endsWith('.mp4') || path.endsWith('.mov')) {
          mediaWidget = const Icon(Icons.videocam, size: 100);
        } else if (path.endsWith('.mp3') || path.endsWith('.wav')) {
          mediaWidget = const Icon(Icons.audiotrack, size: 100);
        } else {
          mediaWidget = const Icon(Icons.insert_drive_file, size: 100);
        }
        return Stack(
          alignment: Alignment.topRight,
          children: [
            GestureDetector(
              onTap: () => onTap(path),
              child: mediaWidget,
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => onRemove!(index),
              ),
          ],
        );
      }).toList(),
    );
  }
}

class NoteScreen2 extends StatefulWidget {
  final TextToSpeechServiceDb? ttsService; // Allow injection for testing

  const NoteScreen2({Key? key, this.ttsService}) : super(key: key);

  @override
  _NoteScreenState createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen2> {
  late TextToSpeechServiceDb _ttsService;
  SortOption _selectedSort = SortOption.values.last; // Default to Last Saved
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? TextToSpeechServiceDb();
  }

  // Debounce search input
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = value;
      });
    });
  }

  Future<List<Map<String, dynamic>>> _fetchNotesWithMedia() async {
    final dbHelper = DatabaseHelper2.instance;
    final db = await dbHelper.database;

    // Use a JOIN to fetch notes and media in one query
    final query = '''
      SELECT Note.noteId, Note.title, Note.description, Note.date, Note.time, Image.mediaPath
      FROM Note
      LEFT JOIN Image ON Note.noteId = Image.noteId
      ${_searchQuery.isNotEmpty ? 'WHERE Note.title LIKE ?' : ''}
      ORDER BY ${_selectedSort.sqlOrder}
    ''';
    final result = await db.rawQuery(
      query,
      _searchQuery.isNotEmpty ? ['%$_searchQuery%'] : null,
    );

    // Group results by noteId
    final Map<int, Map<String, dynamic>> notesWithMedia = {};
    for (var row in result) {
      final noteId = row['noteId'] as int;
      if (!notesWithMedia.containsKey(noteId)) {
        notesWithMedia[noteId] = {
          'note': {
            'noteId': noteId,
            'title': row['title'],
            'description': row['description'],
            'date': row['date'],
            'time': row['time'],
          },
          'media': [],
        };
      }
      if (row['mediaPath'] != null) {
        notesWithMedia[noteId]!['media'].add({'mediaPath': row['mediaPath']});
      }
    }

    return notesWithMedia.values.toList();
  }

  Future<void> _editNote(Map<String, dynamic> note, List<dynamic> media) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          noteId: note['noteId'],
          initialTitle: note['title'],
          initialDescription: note['description'] ?? '',
          initialMediaPaths: media.map((m) => m['mediaPath'] as String).toList(),
          ttsService: _ttsService,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _deleteNote(int noteId) async {
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    final dbHelper = DatabaseHelper2.instance;
    final db = await dbHelper.database;

    await db.delete('Note', where: 'noteId = ?', whereArgs: [noteId]);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted!')));
    setState(() {});
  }

  Future<void> _generateHtmlForNote(Map<String, dynamic> note, List<dynamic> media) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HtmlCreatorScreenDb(
          noteTitle: note['title'],
          noteDescription: note['description'] ?? '',
          mediaPaths: media.map((m) => m['mediaPath'] as String).toList(),
        ),
      ),
    );
  }

  Future<void> _speakNote(Map<String, dynamic> note) async {
    final textToSpeak = 'Title: ${note['title']}. Body: ${note['description'] ?? 'No description'}';
    await _ttsService.speak(textToSpeak);
  }

  void _showFullMedia(String mediaPath) {
    if (mediaPath.endsWith('.jpg') || mediaPath.endsWith('.jpeg') || mediaPath.endsWith('.png')) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Image.file(
              File(mediaPath),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => const Text('Image not found'),
            ),
          ),
        ),
      );
    } else if (mediaPath.endsWith('.mp4') || mediaPath.endsWith('.mov')) {
      final controller = VideoPlayerController.file(File(mediaPath));
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: StatefulBuilder(
            builder: (context, setState) => FutureBuilder(
              future: controller.initialize(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              setState(() {
                                controller.value.isPlaying ? controller.pause() : controller.play();
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return const CircularProgressIndicator();
              },
            ),
          ),
        ),
      ).then((_) => controller.dispose()); // Dispose controller after dialog closes
    } else if (mediaPath.endsWith('.mp3') || mediaPath.endsWith('.wav')) {
      final audioPlayer = AudioPlayer();
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Playing Audio'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () async {
                        await audioPlayer.play(DeviceFileSource(mediaPath));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.pause),
                      onPressed: () async {
                        await audioPlayer.pause();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: () async {
                        await audioPlayer.stop();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).then((_) => audioPlayer.dispose()); // Dispose player after dialog closes
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        shadowColor: Colors.black26,
        title: const Text('Saved Notes'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                _ttsService.currentLanguageName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () async {
              await _ttsService.toggleLanguage();
              if (mounted) setState(() {});
            },
            tooltip: 'Switch Language (${_ttsService.switchLanguageButtonText})',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Search notes by title...',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceVariant,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                              : null,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<SortOption>(
                      value: _selectedSort,
                      icon: Icon(Icons.sort, color: Theme.of(context).colorScheme.onSurface),
                      style: Theme.of(context).textTheme.bodyMedium,
                      underline: Container(),
                      onChanged: (SortOption? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedSort = newValue;
                          });
                        }
                      },
                      items: SortOption.values.map<DropdownMenuItem<SortOption>>((SortOption value) {
                        return DropdownMenuItem<SortOption>(
                          value: value,
                          child: Text(value.label),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchNotesWithMedia(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No saved notes yet'));
                }
                final notesWithMedia = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: notesWithMedia.length,
                  itemBuilder: (context, index) {
                    final noteData = notesWithMedia[index];
                    final note = noteData['note'] as Map<String, dynamic>;
                    final media = noteData['media'] as List<dynamic>;
                    final description = note['description'] ?? 'No description';
                    final preview = description.length > 50 ? '${description.substring(0, 50)}...' : description;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ExpansionTile(
                        leading: Icon(
                          Icons.note,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          note['title'],
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          preview,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  description,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                MediaDisplayWidget(
                                  mediaPaths: media.map((m) => m['mediaPath'] as String).toList(),
                                  onTap: _showFullMedia,
                                ),
                                Text(
                                  '${note['date']} ${note['time']}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.volume_up,
                                        color: _ttsService.isSpeaking
                                            ? Theme.of(context).colorScheme.onSurfaceVariant
                                            : Theme.of(context).colorScheme.primary,
                                      ),
                                      onPressed: _ttsService.isSpeaking ? null : () => _speakNote(note),
                                      tooltip: 'Read Note Aloud',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.secondary),
                                      onPressed: () => _editNote(note, media),
                                      tooltip: 'Edit Note',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.html, color: Colors.green),
                                      onPressed: () => _generateHtmlForNote(note, media),
                                      tooltip: 'Generate HTML',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                      onPressed: () => _deleteNote(note['noteId']),
                                      tooltip: 'Delete Note',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NoteEditorScreen(ttsService: _ttsService)),
          ).then((_) => setState(() {}));
        },
        tooltip: 'Add New Note',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _ttsService.stop();
    super.dispose();
  }
}

class NoteEditorScreen extends StatefulWidget {
  final int? noteId;
  final String? initialTitle;
  final String? initialDescription;
  final List<String>? initialMediaPaths;
  final TextToSpeechServiceDb? ttsService;

  const NoteEditorScreen({
    Key? key,
    this.noteId,
    this.initialTitle,
    this.initialDescription,
    this.initialMediaPaths,
    this.ttsService,
  }) : super(key: key);

  @override
  _NoteEditorScreenState createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<String> _mediaPaths = [];
  late TextToSpeechServiceDb _ttsService;

  @override
  void initState() {
    super.initState();
    _ttsService = widget.ttsService ?? TextToSpeechServiceDb();
    if (widget.noteId != null) {
      _titleController.text = widget.initialTitle ?? '';
      _descController.text = widget.initialDescription ?? '';
      _mediaPaths = List.from(widget.initialMediaPaths ?? []);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _mediaPaths.add(pickedFile.path);
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _mediaPaths.add(pickedFile.path);
      });
    }
  }

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mediaPaths.add(result.files.single.path!);
      });
    }
  }

  Future<bool> _confirmRemoveMedia() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: const Text('Are you sure you want to remove this media file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _removeMedia(int index) async {
    bool confirmed = await _confirmRemoveMedia();
    if (confirmed) {
      setState(() {
        _mediaPaths.removeAt(index);
      });
    }
  }

  Future<void> _saveNote() async {
    final dbHelper = DatabaseHelper2.instance;
    final db = await dbHelper.database;

    final note = {
      'userId': 1,
      'title': _titleController.text,
      'description': _descController.text,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'time': TimeOfDay.now().format(context),
    };

    try {
      if (widget.noteId == null) {
        final noteId = await dbHelper.insertNote(note);
        for (var path in _mediaPaths) {
          await dbHelper.insertImage({'noteId': noteId, 'mediaPath': path});
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved!')));
      } else {
        await db.update('Note', note, where: 'noteId = ?', whereArgs: [widget.noteId]);
        final existingMedia = await db.query('Image', where: 'noteId = ?', whereArgs: [widget.noteId]);
        final existingPaths = existingMedia.map((m) => m['mediaPath'] as String).toList();
        final removedPaths = existingPaths.where((path) => !_mediaPaths.contains(path)).toList();

        if (removedPaths.isNotEmpty) {
          bool confirmed = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Media Removal'),
              content: const Text('Some media files will be removed from this note. Do you want to proceed?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Proceed'),
                ),
              ],
            ),
          ) ?? false;

          if (!confirmed) return;
        }

        await db.delete('Image', where: 'noteId = ?', whereArgs: [widget.noteId]);
        for (var path in _mediaPaths) {
          await dbHelper.insertImage({'noteId': widget.noteId, 'mediaPath': path});
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note updated!')));
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
    }
  }

  Future<void> _speakSelectedText(TextEditingController controller) async {
    final selection = controller.selection;
    if (selection.isValid && selection.textInside(controller.text).isNotEmpty) {
      await _ttsService.speak(selection.textInside(controller.text));
    } else {
      await _ttsService.speak(controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        shadowColor: Colors.black26,
        title: Text(widget.noteId == null ? 'Add Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.volume_up,
              color: _ttsService.isSpeaking
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _ttsService.isSpeaking
                ? null
                : () => _ttsService.speak('Title: ${_titleController.text}. Description: ${_descController.text}'),
            tooltip: 'Read Note Aloud',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Text(
                _ttsService.currentLanguageName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () async {
              await _ttsService.toggleLanguage();
              if (mounted) setState(() {});
            },
            tooltip: 'Switch Language (${_ttsService.switchLanguageButtonText})',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter a title' : null,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.volume_up,
                    color: _ttsService.isSpeaking
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _ttsService.isSpeaking ? null : () => _speakSelectedText(_titleController),
                  tooltip: 'Read Title Aloud',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    maxLines: 8,
                    validator: (value) => value?.isEmpty ?? true ? 'Please enter some description' : null,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.volume_up,
                    color: _ttsService.isSpeaking
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _ttsService.isSpeaking ? null : () => _speakSelectedText(_descController),
                  tooltip: 'Read Description Aloud',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Add Image'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                ElevatedButton(
                  onPressed: _pickVideo,
                  child: const Text('Add Video'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                ElevatedButton(
                  onPressed: _pickAudio,
                  child: const Text('Add Audio'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MediaDisplayWidget(
              mediaPaths: _mediaPaths,
              onTap: _showFullMedia,
              onRemove: _removeMedia,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveNote,
              child: Text(widget.noteId == null ? 'Save Note' : 'Update Note'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  _showFullMedia(String p1) {
  }
}