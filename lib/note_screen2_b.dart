import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'database_helper2.dart';
import 'html_creator_screen_db.dart'; // Updated import as requested
import 'text_to_speech_service_db.dart'; // Import TTS service

class NoteScreen2 extends StatefulWidget {
  @override
  _NoteScreenState createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen2> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<String> _mediaPaths = [];
  int? _editingNoteId;
  late TextToSpeechServiceDb _ttsService; // TTS service instance

  @override
  void initState() {
    super.initState();
    _ttsService = TextToSpeechServiceDb(); // Initialize TTS
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
    ) ??
        false;
  }

  void _removeMedia(int index) async {
    bool confirmed = await _confirmRemoveMedia();
    if (confirmed) {
      setState(() {
        _mediaPaths.removeAt(index);
      });
    }
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
      VideoPlayerController controller = VideoPlayerController.file(File(mediaPath));
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
                              controller.dispose();
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
      );
    } else if (mediaPath.endsWith('.mp3') || mediaPath.endsWith('.wav')) {
      AudioPlayer audioPlayer = AudioPlayer();
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
                        audioPlayer.dispose();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
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
      if (_editingNoteId == null) {
        final noteId = await dbHelper.insertNote(note);
        for (var path in _mediaPaths) {
          await dbHelper.insertImage({'noteId': noteId, 'mediaPath': path});
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved!')));
      } else {
        await db.update('Note', note, where: 'noteId = ?', whereArgs: [_editingNoteId]);
        // Check if media is being removed
        final existingMedia = await db.query('Image', where: 'noteId = ?', whereArgs: [_editingNoteId]);
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
          ) ??
              false;

          if (!confirmed) return; // Abort update if user cancels
        }

        await db.delete('Image', where: 'noteId = ?', whereArgs: [_editingNoteId]);
        for (var path in _mediaPaths) {
          await dbHelper.insertImage({'noteId': _editingNoteId, 'mediaPath': path});
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note updated!')));
        _editingNoteId = null;
      }

      _titleController.clear();
      _descController.clear();
      setState(() => _mediaPaths.clear());
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
    }
  }

  Future<void> _editNote(Map<String, dynamic> note, List<dynamic> media) async {
    setState(() {
      _editingNoteId = note['noteId'];
      _titleController.text = note['title'];
      _descController.text = note['description'] ?? '';
      _mediaPaths = media.map((m) => m['mediaPath'] as String).toList();
    });
    Navigator.pop(context);
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
    ) ??
        false;

    if (!confirmed) return;

    final dbHelper = DatabaseHelper2.instance;
    final db = await dbHelper.database;

    await db.delete('Note', where: 'noteId = ?', whereArgs: [noteId]);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted!')));
    setState(() {});
    Navigator.pop(context);
    await _viewNotes();
  }

  Future<void> _generateHtmlForNote(Map<String, dynamic> note, List<dynamic> media) async {
    Navigator.pop(context); // Close the dialog
    Navigator.push(
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
    final textToSpeak = 'Title: ${note['title']}. Description: ${note['description'] ?? 'No description'}';
    await _ttsService.speak(textToSpeak);
  }

  Future<void> _speakSelectedText(TextEditingController controller) async {
    final selection = controller.selection;
    if (selection.isValid && selection.textInside(controller.text).isNotEmpty) {
      await _ttsService.speak(selection.textInside(controller.text));
    } else {
      await _ttsService.speak(controller.text); // Fallback to full text if no selection
    }
  }

  Future<void> _viewNotes() async {
    final dbHelper = DatabaseHelper2.instance;
    final db = await dbHelper.database;

    final notes = await db.query('Note');
    final List<Map<String, dynamic>> notesWithMedia = [];
    for (var note in notes) {
      final media = await db.query('Image', where: 'noteId = ?', whereArgs: [note['noteId']]);
      notesWithMedia.add({'note': note, 'media': media});
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Saved Notes'),
            Flexible(
              child: ElevatedButton(
                onPressed: () async {
                  await _ttsService.toggleLanguage();
                  if (mounted) setState(() {});
                },
                child: Text(_ttsService.switchLanguageButtonText),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notesWithMedia.length,
            itemBuilder: (context, index) {
              final noteData = notesWithMedia[index];
              final note = noteData['note'] as Map<String, dynamic>;
              final media = noteData['media'] as List<dynamic>;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Title: ${note['title']}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.volume_up,
                                  color: _ttsService.isSpeaking ? Colors.grey : Colors.purple,
                                ),
                                onPressed: _ttsService.isSpeaking ? null : () => _speakNote(note),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editNote(note, media),
                              ),
                              IconButton(
                                icon: const Icon(Icons.html, color: Colors.green),
                                onPressed: () => _generateHtmlForNote(note, media),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteNote(note['noteId']),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text('Description: ${note['description'] ?? 'No description'}'),
                      Text('Date: ${note['date']}'),
                      Text('Time: ${note['time']}'),
                      const SizedBox(height: 8),
                      if (media.isNotEmpty)
                        Wrap(
                          children: media.map((m) {
                            final path = m['mediaPath'] as String;
                            if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
                              return GestureDetector(
                                onTap: () => _showFullMedia(path),
                                child: Image.file(
                                  File(path),
                                  width: 100,
                                  height: 100,
                                  errorBuilder: (context, error, stackTrace) => const Text('Image not found'),
                                ),
                              );
                            } else if (path.endsWith('.mp4') || path.endsWith('.mov')) {
                              return GestureDetector(
                                onTap: () => _showFullMedia(path),
                                child: const Icon(Icons.videocam, size: 100),
                              );
                            } else if (path.endsWith('.mp3') || path.endsWith('.wav')) {
                              return GestureDetector(
                                onTap: () => _showFullMedia(path),
                                child: const Icon(Icons.audiotrack, size: 100),
                              );
                            }
                            return const SizedBox.shrink();
                          }).toList(),
                        )
                      else
                        const Text('No media'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingNoteId == null ? 'Add Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.volume_up,
              color: _ttsService.isSpeaking ? Colors.grey : Colors.white,
            ),
            onPressed: _ttsService.isSpeaking
                ? null
                : () => _ttsService.speak('Title: ${_titleController.text}. Description: ${_descController.text}'),
            tooltip: 'Read Note',
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () async {
              await _ttsService.toggleLanguage();
              if (mounted) setState(() {});
            },
            tooltip: _ttsService.switchLanguageButtonText,
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
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.volume_up,
                    color: _ttsService.isSpeaking ? Colors.grey : Colors.purple,
                  ),
                  onPressed: _ttsService.isSpeaking ? null : () => _speakSelectedText(_titleController),
                  tooltip: 'Read Selected Text',
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.volume_up,
                    color: _ttsService.isSpeaking ? Colors.grey : Colors.purple,
                  ),
                  onPressed: _ttsService.isSpeaking ? null : () => _speakSelectedText(_descController),
                  tooltip: 'Read Selected Text',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _pickImage, child: const Text('Add Image')),
                ElevatedButton(onPressed: _pickVideo, child: const Text('Add Video')),
                ElevatedButton(onPressed: _pickAudio, child: const Text('Add Audio')),
              ],
            ),
            Wrap(
              children: _mediaPaths.asMap().entries.map((entry) {
                final index = entry.key;
                final path = entry.value;
                Widget mediaWidget;
                if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
                  mediaWidget = Image.file(File(path), width: 100, height: 100);
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
                      onTap: () => _showFullMedia(path),
                      child: mediaWidget,
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeMedia(index),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveNote,
              child: Text(_editingNoteId == null ? 'Save Note' : 'Update Note'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _viewNotes, child: const Text('View Saved Notes')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _ttsService.stop(); // Stop TTS on dispose
    super.dispose();
  }
}