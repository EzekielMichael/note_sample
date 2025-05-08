import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:html/dom.dart' as dom;

class HtmlCreatorScreenDb extends StatefulWidget {
  final String noteTitle;
  final String noteDescription;
  final List<String> mediaPaths;

  const HtmlCreatorScreenDb({
    super.key,
    required this.noteTitle,
    required this.noteDescription,
    required this.mediaPaths,
  });

  @override
  State<HtmlCreatorScreenDb> createState() => _HtmlCreatorScreenState();
}

class _HtmlCreatorScreenState extends State<HtmlCreatorScreenDb> {
  bool _isGenerating = false;
  String? _htmlPreview;
  List<FileSystemEntity> _savedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
  }

  Future<void> _loadSavedFiles() async {
    Directory directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/HTML_Notes');
    } else {
      directory = Directory('${(await getApplicationDocumentsDirectory()).path}/HTML_Notes');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
      setState(() => _savedFiles = []);
      return;
    }

    setState(() {
      _savedFiles = directory.listSync()
          .where((file) => file is File && file.path.endsWith('.html'))
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    });
  }

  String _determineFileType(String extension) {
    const imageTypes = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
    const audioTypes = ['mp3', 'wav', 'ogg', 'aac', 'm4a', 'flac'];
    const videoTypes = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'];
    const docTypes = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'];

    if (imageTypes.contains(extension)) return 'image';
    if (audioTypes.contains(extension)) return 'audio';
    if (videoTypes.contains(extension)) return 'video';
    if (docTypes.contains(extension)) return 'document';
    return 'file';
  }

  Future<String> _generateHtmlContent() async {
    if (widget.mediaPaths.isEmpty) {
      return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${widget.noteTitle}</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; line-height: 1.6; color: #333; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; margin-top: 0; }
        .content { margin: 20px 0; white-space: pre-line; line-height: 1.8; }
        .footer { margin-top: 30px; text-align: center; color: #7f8c8d; font-size: 0.9em; border-top: 1px solid #eee; padding-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>${widget.noteTitle}</h1>
        <div class="content">${widget.noteDescription}</div>
        <div class="footer">
            Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} 
            with 0 files by Eze app
        </div>
    </div>
</body>
</html>
''';
    }

    try {
      String filesHtml = '';
      int fileCounter = 1;

      for (var mediaPath in widget.mediaPaths) {
        final file = File(mediaPath);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final fileBase64 = Uri.dataFromBytes(bytes, mimeType: _getMimeType(file)).toString();
        final fileName = file.path.split('/').last;
        final fileSize = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(2);
        final fileType = _determineFileType(file.path.split('.').last.toLowerCase());

        filesHtml += '''
      <div class="file-container">
        <h3>Attachment $fileCounter: ${fileType.capitalize()} 
        <!-- ($fileSize MB) -->
        </h3>
        ${_generateFileEmbed(fileBase64, fileName, fileType, _getMimeType(file))}
        <!-- <p style="text-align: center; color: #666;">$fileName</p> -->
      </div>
      ''';
        fileCounter++;
      }

      return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${widget.noteTitle}</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; line-height: 1.6; color: #333; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; margin-top: 0; }
        .content { margin: 20px 0; white-space: pre-line; line-height: 1.8; }
        .file-container { margin: 30px 0; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px; background-color: #f9f9f9; }
        .file-container h3 { margin-top: 0; color: #2c3e50; }
        .footer { margin-top: 30px; text-align: center; color: #7f8c8d; font-size: 0.9em; border-top: 1px solid #eee; padding-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>${widget.noteTitle}</h1>
        <div class="content">${widget.noteDescription}</div>
        $filesHtml
        <div class="footer">
            Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} 
            with ${widget.mediaPaths.length} files by Eze app
        </div>
    </div>
</body>
</html>
''';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating HTML: $e')),
        );
      }
      return '';
    }
  }

  String _generateFileEmbed(String fileBase64, String fileName, String fileType, String mimeType) {
    switch (fileType.toLowerCase()) {
      case 'image':
        return '<img src="$fileBase64" alt="$fileName" style="max-width: 100%; border: 1px solid #ddd; border-radius: 4px;">';
      case 'audio':
        return '''
      <audio controls style="width: 100%;">
        <source src="$fileBase64" type="$mimeType">
        Your browser does not support audio embedding
      </audio>
      ''';
      case 'video':
        return '''
      <video controls style="max-width: 100%;">
        <source src="$fileBase64" type="$mimeType">
        Your browser does not support video embedding
      </video>
      ''';
      default:
        return '''
      <div style="text-align: center; margin: 20px 0;">
        <object data="$fileBase64" type="$mimeType" style="width: 100%; min-height: 300px;">
          <p>This file type cannot be displayed inline. <a href="$fileBase64" download="$fileName">Download instead</a></p>
        </object>
        <a href="$fileBase64" download="$fileName" 
           style="padding: 10px 20px; background: #3498db; color: white; 
                  text-decoration: none; border-radius: 4px; margin-top: 10px; display: inline-block;">
          Download $fileName
        </a>
      </div>
      ''';
    }
  }

  String _getMimeType(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      case 'svg': return 'image/svg+xml';
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'ogg': return 'audio/ogg';
      case 'aac': return 'audio/aac';
      case 'm4a': return 'audio/mp4';
      case 'flac': return 'audio/flac';
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'avi': return 'video/x-msvideo';
      case 'mkv': return 'video/x-matroska';
      case 'webm': return 'video/webm';
      case 'flv': return 'video/x-flv';
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt': return 'text/plain';
      default: return 'application/octet-stream';
    }
  }

  Future<void> _generateAndSaveHtml() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
      }
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final htmlContent = await _generateHtmlContent();
      if (htmlContent.isEmpty) return;

      setState(() => _htmlPreview = htmlContent);

      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/HTML_Notes');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final sanitizedHeading = widget.noteTitle
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${sanitizedHeading}_$timestamp.html';
      final file = File(path.join(directory.path, fileName));

      await file.writeAsString(htmlContent);
      await _loadSavedFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HTML with ${widget.mediaPaths.length} embedded files saved'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => _openFile(file),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving HTML: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _openFile(File file) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage permission required to open files')),
              );
            }
            return;
          }
        }
      }

      const mimeType = 'text/html';
      final result = await OpenFile.open(file.path, type: mimeType);

      if (result.type != ResultType.done) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: mimeType)],
          text: 'Open HTML file',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _openFile(file),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${file.path.split('/').last}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await file.delete();
      await _loadSavedFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: $e')),
        );
      }
    }
  }

  Future<void> _shareFile(FileSystemEntity file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/html')],
        text: 'Sharing HTML file: ${file.path.split('/').last}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  void _handleLinkTap(String? url, Map<String, String> attributes, dom.Element? element) async {
    if (url != null && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        title: const Text('Generate HTML from Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            color: Colors.blueAccent,
            onPressed: () => _showSavedFiles(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Title: ${widget.noteTitle}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Description: ${widget.noteDescription}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              if (widget.mediaPaths.isNotEmpty) ...[
                const Text(
                  'Attached Media:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.mediaPaths.map((path) {
                    final fileType = _determineFileType(path.split('.').last.toLowerCase());
                    return Chip(
                      avatar: Icon(
                        fileType == 'image'
                            ? Icons.image
                            : fileType == 'audio'
                            ? Icons.audiotrack
                            : fileType == 'video'
                            ? Icons.videocam
                            : Icons.insert_drive_file,
                        color: fileType == 'image'
                            ? Colors.blue
                            : fileType == 'audio'
                            ? Colors.purple
                            : fileType == 'video'
                            ? Colors.red
                            : Colors.grey,
                      ),
                      label: Text(path.split('/').last),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateAndSaveHtml,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.white60,
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                  'Generate HTML with ${widget.mediaPaths.length} ${widget.mediaPaths.length == 1 ? 'file' : 'files'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (_htmlPreview != null) ...[
                const SizedBox(height: 30),
                const Text(
                  'HTML Preview:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Html(
                          data: _htmlPreview!,
                          style: {'body': Style(margin: Margins.zero)},
                          onLinkTap: (url, attributes, element) =>
                              _handleLinkTap(url, attributes, element),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSavedFiles(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved HTML Files',
            style: TextStyle(fontStyle: FontStyle.italic,
                color: Colors.green,
                // backgroundColor: Colors.deepPurple
            ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _savedFiles.isEmpty
              ? const Center(child: Text('No saved files yet'))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _savedFiles.length,
            itemBuilder: (context, index) {
              final file = _savedFiles[index];
              final fileName = file.path.split('/').last;
              final fileSize = (file.statSync().size / (1024 * 1024)).toStringAsFixed(2);
              final modified = file.statSync().modified;

              return ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(fileName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$fileSize MB'),
                    Text('${modified.day}/${modified.month}/${modified.year}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.blue),
                      onPressed: () => _shareFile(file),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteFile(file),
                    ),
                  ],
                ),
                onTap: () => _openFile(file as File),
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
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}